#!/usr/bin/python3
"""SOURCE ONLY. Explicit sleep + fixed CHIE cycle; requires separate physical authorization.

No timing guarantee survives kernel/I/O stalls. An ACK_UNKNOWN can permit sleep
with restoration unproved. This is a qualification experiment, not protection.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ENABLED = False
EXPECTED_SLEEP_BINARY = None


def verified_result(record):
    try:
        worker, _ = json.JSONDecoder().raw_decode(record.get('workerStdout', '').lstrip())
        restore = json.loads(record.get('restoreStdout', ''))
        before = worker.get('hardware', {})
        after = restore.get('hardware', {})
        return (record.get('stopReason') == 'ownerEOF' and record.get('restoreExit') == 0
            and record.get('phase') == 'restoreAttemptCompleted'
            and worker.get('mode') == 'trialDisconnect' and before.get('outcome') == 0
            and before.get('baselineHex') == '00' and before.get('readbackHex') == '08'
            and restore.get('mode') == 'guardianRestore' and after.get('outcome') == 0
            and after.get('baselineHex') == '08' and after.get('readbackHex') == '00'
            and restore.get('result') == 'restoredZeroExternalSourceObserved'
            and restore.get('after', {}).get('source') == 'adapter')
    except (ValueError, AttributeError): return False


def main():
    if not ENABLED or EXPECTED_SLEEP_BINARY is None:
        raise SystemExit('Source-only sleep recovery experiment. Nothing executed.')
    if os.getuid() != 0 or os.geteuid() != 0 or sys.argv[1:] != ['--approved-sleep-recovery-trial']:
        raise SystemExit('Explicit administrator invocation required; no elevation.')
    scripts = Path(__file__).resolve().parent
    spec = importlib.util.spec_from_file_location('guardian_packet', scripts / 'adapter-disconnect-trial.py')
    packet = importlib.util.module_from_spec(spec); spec.loader.exec_module(packet)
    if not packet.ENABLED or packet.EXPECTED_BINARY is None or not packet.process_preflight():
        raise SystemExit('Reviewed guardian and stopped controllers required.')
    binaries = [('lab', scripts.parent / '.build/release/statbatt-adapter-lab', packet.EXPECTED_BINARY),
                ('sleep-lab', scripts.parent / '.build/release/statbatt-sleep-lab', EXPECTED_SLEEP_BINARY)]
    contents = []
    for name, path, expected in binaries:
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != expected: raise SystemExit('Reviewed binary mismatch')
        contents.append((name, data))
    baseline = packet.prior_inspection_packet()
    stage = Path(tempfile.mkdtemp(prefix='statbatt-sleep-trial-', dir='/private/tmp'))
    for name, data in contents + [('supervisor.py', (scripts / 'adapter-disconnect-trial.py').read_bytes())]:
        with (stage / name).open('xb') as stream:
            stream.write(data); stream.flush(); os.fsync(stream.fileno())
        (stage / name).chmod(0o500)
    packet.save(stage, 'intent.json', {'authorization': sys.argv[1], 'priorInspection': baseline,
        'binarySHA256': packet.EXPECTED_BINARY, 'sleepBinarySHA256': EXPECTED_SLEEP_BINARY,
        'operation': 'CHIE00->08->00 with explicit system sleep request',
        'holdSeconds': packet.HOLD_SECONDS, 'sleepAcknowledgmentWaitSeconds': 8,
        'timestampUTC': packet.datetime.datetime.now(packet.datetime.timezone.utc).isoformat()})
    streams, children = [], []
    def launch(argv, label):
        out = (stage / (label + '.stdout')).open('xb'); err = (stage / (label + '.stderr')).open('xb')
        streams.extend([out, err])
        process = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=out, stderr=err,
                                   cwd=stage, env=packet.ENV, start_new_session=True)
        children.append(process); return process
    def lines(label):
        with (stage / (label + '.stdout')).open('rb') as stream:
            return stream.read(65536).decode(errors='replace').splitlines()
    def ready(process, label):
        end = time.monotonic() + 5
        while time.monotonic() < end and process.poll() is None:
            if 'READY' in lines(label): return
            time.sleep(.01)
        raise RuntimeError(label + 'NotReady')
    guardian = observer = None
    try:
        observer = launch([str(stage / 'sleep-lab'), '--approved-sleep-recovery-observer'], 'sleep')
        ready(observer, 'sleep')
        guardian = launch([sys.executable, '-I', str(stage / 'supervisor.py'), '--sleep-guardian'], 'guardian')
        ready(guardian, 'guardian')
        packet.save(stage, 'armed.json', {'guardianPID': guardian.pid, 'observerPID': observer.pid,
                    'authorization': '--approved-sleep-recovery-trial'})
        guardian.stdin.write(b'G'); guardian.stdin.flush()
        requested = owner_closed = False
        end = time.monotonic() + 12
        result = {}
        while time.monotonic() < end:
            observer_gone = observer.poll() is not None
            if observer_gone and not guardian.stdin.closed:
                guardian.stdin.close()
            try: progress = json.loads((stage / 'guardian.json').read_bytes())
            except (OSError, ValueError): progress = {}
            if not observer_gone and not requested and progress.get('phase') == 'inhibitionAcknowledged':
                observer.stdin.write(b'S'); observer.stdin.flush(); requested = True
            if 'WILL_SLEEP' in lines('sleep') and not owner_closed:
                if not guardian.stdin.closed: guardian.stdin.close()
                owner_closed = True
            for line in lines('guardian'):
                if line.startswith('GUARDIAN_RESULT '): result = json.loads(line[16:])
            if result:
                if not observer_gone:
                    observer.stdin.write(b'R' if owner_closed and verified_result(result) else b'F')
                    observer.stdin.flush()
                break
            time.sleep(.01)
        if not guardian.stdin.closed: guardian.stdin.close()
        # Closing observer owner pipe acknowledges unknown if it is still waiting.
        # On verified reply, wait briefly for its explicit acknowledgment evidence first.
        if result:
            try: observer.wait(timeout=1)
            except subprocess.TimeoutExpired: pass
        if not observer.stdin.closed: observer.stdin.close()
        summary = {'guardian': result, 'sleepEvents': lines('sleep'),
                   'qualified': owner_closed and verified_result(result) and 'ACK_RESTORED' in lines('sleep')}
        packet.save(stage, 'result.json', summary)
        print(json.dumps(summary, indent=2))
        return 0 if summary['qualified'] else 1
    finally:
        # Never kill the independent restore guardian. EOF requests restoration.
        for process in children:
            if not process.stdin.closed: process.stdin.close()
        for stream in streams: stream.close()
        print('Preserved sleep qualification evidence:', stage)


if __name__ == '__main__':
    sys.exit(main())
