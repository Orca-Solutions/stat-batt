#!/usr/bin/python3
"""Disabled one-use120s qualification packet. No installation or automatic policy."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
import types
import uuid

ENABLED = False
COMMON_PATH = None
COMMON_SHA256 = None
SLEEP_BINARY = None
SLEEP_SHA256 = None
BINARY_SHA256 = None
SOURCE_ROOT = None
SOURCE_MANIFEST = None
SOURCE_MANIFEST_SHA256 = None


def pinned_module(path, expected):
    raw = Path(path).read_bytes()
    if expected is None or hashlib.sha256(raw).hexdigest() != expected:
        raise RuntimeError('Pinned helper mismatch')
    module = types.ModuleType('qualification_helper')
    exec(compile(raw, str(path), 'exec'), module.__dict__)
    return module


def main():
    if not ENABLED or any(x is None for x in (COMMON_PATH, COMMON_SHA256, SLEEP_BINARY, SLEEP_SHA256, BINARY_SHA256, SOURCE_ROOT, SOURCE_MANIFEST, SOURCE_MANIFEST_SHA256)):
        raise SystemExit('Source-only long-pause packet; execution disabled.')
    if os.getuid() != 0 or os.geteuid() != 0 or sys.argv[1:] != ['--approved-long-sleep-test']:
        raise SystemExit('Explicit administrator invocation required.')
    common = pinned_module(COMMON_PATH, COMMON_SHA256)
    common.BINARY_SHA256 = BINARY_SHA256
    common.verify_binary()
    raw = Path(SOURCE_MANIFEST).read_bytes()
    if len(raw) > 65536 or hashlib.sha256(raw).hexdigest() != SOURCE_MANIFEST_SHA256:
        raise SystemExit('Source manifest mismatch')
    manifest = json.loads(raw)
    for name in ('Sources/StatBattAdapterGuardian/Command.swift', 'Sources/StatBattAdapterGuardian/WorkerRecoveryGate.swift',
        'Sources/StatBattAdapterGuardian/LongPauseSafety.swift', 'Sources/CStatBattAdapterControl/adapter_control.c',
        'Sources/StatBattAdapterBackend/AdapterPacket.swift'):
        if hashlib.sha256((Path(SOURCE_ROOT) / name).read_bytes()).hexdigest() != manifest.get(name):
            raise SystemExit('Reviewed source mismatch')
    names = subprocess.run(['/bin/ps','-axo','comm='],check=True,capture_output=True,text=True,timeout=3).stdout.splitlines()
    blocked = {'statbatt','statbattcontroldaemon','shortcuts','energiza','aldente','batt','batterytoolkit','battery toolkit','batterytoolkitd'}
    if not names or any(Path(name.strip()).name.lower() in blocked for name in names):
        raise SystemExit('Close controllers before this test.')
    service = subprocess.run(['/bin/launchctl','print','system/dev.statbatt.control-daemon'],capture_output=True,timeout=3)
    if service.returncode != 113: raise SystemExit('Service must be unregistered.')
    observer_bytes = Path(SLEEP_BINARY).read_bytes()
    if hashlib.sha256(observer_bytes).hexdigest() != SLEEP_SHA256:
        raise SystemExit('Observer hash mismatch')
    baseline = common.invoke('--inspect')
    if baseline.get('exit') != 0 or not any(common.positive(p,0) for p in baseline['packets']):
        raise SystemExit('Fresh00+adapter baseline unavailable')
    stage = Path(tempfile.mkdtemp(prefix='statbatt-long-sleep-',dir='/private/tmp'))
    observer_path = stage / 'sleep-observer'
    with observer_path.open('xb') as stream:
        stream.write(observer_bytes); stream.flush(); os.fchmod(stream.fileno(), 0o500); os.fsync(stream.fileno())
    operation = str(uuid.uuid4())
    common.save(stage,'intent.json',{'operation':operation,'baseline':baseline,'binarySHA256':BINARY_SHA256,
        'startedAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'startedAtContinuousNanoseconds':common.continuous_nanoseconds(),'supervisorPID':os.getpid(),
        'authorizationArgument':'--approved-long-sleep-test',
        'plan':'One fixed120s cycle; request system sleep once after fresh08+battery. WILL_SLEEP closes owner. Acknowledge verified only after guardian restoration. One guarded00 fallback if needed; no retry.'})
    observer = subprocess.Popen([str(observer_path),'--approved-sleep-recovery-observer'],
        stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,env=common.ENV)
    child, events, markers, requested, owner_closed, replied, error = coordinate(observer, common, operation)
    recovery = common.verify_recovery(lambda:common.invoke('--inspect'),common.leases_available,lambda:common.invoke('--recover'))
    qualified = (error is None and requested and owner_closed and replied and observer.returncode == 0 and child is not None and child.returncode == 0
        and 'ACK_RESTORED' in markers and 'ACK_UNKNOWN' not in markers
        and recovery.get('result') == 'independentRestorationVerified' and common.journal_phase() == 'restored')
    result = {'qualified':qualified,'errorType':error,'events':events,'sleepMarkers':markers,'recovery':recovery,
        'limitation':'Callback and acknowledgment evidence only; observer exits before wake. Post-wake inspection requires a separate read-only check.'}
    common.save(stage,'result.json',result)
    print(json.dumps(result,indent=2)); print('Evidence:',stage)
    return 0 if qualified else 1


def coordinate(observer, common, operation):
    child = None
    events, markers, pending = [], [], {observer.stdout: b''}
    requested = owner_closed = replied = False
    error = None
    try:
        end = time.monotonic() + 20
        while time.monotonic() < end:
            for stream in select.select(list(pending), [], [], .02)[0]:
                chunk = os.read(stream.fileno(),4096)
                if not chunk:
                    del pending[stream]; continue
                pending[stream] += chunk
                if len(pending[stream]) > 32768: raise RuntimeError('frameLimit')
                while b'\n' in pending[stream]:
                    line,pending[stream] = pending[stream].split(b'\n',1)
                    if stream is observer.stdout:
                        marker = line.decode('ascii')
                        if marker not in ('READY','SLEEP_REQUESTED','WILL_SLEEP','ACK_RESTORED','ACK_UNKNOWN','INCONCLUSIVE'):
                            raise RuntimeError('observerMarker')
                        if len(markers) >= 32: raise RuntimeError('markerLimit')
                        markers.append(marker)
                        if marker == 'READY' and child is None:
                            child = subprocess.Popen([str(common.BINARY),'--cycle-120'],stdin=subprocess.PIPE,
                                stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,env=common.ENV,start_new_session=True)
                            pending[child.stdout] = b''
                            child.stdin.write((operation+'\n').encode()); child.stdin.flush()
                        if marker == 'WILL_SLEEP' and child is not None and not owner_closed:
                            child.stdin.close(); owner_closed = True
                    else:
                        packet = json.loads(line)
                        if len(events) >= 400: raise RuntimeError('traceLimit')
                        events.append(packet)
                        if not requested and common.positive(packet,8):
                            observer.stdin.write(b'S'); observer.stdin.flush(); requested = True
            if child is not None and child.poll() is not None and child.stdout not in pending and not replied:
                restored = restoration_observed(events,common.continuous_nanoseconds())
                observer.stdin.write(b'R' if owner_closed and child.returncode == 0 and restored else b'F')
                observer.stdin.flush(); replied = True
            if observer.poll() is not None and observer.stdout not in pending:
                if not replied or 'ACK_RESTORED' not in markers: error = error or 'observerExitedWithoutVerifiedAcknowledgment'
                break
    except BaseException as failure:
        error = type(failure).__name__
    finally:
        # No kill: owner EOF requests restoration independently of this supervisor.
        for process in (child,observer):
            if process is not None:
                try: process.stdin.close()
                except Exception: pass
        if child is not None:
            try: child.wait(timeout=12)
            except Exception as failure: error = error or type(failure).__name__
    return child, events, markers, requested, owner_closed, replied, error


def restoration_observed(events,now):
    return any(isinstance(p,dict) and p.get('phase') == 'restored' and p.get('outcome') == 0
        and p.get('key') == 0 and p.get('adapter') is True and p.get('battery') is False
        and type(p.get('sampledAt')) is int and type(p.get('sourceAt')) is int
        and 0 < p['sampledAt'] <= p['sourceAt'] <= now and now-p['sampledAt'] <= 2_000_000_000
        for p in events)

if __name__ == '__main__': sys.exit(main())
