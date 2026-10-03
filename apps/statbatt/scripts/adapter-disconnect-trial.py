#!/usr/bin/python3
"""SOURCE-ONLY qualification packet; execution intentionally disabled pending review.

Guardian is a separate root process/session. It owns the inhibition worker and
reaps that worker before restoration, so a living worker cannot issue a delayed
inhibit after restoration. Shared kernel/firmware failure is not solved.
"""
import datetime
import hashlib
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile
import time

ENABLED = False  # Requires explicit source review + physical recovery decision.
EXPECTED_BINARY = None  # Must be replaced by the independently reviewed build SHA256.
ENV = {'PATH': '/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': '/var/root'}
HOLD_SECONDS = 2.0  # Restore requested by two seconds; not a firmware-expiring latch.


def save(stage, name, record):
    temporary = stage / (name + '.new')
    with temporary.open('w') as f:
        json.dump(record, f, indent=2)
        f.flush()
        os.fsync(f.fileno())
    temporary.replace(stage / name)
    fd = os.open(stage, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def process_preflight():
    lines = subprocess.run(['/bin/ps', '-axo', 'comm='], capture_output=True,
                           text=True, check=True, timeout=3).stdout.splitlines()
    blocked = {'statbatt', 'energiza', 'aldente', 'battery toolkit', 'batterytoolkit',
               'batt', 'batterytoolkitd', 'me.mhaeuser.batterytoolkitd', 'shortcuts'}
    return bool(lines) and not any(Path(line.strip()).name.lower() in blocked for line in lines)


def inhibition_acknowledged(data):
    try:
        report, _ = json.JSONDecoder().raw_decode(data.decode().lstrip())
        hardware = report.get('hardware', {})
        return report.get('mode') == 'trialDisconnect' and hardware.get('outcome') == 0 and hardware.get('baselineHex') == '00' and hardware.get('readbackHex') == '08'
    except (ValueError, UnicodeError, AttributeError):
        return False


def guardian(stage, observe_worker=False):
    # Stage is inherited cwd; no command-line path or payload accepted.
    info = stage.stat()
    if info.st_uid != 0 or info.st_mode & 0o077:
        raise RuntimeError('guardianStageNotPrivateRootOwned')
    executable = stage / 'lab'
    if hashlib.sha256(executable.read_bytes()).hexdigest() != EXPECTED_BINARY:
        raise RuntimeError('guardianBinaryHashMismatch')
    worker = None
    sleeper = None
    gate_sent = False
    writer_reaped = True
    worker_prefix = b''
    worker_acknowledged = False
    record = {'phase': 'guardianPrepared', 'holdSeconds': HOLD_SECONDS, 'journalErrors': []}

    def evidence():
        # Once G is possible, evidence failure must never bypass restoration.
        try:
            save(stage, 'guardian.json', record)
        except Exception as error:
            record['journalErrors'].append(type(error).__name__)

    try:
        # A separate root process owns this assertion through writer termination AND
        # restoration. Killing the inhibition worker cannot release this assertion.
        sleeper = subprocess.Popen([str(executable), '--guardian-sleep-hold'],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            env=ENV, start_new_session=True)
        if not select.select([sleeper.stdout], [], [], 5)[0] or sleeper.stdout.readline() != b'READY\n':
            raise RuntimeError('guardianSleepAssertionNotReady')
        # Before arming, evidence is mandatory and any failure aborts without G.
        save(stage, 'guardian.json', record)
        print('READY', flush=True)
        if not select.select([sys.stdin], [], [], 5)[0] or os.read(0, 1) != b'G':
            return 1
        worker = subprocess.Popen([str(executable), '--trial-disconnect-worker'],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            env=ENV, start_new_session=True)
        if not select.select([worker.stdout], [], [], 5)[0] or worker.stdout.readline() != b'READY\n':
            raise RuntimeError('workerNotReady')
        if select.select([sys.stdin], [], [], 0)[0] or sleeper.poll() is not None:
            raise RuntimeError('supervisorOrSleepAssertionGoneBeforeGate')
        record.update(phase='inhibitionIntent', workerPID=worker.pid)
        save(stage, 'guardian.json', record)
        gate_time = time.monotonic()
        deadline = gate_time + HOLD_SECONDS
        record.update(gateMonotonicSeconds=gate_time)
        gate_sent = True  # Conservative intent before pipe write.
        writer_reaped = False
        worker.stdin.write(b'G')
        worker.stdin.flush()
        record.update(phase='inhibitionGateSent')
        evidence()
        record['stopReason'] = 'deadlineOrWorkerExit'
        while time.monotonic() < deadline and worker.poll() is None:
            if observe_worker and len(worker_prefix) < 16384 and select.select([worker.stdout], [], [], 0)[0]:
                worker_prefix += os.read(worker.stdout.fileno(), min(4096, 16384 - len(worker_prefix)))
                if not worker_acknowledged and inhibition_acknowledged(worker_prefix):
                    worker_acknowledged = True
                    record.update(phase='inhibitionAcknowledged', inhibitionAcknowledged=True)
                    evidence()
            if sleeper.poll() is not None:
                record['stopReason'] = 'sleepAssertionLost'
                break
            if select.select([sys.stdin], [], [], min(0.02, max(0, deadline-time.monotonic())))[0]:
                record['stopReason'] = 'ownerEOF' if os.read(0, 1) == b'' else 'unexpectedOwnerData'
                break
        record['stopMonotonicSeconds'] = time.monotonic()
    except Exception as error:
        record.update(guardianError=type(error).__name__)
    finally:
        if worker is not None:
            try:
                if worker.poll() is None:
                    worker.kill()
                stdout, stderr = worker.communicate(timeout=1)
                writer_reaped = True
                record.update(workerExit=worker.returncode, workerStdout=(worker_prefix + stdout).decode(errors='replace'),
                              workerStderr=stderr.decode(errors='replace'))
            except Exception as error:
                writer_reaped = False
                record.update(phase='workerUnreapedRestorationUnsafeUnknown', workerError=type(error).__name__)
        if gate_sent and writer_reaped:
            record.update(phase='restoreIntent')
            evidence()  # Best effort, never an exception barrier before restoration.
            try:
                result = subprocess.run([str(executable), '--guardian-restore'],
                    capture_output=True, text=True, timeout=5, env=ENV)
                record.update(phase='restoreAttemptCompleted', restoreExit=result.returncode,
                              restoreStdout=result.stdout, restoreStderr=result.stderr)
            except subprocess.TimeoutExpired:
                record.update(phase='restoreTimedOutUnknown')
            except Exception as error:
                record.update(phase='restoreFailedUnknown', error=type(error).__name__)
        elif not gate_sent:
            record.update(phase='cancelledBeforeInhibition')
        # Keep guardian assertion through the entire restore attempt, including failures.
        if sleeper is not None:
            try:
                sleeper.stdin.close()
                sleeper.wait(timeout=1)
            except Exception as error:
                record.update(sleepAssertionReleaseError=type(error).__name__)
        evidence()
        print('GUARDIAN_RESULT ' + json.dumps(record), flush=True)
    return 0 if record.get('restoreExit') == 0 else 1


def prior_inspection_packet():
    path = Path('/private/tmp/statbatt-adapter-inspect.json')
    data = path.read_bytes()
    report = json.loads(data)
    timestamp = datetime.datetime.fromisoformat(report['generatedAtUTC'].replace('Z', '+00:00'))
    age = (datetime.datetime.now(datetime.timezone.utc) - timestamp).total_seconds()
    hardware = report.get('hardware', {})
    target = report.get('platform', {})
    if not (0 <= age <= 300 and report.get('mode') == 'inspect'
            and report.get('result') == 'readOnlyInspectionCompleted'
            and hardware.get('baselineHex') == '00' and hardware.get('size') == 1
            and hardware.get('type') == 0x6865785f and hardware.get('attributes') == 0xD4
            and target.get('model') == 'Mac16,13' and target.get('architecture') == 'arm64'
            and target.get('operatingSystemVersion') == '27.0.1'
            and target.get('operatingSystemBuild') == '26A434'
            and target.get('firmwareVersion') == 'mBoot-20457.1.29'):
        raise RuntimeError('freshExactBaselineInspectionRequired')
    return {'path': str(path), 'sha256': hashlib.sha256(data).hexdigest(),
            'generatedAtUTC': report['generatedAtUTC'], 'report': report}


def disconnect_owner_after_gate(child, stage):
    """Close the ownership pipe; this observer never controls the restore deadline."""
    gate_deadline = time.monotonic() + 5
    while child.poll() is None and time.monotonic() < gate_deadline:
        try:
            progress = json.loads((stage / 'guardian.json').read_bytes())
        except (OSError, ValueError):
            progress = {}
        if progress.get('phase') == 'inhibitionGateSent':
            time.sleep(1.25)
            break
        time.sleep(0.01)
    child.stdin.close()


def main():
    if not ENABLED or EXPECTED_BINARY is None:
        raise SystemExit('Source-only: emergency hardware recovery and trial review remain unresolved. Nothing executed.')
    if os.getuid() != 0 or os.geteuid() != 0:
        raise SystemExit('Administrator identity required; no automatic elevation.')
    if sys.argv[1:] == ['--guardian']:
        return guardian(Path.cwd())
    if sys.argv[1:] == ['--sleep-guardian']:
        return guardian(Path.cwd(), observe_worker=True)
    owner_disconnect = sys.argv[1:] == ['--approved-owner-disconnect-trial']
    if (sys.argv[1:] != ['--approved-bounded-trial'] and not owner_disconnect) or not process_preflight():
        raise SystemExit('Explicit mode and stopped controllers required.')
    binary = Path(__file__).resolve().parent.parent / '.build/release/statbatt-adapter-lab'
    data = binary.read_bytes()
    if hashlib.sha256(data).hexdigest() != EXPECTED_BINARY:
        raise SystemExit('Reviewed binary hash mismatch.')
    inspection = prior_inspection_packet()
    stage = Path(tempfile.mkdtemp(prefix='statbatt-adapter-trial-', dir='/private/tmp'))
    # Copy both reviewed supervisor and binary into private root-owned staging.
    for name, contents in [('lab', data), ('supervisor.py', Path(__file__).read_bytes())]:
        with (stage / name).open('xb') as f:
            f.write(contents); f.flush(); os.fsync(f.fileno())
        (stage / name).chmod(0o500)
    save(stage, 'intent.json', {'phase': 'prepared', 'operation': 'CHIE00->08->00',
        'binarySHA256': EXPECTED_BINARY, 'maximumRequestedHoldSeconds': HOLD_SECONDS,
        'timestampUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'priorInspection': inspection, 'argv': [str(stage / 'lab'), '--trial-disconnect-worker'],
        'authorization': 'Explicit operator invocation ' + sys.argv[1] + '; controllers and shortcuts stopped',
        'ownerDisconnectTest': owner_disconnect,
        'limits': 'Software deadline only; hardware restoration and emergency recovery unproven.'})
    # File-backed output cannot block the guardian on a full parent-owned pipe.
    output_file = (stage / 'guardian.stdout').open('xb')
    error_file = (stage / 'guardian.stderr').open('xb')
    child = subprocess.Popen([sys.executable, '-I', str(stage / 'supervisor.py'), '--guardian'],
        stdin=subprocess.PIPE, stdout=output_file, stderr=error_file,
        cwd=stage, env=ENV, start_new_session=True)
    def output_text(name):
        with (stage / name).open('rb') as stream:
            return stream.read(65536).decode(errors='replace')
    try:
        readiness_deadline = time.monotonic() + 5
        while 'READY' not in output_text('guardian.stdout').splitlines():
            if child.poll() is not None or time.monotonic() >= readiness_deadline:
                raise RuntimeError('guardianNotReady')
            time.sleep(0.01)
        save(stage, 'armed.json', {'phase': 'guardianReadyInhibitionAuthorized',
            'timestampUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'authorization': 'Same explicit bounded-trial invocation recorded in intent.json',
            'binarySHA256': EXPECTED_BINARY, 'guardianPID': child.pid,
            'argv': [str(stage / 'lab'), '--trial-disconnect-worker'],
            'maximumRequestedHoldSeconds': HOLD_SECONDS})
        child.stdin.write(b'G'); child.stdin.flush()
        if owner_disconnect:
            # Exercise the same EOF restoration path as owner process loss while
            # retaining this observer to collect evidence. Never extend the guardian's
            # two-second deadline. Do not claim this is a daemon crash test.
            disconnect_owner_after_gate(child, stage)
        # Do not kill guardian on timeout. Closing pipe requests immediate restoration.
        try:
            child.wait(timeout=12)
        except subprocess.TimeoutExpired:
            if not child.stdin.closed:
                child.stdin.close()
            print('Guardian still running; recovery unknown. Do not retry.')
            return 1
        stdout = output_text('guardian.stdout')
        stderr = output_text('guardian.stderr')
        owner_eof_observed = False
        for line in stdout.splitlines():
            if line.startswith('GUARDIAN_RESULT '):
                result = json.loads(line[len('GUARDIAN_RESULT '):])
                owner_eof_observed = result.get('stopReason') == 'ownerEOF'
                print(json.dumps(result, indent=2))
        if stderr:
            print('Guardian diagnostics:', stderr)
        if not any(line.startswith('GUARDIAN_RESULT ') for line in stdout.splitlines()):
            print('Guardian returned without a structured result; recovery unknown. Do not retry.')
            return 1
        if owner_disconnect and not owner_eof_observed:
            print('Owner EOF recovery was not exercised; this qualification is inconclusive even if restoration succeeded.')
            return 1
        return child.returncode
    finally:
        if not child.stdin.closed:
            child.stdin.close()
        output_file.close()
        error_file.close()
        print('Preserved qualification evidence:', stage)


if __name__ == '__main__':
    sys.exit(main())
