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
EVIDENCE_PATH = None
EVIDENCE_SHA256 = None
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


def collect(child, operation, clock):
    events, pending, error = [], b'', None
    def consume(chunk):
        nonlocal pending
        pending += chunk
        if len(pending) > 32768: raise RuntimeError('Frame overflow')
        while b'\n' in pending:
            line, pending = pending.split(b'\n', 1)
            packet = json.loads(line)
            if not isinstance(packet, dict): raise RuntimeError('Packet type')
            if len(events) >= 2000: raise RuntimeError('Trace overflow')
            events.append({'receivedAt': clock(), 'packet': packet})
    try:
        child.stdin.write((operation + '\n').encode()); child.stdin.flush()
        deadline = time.monotonic() + 130
        while child.poll() is None and time.monotonic() < deadline:
            if not select.select([child.stdout], [], [], .02)[0]: continue
            chunk = os.read(child.stdout.fileno(), 4096)
            if not chunk: break
            consume(chunk)
        if child.poll() is None and time.monotonic() >= deadline: error = 'Guardian completion deadline exceeded'
    except BaseException as failure:
        error = type(failure).__name__
    finally:
        # EOF requests restoration. Never kill the guardian or its worker here,
        # including KeyboardInterrupt/SystemExit and malformed-output paths.
        try: child.stdin.close()
        except Exception as failure: error = error or type(failure).__name__
        try: child.wait(timeout=12)
        except Exception as failure: error = error or type(failure).__name__
        # A child can exit before the polling loop sees its final failure packet.
        # Drain only readable bytes, with a fixed budget, without waiting on EOF.
        try:
            for _ in range(16):
                if not select.select([child.stdout], [], [], 0)[0]: break
                chunk = os.read(child.stdout.fileno(), 4096)
                if not chunk: break
                consume(chunk)
            else: error = error or 'Final drain budget exceeded'
            if pending: error = error or 'Incomplete final frame'
        except Exception as failure: error = error or type(failure).__name__
    return events, error


def main():
    if not ENABLED or any(x is None for x in (COMMON_PATH, COMMON_SHA256, EVIDENCE_PATH,
        EVIDENCE_SHA256, BINARY_SHA256, SOURCE_ROOT, SOURCE_MANIFEST, SOURCE_MANIFEST_SHA256)):
        raise SystemExit('Source-only long-pause packet; execution disabled.')
    if os.getuid() != 0 or os.geteuid() != 0 or sys.argv[1:] != ['--approved-long-pause-test']:
        raise SystemExit('Explicit administrator invocation required.')
    common = pinned_module(COMMON_PATH, COMMON_SHA256)
    evidence = pinned_module(EVIDENCE_PATH, EVIDENCE_SHA256)
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
    baseline = common.invoke('--inspect')
    if baseline.get('exit') != 0 or not any(common.positive(p,0) for p in baseline['packets']):
        raise SystemExit('Fresh00+adapter baseline unavailable')
    stage = Path(tempfile.mkdtemp(prefix='statbatt-long-pause-',dir='/private/tmp'))
    operation = str(uuid.uuid4())
    common.save(stage,'intent.json',{'operation':operation,'baseline':baseline,'binarySHA256':BINARY_SHA256,
        'startedAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'startedAtContinuousNanoseconds':common.continuous_nanoseconds(),'supervisorPID':os.getpid(),
        'authorizationArgument':'--approved-long-pause-test',
        'plan':'One fixed120s cycle; independent worker lease, >=50% battery, nominal thermal state. EOF requests restoration. One guarded00 fallback only if necessary; no retry.'})
    child = subprocess.Popen([str(common.BINARY),'--cycle-120'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,env=common.ENV,start_new_session=True)
    events,error = collect(child,operation,common.continuous_nanoseconds)
    recovery = common.verify_recovery(lambda:common.invoke('--inspect'),common.leases_available,lambda:common.invoke('--recover'))
    final = recovery.get('inspection',{})
    packets = final.get('packets',[])
    inspection = {'exit':final.get('exit'),'packet':packets[-1] if packets else {},'receivedAt':common.continuous_nanoseconds()}
    closed = common.journal_phase() == 'restored'
    qualified = error is None and evidence.qualifies(events,child.returncode,inspection,recovery.get('fallbackUsed',True),closed)
    common.save(stage,'trace.json',events)
    result = {'qualified':qualified,'guardianExit':child.returncode,'errorType':error,'samples':len(events),
        'recovery':recovery,'journalRestored':closed,'automaticControlEnabled':False}
    common.save(stage,'result.json',result)
    print(json.dumps(result,indent=2)); print('Evidence:',stage)
    return 0 if qualified else 1

if __name__ == '__main__': sys.exit(main())
