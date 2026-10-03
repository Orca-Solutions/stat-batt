#!/usr/bin/python3
"""Disabled, one-shot guardian-loss qualification. Never a background controller."""
import datetime
import ctypes
import fcntl
import hashlib
import json
import os
from pathlib import Path
import select
import stat
import subprocess
import sys
import tempfile
import time
import uuid

ENABLED = False
BINARY = Path('/Library/Application Support/StatBattLocal/StatBatt.app/Contents/MacOS/StatBattAdapterGuardian')
BINARY_SHA256 = '673176cd92b7374fa01b194dac8491ed1e1a05094424f2c5a3a96c466642cd62'
SOURCE_MANIFEST = Path('/private/tmp/statbatt-v11-candidate-b9znmgcm/CANDIDATE_MANIFEST.json')
SOURCE_MANIFEST_SHA256 = '2152e7e4707b08bde19ebb105b5d9c99d33978f78e986fba0270b16d1f9c2931'
SOURCE_ROOT = Path('/private/tmp/statbatt-v11-candidate-b9znmgcm/statbatt')
OWNERSHIP = Path('/Library/Application Support/StatBattAdapterGuardian')
ENV = {'PATH': '/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': '/var/root'}
REQUIREMENT = 'anchor apple generic and certificate leaf[subject.OU] = "TWZA95CB7G" and identifier "dev.statbatt.adapter-guardian"'


def continuous_nanoseconds():
    class Timebase(ctypes.Structure):
        _fields_ = [('numer', ctypes.c_uint32), ('denom', ctypes.c_uint32)]
    library = ctypes.CDLL('/usr/lib/libSystem.B.dylib')
    library.mach_continuous_time.restype = ctypes.c_uint64
    library.mach_timebase_info.argtypes = [ctypes.POINTER(Timebase)]
    base = Timebase()
    if library.mach_timebase_info(ctypes.byref(base)) != 0 or base.denom == 0: raise RuntimeError('clockUnavailable')
    return library.mach_continuous_time() * base.numer // base.denom


def positive(packet, key, now=None):
    if not isinstance(packet, dict): return False
    phase = 'inhibited' if key == 8 else 'inspection'
    key_at, source_at = packet.get('sampledAt'), packet.get('sourceAt')
    now = continuous_nanoseconds() if now is None else now
    maximum_age = 250_000_000 if key == 8 else 2_000_000_000
    return (packet.get('phase') == phase and packet.get('outcome') == 0 and packet.get('key') == key
            and type(key_at) is int and type(source_at) is int and 0 < key_at <= source_at <= now
            and now - key_at <= maximum_age
            and packet.get('battery') is (key == 8) and packet.get('adapter') is (key == 0))


def kill_once(child, packet, already_killed, audit=None):
    now = continuous_nanoseconds()
    if already_killed or not positive(packet, 8, now=now): return already_killed
    if audit is not None: audit.update(killRequestedAt=now, acceptedPacket=packet)
    child.kill()
    if audit is not None: audit['killCompletedAt'] = continuous_nanoseconds()
    return True


def save(stage, name, data):
    with (stage / (name + '.new')).open('x') as stream:
        json.dump(data, stream, indent=2); stream.flush(); os.fsync(stream.fileno())
    (stage / (name + '.new')).replace(stage / name)
    fd = os.open(stage, os.O_RDONLY | os.O_DIRECTORY)
    try: os.fsync(fd)
    finally: os.close(fd)


def secure_path(path, directory=False):
    info = path.lstat()
    return info.st_uid == 0 and not info.st_mode & 0o022 and (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode))


def verify_binary():
    if not secure_path(BINARY): raise RuntimeError('binaryOwnership')
    for parent in BINARY.parents:
        if not secure_path(parent, directory=True): raise RuntimeError('binaryAncestry')
    if hashlib.sha256(BINARY.read_bytes()).hexdigest() != BINARY_SHA256: raise RuntimeError('binaryHash')
    subprocess.run(['/usr/bin/codesign', '--verify', '--strict', '-R', REQUIREMENT, str(BINARY)],
                   check=True, capture_output=True, timeout=5, env=ENV)


