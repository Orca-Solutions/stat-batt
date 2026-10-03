import importlib.util
from pathlib import Path
import io
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location('trial', Path(__file__).with_name('long-pause-trial.py'))
trial = importlib.util.module_from_spec(spec); spec.loader.exec_module(trial)

class Child:
    def __init__(self, polls):
        self.stdin = io.BytesIO(); self.stdout = mock.Mock(); self.stdout.fileno.return_value = 17
        self.poll = mock.Mock(side_effect=polls); self.wait = mock.Mock(return_value=0)
        self.kill = mock.Mock(); self.terminate = mock.Mock()

class TrialTests(unittest.TestCase):
    def test_disabled_cannot_launch_or_load_helpers(self):
        with mock.patch.object(trial.subprocess, 'Popen') as launch, mock.patch.object(trial, 'pinned_module') as load:
            with self.assertRaises(SystemExit): trial.main()
            launch.assert_not_called(); load.assert_not_called()
    def test_malformed_output_closes_owner_and_never_kills(self):
        child = Child([None])
        with mock.patch.object(trial.select, 'select', side_effect=[([child.stdout],[],[]),([],[],[])]), mock.patch.object(trial.os, 'read', return_value=b'not-json\n'):
            events,error = trial.collect(child,'operation',lambda:100)
        self.assertEqual(events,[]); self.assertIsNotNone(error)
        self.assertTrue(child.stdin.closed); child.wait.assert_called_once_with(timeout=12)
        child.kill.assert_not_called(); child.terminate.assert_not_called()
    def test_interrupt_still_returns_unknown_after_owner_cleanup(self):
        child = Child([None])
        with mock.patch.object(trial.select, 'select', side_effect=[KeyboardInterrupt(),([],[],[])]):
            _,error = trial.collect(child,'operation',lambda:100)
        self.assertEqual(error,'KeyboardInterrupt'); self.assertTrue(child.stdin.closed)
        child.kill.assert_not_called(); child.terminate.assert_not_called()
    def test_exited_child_final_packet_is_not_lost(self):
        child = Child([0,0])
        packet=b'{"phase":"rejected","failure":"hardware"}\n'
        with mock.patch.object(trial.select,'select',side_effect=[([child.stdout],[],[]),([],[],[])]), mock.patch.object(trial.os,'read',return_value=packet):
            events,error = trial.collect(child,'operation',lambda:100)
        self.assertIsNone(error); self.assertEqual(events[0]['packet']['failure'],'hardware')
        self.assertTrue(child.stdin.closed)
if __name__=='__main__': unittest.main()
