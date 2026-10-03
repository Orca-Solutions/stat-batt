"""Software only: never launch the sleep or hardware lab."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('sleep_trial', Path(__file__).with_name('adapter-sleep-trial.py'))
trial = importlib.util.module_from_spec(spec); spec.loader.exec_module(trial)

class SleepTrialTests(unittest.TestCase):
    def test_gate_blocks_before_loading_or_launching_hardware(self):
        with patch.object(trial.subprocess, 'Popen') as launch:
            with self.assertRaises(SystemExit): trial.main()
            launch.assert_not_called()

    def test_watchdog_restoration_does_not_qualify_sleep_path(self):
        self.assertFalse(trial.verified_result({'stopReason': 'deadlineOrWorkerExit',
            'restoreExit': 0, 'phase': 'restoreAttemptCompleted'}))

    def test_only_verified_eof_restoration_qualifies(self):
        result = {'stopReason': 'ownerEOF', 'restoreExit': 0, 'phase': 'restoreAttemptCompleted',
            'workerStdout': json.dumps({'mode': 'trialDisconnect', 'hardware': {'outcome': 0, 'baselineHex': '00', 'readbackHex': '08'}}),
            'restoreStdout': json.dumps({'mode': 'guardianRestore', 'hardware': {'outcome': 0, 'baselineHex': '08', 'readbackHex': '00'},
                'result': 'restoredZeroExternalSourceObserved', 'after': {'source': 'adapter'}})}
        self.assertTrue(trial.verified_result(result))
        for key in result:
            incomplete = dict(result); del incomplete[key]
            self.assertFalse(trial.verified_result(incomplete))
        self.assertFalse(trial.verified_result(dict(result, restoreExit=1)))
        restore = json.loads(result['restoreStdout'])
        restore['hardware']['baselineHex'] = '00'
        self.assertFalse(trial.verified_result(dict(result, restoreStdout=json.dumps(restore))))

if __name__ == '__main__': unittest.main()