def leases_available():
    """Read-only proof. Never hold these locks while invoking the real guardian."""
    descriptors = []
    try:
        if not secure_path(OWNERSHIP, directory=True): return False
        directory = os.open(OWNERSHIP, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        descriptors.append(directory)
        fcntl.flock(directory, fcntl.LOCK_EX | fcntl.LOCK_NB)
        lease = os.open('writer.lock', os.O_RDONLY | os.O_NOFOLLOW, dir_fd=directory)
        descriptors.append(lease)
        info = os.fstat(lease)
        if info.st_uid != 0 or not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077: return False
        fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except (OSError, BlockingIOError): return False
    finally:
        for descriptor in reversed(descriptors): os.close(descriptor)


def invoke(mode):
    # Call sites use fixed modes only. No caller-controlled argv is accepted.
    if mode not in ('--inspect', '--recover'): raise ValueError('closedMode')
    process = subprocess.Popen([str(BINARY), mode], stdin=subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=ENV)
    try: stdout, _ = process.communicate(timeout=6)
    except subprocess.TimeoutExpired:
        # Never kill a recovery guardian merely because its response is late.
        return {'exit': None, 'packets': [], 'stillRunning': True}
    packets = []
    if len(stdout) <= 65536:
        for line in stdout.splitlines():
            try: packets.append(json.loads(line))
            except (ValueError, UnicodeError): pass
    return {'exit': process.returncode, 'packets': packets}


def verify_recovery(inspect, available, recover, clock=time.monotonic, pause=time.sleep):
    end = clock() + 6
    while not available():
        if clock() >= end: return {'result': 'writerLeaseStillHeldUnknown', 'fallbackUsed': False}
        pause(.05)
    initial = inspect()
    if initial.get('stillRunning'): return {'result': 'inspectionStillRunningUnknown', 'fallbackUsed': False}
    if initial.get('exit') == 0 and any(positive(packet, 0) for packet in initial.get('packets', [])):
        return {'result': 'independentRestorationVerified', 'fallbackUsed': False, 'inspection': initial}
    # A second proof and the guardian's own lock acquisition prevent late-writer races.
    if not available(): return {'result': 'leaseChangedUnknown', 'fallbackUsed': False, 'inspection': initial}
    fallback = recover()
    if fallback.get('stillRunning'): return {'result': 'fallbackStillRunningUnknown', 'fallbackUsed': True, 'fallback': fallback}
    final = inspect()
    return {'result': 'fallbackRestorationVerified' if fallback.get('exit') == 0 and final.get('exit') == 0 and any(positive(p, 0) for p in final.get('packets', [])) else 'restorationUnknown',
            'fallbackUsed': True, 'inspection': initial, 'fallback': fallback, 'finalInspection': final}


def journal_phase():
    path = OWNERSHIP / 'intent.json'
    if not secure_path(path) or path.lstat().st_mode & 0o077: return None
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try: data = os.read(fd, 4097)
    finally: os.close(fd)
    if len(data) > 4096: return None
    return json.loads(data).get('phase')


def cleanup_owned_intent(inspect, available, recover, read_phase):
    # Independent restoration has already been observed and recorded. This
    # separate00 cleanup closes its durable intent using the shipped helper.
    if not available(): return {'verified': False, 'reason': 'leaseChanged'}
    cleanup = recover()
    if cleanup.get('stillRunning'): return {'verified': False, 'reason': 'cleanupStillRunning'}
    final = inspect()
    verified = (cleanup.get('exit') == 0 and final.get('exit') == 0
                and any(positive(p, 0) for p in final.get('packets', [])) and read_phase() == 'restored')
    return {'verified': verified, 'recovery': cleanup, 'finalInspection': final}


def observe_cycle(child, operation):
    killed = False; evidence = []; pending = b''; error = None; kill_audit = {}
    try:
        child.stdin.write((operation + '\n').encode()); child.stdin.flush()
        deadline = time.monotonic() + 6
        while child.poll() is None and time.monotonic() < deadline:
            if not select.select([child.stdout], [], [], .02)[0]: continue
            chunk = os.read(child.stdout.fileno(), 4096)
            if not chunk: break
            pending += chunk
            if len(pending) > 65536: raise RuntimeError('outputLimit')
            while b'\n' in pending:
                line, pending = pending.split(b'\n', 1)
                try: packet = json.loads(line)
                except ValueError: continue
                if len(evidence) < 128: evidence.append(packet)
                if positive(packet, 8):
                    # Exactly this child, exactly once. Never kill the independent worker.
                    killed = kill_once(child, packet, killed, kill_audit); break
            if killed: break
    except Exception as failure:
        error = type(failure).__name__
    finally:
        try: child.stdin.close()  # Any pre-kill failure asks the living guardian to restore.
        except Exception as failure: error = error or type(failure).__name__
        try: child.wait(timeout=12)
        except Exception as failure: error = error or type(failure).__name__  # Never kill recovery on timeout.
    return killed, evidence, error, kill_audit


def main():
    if not ENABLED or SOURCE_MANIFEST is None or SOURCE_MANIFEST_SHA256 is None:
        raise SystemExit('Source-only guardian-loss packet; execution disabled.')
    if os.getuid() != 0 or os.geteuid() != 0 or sys.argv[1:] != ['--approved-guardian-loss-test']:
        raise SystemExit('Explicit administrator invocation required; no elevation.')
    verify_binary()
    proof = Path(SOURCE_MANIFEST).read_bytes()
    if len(proof) > 65536 or hashlib.sha256(proof).hexdigest() != SOURCE_MANIFEST_SHA256:
        raise SystemExit('Source provenance mismatch')
    manifest = json.loads(proof)
    for name in ('Sources/StatBattAdapterGuardian/Command.swift', 'Sources/StatBattAdapterGuardian/WorkerRecoveryGate.swift',
                 'Sources/CStatBattAdapterControl/adapter_control.c', 'Sources/StatBattAdapterBackend/AdapterPacket.swift'):
        if hashlib.sha256((SOURCE_ROOT / name).read_bytes()).hexdigest() != manifest.get(name):
            raise SystemExit('Reviewed source mismatch')
    names = subprocess.run(['/bin/ps', '-axo', 'comm='], check=True, capture_output=True, text=True, timeout=3).stdout.splitlines()
    blocked = {'statbatt', 'statbattcontroldaemon', 'shortcuts', 'energiza', 'aldente', 'batt', 'batterytoolkit', 'battery toolkit', 'batterytoolkitd'}
    if not names or any(Path(name.strip()).name.lower() in blocked for name in names):
        raise SystemExit('Close UI, shortcuts, and other charging controllers first.')
    service = subprocess.run(['/bin/launchctl', 'print', 'system/dev.statbatt.control-daemon'], capture_output=True, timeout=3)
    if service.returncode != 113: raise SystemExit('StatBatt service must already be unregistered; exact launchctl113 required.')
    baseline = invoke('--inspect')
    if baseline.get('exit') != 0 or not any(positive(packet, 0) for packet in baseline['packets']): raise SystemExit('Fresh00+AC baseline unavailable')
    stage = Path(tempfile.mkdtemp(prefix='statbatt-guardian-loss-', dir='/private/tmp'))
    operation = str(uuid.uuid4())
    save(stage, 'intent.json', {'operation': operation, 'authorization': sys.argv[1], 'binarySHA256': BINARY_SHA256,
        'sourceManifestSHA256': SOURCE_MANIFEST_SHA256, 'baseline': baseline,
        'timestampUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'plan': 'One cycle; kill only its guardian after fresh08+battery; worker restores on EOF with fixed2s lease. One guarded00 fallback if needed, OR after independent00+AC proof one00 cleanup closes owned journal. No repeated08.'})
    child = subprocess.Popen([str(BINARY), '--cycle'], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL, env=ENV, start_new_session=True)
    killed, evidence, error, kill_audit = observe_cycle(child, operation)
    # Evidence I/O cannot delay the worker's independent restoration.
    recovery = verify_recovery(lambda: invoke('--inspect'), leases_available, lambda: invoke('--recover'))
    cleanup = None
    if recovery['result'] == 'independentRestorationVerified':
        try: save(stage, 'independent-proof.json', recovery)
        except Exception as failure: error = error or type(failure).__name__
        cleanup = cleanup_owned_intent(lambda: invoke('--inspect'), leases_available, lambda: invoke('--recover'), journal_phase)
    result = {'guardianKilled': killed, 'guardianExit': child.returncode, 'errorType': error, 'events': evidence, 'killAudit': kill_audit, 'recovery': recovery,
              'cleanup': cleanup,
              'qualified': killed and child.returncode == -9 and error is None and recovery['result'] == 'independentRestorationVerified' and cleanup is not None and cleanup['verified']}
    save(stage, 'result.json', result)
    print(json.dumps(result, indent=2)); print('Evidence:', stage)
    return 0 if result['qualified'] else 1


if __name__ == '__main__': sys.exit(main())
