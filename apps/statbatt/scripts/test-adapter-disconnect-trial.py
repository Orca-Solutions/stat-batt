"""Software-only guardian sequencing tests; all process calls are mocked."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('trial', Path(__file__).with_name('adapter-disconnect-trial.py'))
trial = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trial)

class GuardianTests(unittest.TestCase):
    def test_sleep_progress_requires_complete_positive_inhibition_report(self):
        report = {'mode': 'trialDisconnect', 'hardware': {'outcome': 0, 'baselineHex': '00', 'readbackHex': '08'}}
        data = json.dumps(report).encode()
        self.assertFalse(trial.inhibition_acknowledged(data[:-1]))
        self.assertTrue(trial.inhibition_acknowledged(data + b'\n{"partialTrace"'))
        report['hardware']['readbackHex'] = '00'
        self.assertFalse(trial.inhibition_acknowledged(json.dumps(report).encode()))

    def test_entry_point_is_closed_before_process_access(self):
        with patch.object(trial.subprocess, 'Popen') as launch:
            with self.assertRaises(SystemExit):
                trial.main()
            launch.assert_not_called()

    def exercise(self, parent_dies=False, stuck=False, journal_fails=False, observe_worker=False):
        events, records = [], []
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'lab').write_bytes(b'fixture-not-executable')
            class Stage:
                def stat(self): return types.SimpleNamespace(st_uid=0, st_mode=0o700)
                def __truediv__(self, value): return root / value
            class Gate:
                def write(self, value): events.append(('gate', value))
                def flush(self): pass
            sleeper = types.SimpleNamespace(stdin=types.SimpleNamespace(close=lambda: events.append(('sleepRelease', None))),
                stdout=io.BytesIO(b'READY\n'), stderr=io.BytesIO(), poll=lambda: None,
                wait=lambda timeout: events.append(('sleepReaped', None)))
            class WorkerOutput(io.BytesIO):
                def fileno(self): return 99
            worker = types.SimpleNamespace(pid=123, stdin=Gate(), stdout=WorkerOutput(b'READY\n'),
                stderr=io.BytesIO(), returncode=-9, poll=lambda: None,
                kill=lambda: events.append(('kill', None)))
            def communicate(timeout):
                events.append(('reap', None))
                if stuck: raise trial.subprocess.TimeoutExpired('fixture', timeout)
                return b'{}', b''
            worker.communicate = communicate
            def restore(*args, **kwargs):
                events.append(('restore', args[0][-1]))
                return types.SimpleNamespace(returncode=0, stdout='{}', stderr='')
            # First G receipt, worker READY, parent-alive check, optional parent EOF.
            selections = [([sleeper.stdout], [], []), ([trial.sys.stdin], [], []), ([worker.stdout], [], []), ([], [], [])]
            if observe_worker: selections.append(([worker.stdout], [], []))
            if parent_dies: selections.append(([trial.sys.stdin], [], []))
            clock = [0, .1, .2, .3] if parent_dies else [0, 3, 3]
            def save(stage, name, record):
                records.append(dict(record))
                if journal_fails and record['phase'] == 'restoreIntent':
                    raise OSError('simulated disk full')
            reads = [b'G']
            if observe_worker:
                reads.append(json.dumps({'mode': 'trialDisconnect', 'hardware': {'outcome': 0, 'baselineHex': '00', 'readbackHex': '08'}}).encode())
            reads.append(b'')
            with patch.object(trial, 'EXPECTED_BINARY', hashlib.sha256(b'fixture-not-executable').hexdigest()), \
                 patch.object(trial, 'save', side_effect=save), \
                 patch.object(trial.os, 'read', side_effect=reads), \
                 patch.object(trial.select, 'select', side_effect=selections), \
                 patch.object(trial.time, 'monotonic', side_effect=clock), \
                 patch.object(trial.subprocess, 'Popen', side_effect=[sleeper, worker]), \
                 patch.object(trial.subprocess, 'run', side_effect=restore):
                result = trial.guardian(Stage(), observe_worker=observe_worker)
        return result, events, records

    def test_sleep_guardian_preserves_consumed_report_and_reaps_before_restore(self):
        result, events, records = self.exercise(parent_dies=True, observe_worker=True)
        self.assertEqual(result, 0)
        self.assertTrue(any(record['phase'] == 'inhibitionAcknowledged' for record in records))
        self.assertTrue(trial.inhibition_acknowledged(records[-1]['workerStdout'].encode()))
        self.assertLess(events.index(('reap', None)), events.index(('restore', '--guardian-restore')))

    def test_deadline_reaps_writer_before_restore(self):
        result, events, _ = self.exercise()
        self.assertEqual(result, 0)
        self.assertEqual(events, [('gate', b'G'), ('kill', None), ('reap', None), ('restore', '--guardian-restore'), ('sleepRelease', None), ('sleepReaped', None)])

    def test_parent_death_restores_without_waiting_deadline(self):
        result, events, records = self.exercise(parent_dies=True)
        self.assertEqual(result, 0)
        self.assertIn(('restore', '--guardian-restore'), events)
        self.assertLess(events.index(('restore', '--guardian-restore')), events.index(('sleepRelease', None)))
        self.assertEqual(records[-1]['stopReason'], 'ownerEOF')
        self.assertLess(records[-1]['stopMonotonicSeconds'] - records[-1]['gateMonotonicSeconds'], trial.HOLD_SECONDS)

    def test_owner_disconnect_closes_only_after_gate_observation(self):
        events = []
        child = types.SimpleNamespace(poll=lambda: None,
            stdin=types.SimpleNamespace(close=lambda: events.append('closed')))
        with tempfile.TemporaryDirectory() as folder:
            stage = Path(folder)
            (stage / 'guardian.json').write_text('{"phase":"inhibitionGateSent"}')
            with patch.object(trial.time, 'monotonic', side_effect=[0, .1]), \
                 patch.object(trial.time, 'sleep', side_effect=lambda seconds: events.append(seconds)):
                trial.disconnect_owner_after_gate(child, stage)
        self.assertEqual(events, [1.25, 'closed'])

    def test_missing_gate_evidence_still_closes_owner_bounded(self):
        events = []
        child = types.SimpleNamespace(poll=lambda: None,
            stdin=types.SimpleNamespace(close=lambda: events.append('closed')))
        with tempfile.TemporaryDirectory() as folder:
            with patch.object(trial.time, 'monotonic', side_effect=[0, .1, 6]), \
                 patch.object(trial.time, 'sleep', side_effect=lambda seconds: events.append(seconds)):
                trial.disconnect_owner_after_gate(child, Path(folder))
        self.assertEqual(events, [.01, 'closed'])

    def test_journal_failure_cannot_skip_restoration(self):
        result, events, records = self.exercise(journal_fails=True)
        self.assertEqual(result, 0)
        self.assertIn(('restore', '--guardian-restore'), events)
        self.assertEqual(records[-1]['journalErrors'], ['OSError'])

    def test_unreaped_writer_is_unknown_not_false_restoration(self):
        result, events, records = self.exercise(stuck=True)
        self.assertEqual(result, 1)
        self.assertFalse(any(kind == 'restore' for kind, _ in events))
        self.assertEqual(records[-1]['phase'], 'workerUnreapedRestorationUnsafeUnknown')

if __name__ == '__main__':
    unittest.main()
