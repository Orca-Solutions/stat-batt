"""Mocked control flow only; no installed binaries or hardware are executed."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location('loss_trial', Path(__file__).with_name('guardian-loss-trial.py'))
trial = importlib.util.module_from_spec(spec); spec.loader.exec_module(trial)


def packet(key):
    return {'phase': 'inhibited' if key == 8 else 'inspection', 'outcome': 0, 'key': key,
            'sampledAt': 100, 'sourceAt': 101, 'battery': key == 8, 'adapter': key == 0}


class GuardianLossTests(unittest.TestCase):
    def setUp(self):
        clock = patch.object(trial, 'continuous_nanoseconds', return_value=102)
        clock.start(); self.addCleanup(clock.stop)

    def test_stale_future_or_failed_inspections_never_qualify(self):
        self.assertFalse(trial.positive(packet(8), 8, now=250_000_101))
        self.assertFalse(trial.positive(packet(8), 8, now=99))
        self.assertFalse(trial.positive(packet(0), 0, now=2_000_000_101))
        recovery = Mock(return_value={'exit': 1, 'packets': []})
        result = trial.verify_recovery(lambda: {'exit': 1, 'packets': [packet(0)]}, lambda: True, recovery)
        self.assertEqual(result['result'], 'restorationUnknown')

    def test_disabled_entrypoint_never_launches(self):
        with patch.object(trial.subprocess, 'Popen') as launch:
            with self.assertRaises(SystemExit): trial.main()
            launch.assert_not_called()

    def test_kill_requires_positive_source_and_occurs_once(self):
        child = Mock()
        self.assertFalse(trial.kill_once(child, dict(packet(8), battery=False), False))
        self.assertFalse(trial.kill_once(child, dict(packet(8), sourceAt=99), False))
        self.assertTrue(trial.kill_once(child, packet(8), False))
        self.assertTrue(trial.kill_once(child, packet(8), True))
        child.kill.assert_called_once_with()

    def test_cycle_exception_returns_for_recovery_after_closing_owner(self):
        child = Mock()
        child.poll.return_value = None
        with patch.object(trial.select, 'select', side_effect=OSError('fixture')):
            killed, events, error, audit = trial.observe_cycle(child, 'fixture-operation')
        self.assertFalse(killed); self.assertEqual(error, 'OSError')
        child.stdin.close.assert_called_once_with()
        child.wait.assert_called_once_with(timeout=12)
        child.kill.assert_not_called()

    def test_broken_owner_close_still_waits_and_returns_for_recovery(self):
        child = Mock()
        child.poll.return_value = 0
        child.stdin.close.side_effect = BrokenPipeError('fixture')
        killed, events, error, audit = trial.observe_cycle(child, 'fixture-operation')
        self.assertFalse(killed); self.assertEqual(error, 'BrokenPipeError')
        child.wait.assert_called_once_with(timeout=12)
        child.kill.assert_not_called()

    def test_independent_restore_never_invokes_fallback(self):
        recover = Mock()
        result = trial.verify_recovery(lambda: {'exit': 0, 'packets': [packet(0)]}, lambda: True, recover)
        self.assertEqual(result['result'], 'independentRestorationVerified')
        recover.assert_not_called()

    def test_independent_proof_cleanup_requires_fresh_zero_and_closed_journal(self):
        recover = Mock(return_value={'exit': 0, 'packets': []})
        inspect = Mock(return_value={'exit': 0, 'packets': [packet(0)]})
        result = trial.cleanup_owned_intent(inspect, lambda: True, recover, lambda: 'restored')
        self.assertTrue(result['verified']); recover.assert_called_once_with()
        result = trial.cleanup_owned_intent(inspect, lambda: True, recover, lambda: 'inhibitionIntent')
        self.assertFalse(result['verified'])
        recover.reset_mock()
        result = trial.cleanup_owned_intent(inspect, lambda: False, recover, lambda: 'restored')
        self.assertFalse(result['verified']); recover.assert_not_called()

    def test_live_writer_prevents_inspection_and_fallback(self):
        inspect, recover = Mock(), Mock()
        result = trial.verify_recovery(inspect, lambda: False, recover, clock=Mock(side_effect=[0, 7]), pause=Mock())
        self.assertEqual(result['result'], 'writerLeaseStillHeldUnknown')
        inspect.assert_not_called(); recover.assert_not_called()

    def test_fallback_is_once_and_never_qualifies_independent_restore(self):
        inspect = Mock(side_effect=[{'exit': 0, 'packets': [dict(packet(0), key=8)]}, {'exit': 0, 'packets': [packet(0)]}])
        recover = Mock(return_value={'exit': 0, 'packets': []})
        result = trial.verify_recovery(inspect, lambda: True, recover)
        self.assertEqual(result['result'], 'fallbackRestorationVerified')
        self.assertTrue(result['fallbackUsed']); recover.assert_called_once_with()

    def test_changed_lease_or_late_recovery_never_triggers_retry(self):
        recover = Mock()
        result = trial.verify_recovery(lambda: {'exit': 0, 'packets': []}, Mock(side_effect=[True, False]), recover)
        self.assertEqual(result['result'], 'leaseChangedUnknown'); recover.assert_not_called()
        inspect = Mock(return_value={'exit': 0, 'packets': []})
        recover = Mock(return_value={'stillRunning': True})
        result = trial.verify_recovery(inspect, lambda: True, recover)
        self.assertEqual(result['result'], 'fallbackStillRunningUnknown')
        inspect.assert_called_once_with(); recover.assert_called_once_with()

if __name__ == '__main__': unittest.main()
