#!/usr/bin/python3
"""Supervise one explicitly authorized enabled-state test; never elevate itself."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

EXPECTED = '7bc43092acad9083ec40fd778edeac10a044a5876fbdb0ec38b2f11b829f07b6'
BINARY = Path(__file__).resolve().parent.parent / '.build/release/statbatt-adapter-lab'

def main():
    if sys.argv[1:] != ['--approved-enabled-state-test'] or os.getuid() != 0 or os.geteuid() != 0:
        raise SystemExit('Requires administrator execution and --approved-enabled-state-test. No automatic elevation.')
    # System-wide process inventory supplements AppKit's session-scoped checks.
    processes = subprocess.run(['/bin/ps', '-axo', 'comm='], capture_output=True,
                               text=True, check=True, timeout=3).stdout.splitlines()
    if not processes:
        raise SystemExit('Process inventory unavailable; nothing executed.')
    blocked = {'statbatt', 'energiza', 'aldente', 'battery toolkit', 'batterytoolkit',
               'batt', 'batterytoolkitd', 'me.mhaeuser.batterytoolkitd', 'shortcuts'}
    if any(Path(line.strip()).name.lower() in blocked for line in processes):
        raise SystemExit('Close charging controllers, StatBatt and running shortcuts first; nothing executed.')
    inspection = Path('/private/tmp/statbatt-adapter-inspect.json').read_bytes()
    baseline = json.loads(inspection)
    if baseline.get('result') != 'readOnlyInspectionCompleted' or baseline.get('hardware', {}).get('baselineHex') != '00':
        raise SystemExit('Prior baseline packet absent or unexpected; nothing executed.')
    data = BINARY.read_bytes()
    if hashlib.sha256(data).hexdigest() != EXPECTED:
        raise SystemExit('Reviewed binary hash mismatch; nothing executed.')
    # Root-owned private staging removes replacement races in the executable path.
    stage = Path(tempfile.mkdtemp(prefix='statbatt-admin-enabled-', dir='/private/tmp'))
    executable = stage / 'lab'
    with executable.open('xb') as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    executable.chmod(0o500)
    journal = stage / 'result.json'
    record = dict(timestampUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  binarySHA256=EXPECTED, operation='CHIE 00-to-00 only', timeoutSeconds=10,
                  phase='intentRecorded', argv=[str(executable), '--test-restore-admin'],
                  priorInspectionSHA256=hashlib.sha256(inspection).hexdigest(),
                  priorInspection=baseline, authorization='Explicit operator invocation of approved enabled-state test')
    def save():
        temporary = stage / 'record.new'
        with temporary.open('w') as stream:
            json.dump(record, stream, indent=2)
            stream.flush()
            os.fsync(stream.fileno())
        temporary.replace(journal)
        fd = os.open(stage, os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    save()
    try:
        result = subprocess.run([str(executable), '--test-restore-admin'], capture_output=True,
                                text=True, timeout=10, env={'PATH':'/usr/bin:/bin:/usr/sbin:/sbin', 'HOME':'/var/root'})
        record.update(phase='completed', exitCode=result.returncode, stdout=result.stdout, stderr=result.stderr)
    except subprocess.TimeoutExpired:
        record.update(phase='timedOutUnknownNoRetry')
    except Exception as error:
        record.update(phase='supervisorErrorUnknownNoRetry', error=type(error).__name__)
    save()
    print(json.dumps(record, indent=2))
    print('Preserved result:', journal)
    executable.unlink()
    return 0 if record.get('exitCode') == 0 else 1

if __name__ == '__main__':
    sys.exit(main())
