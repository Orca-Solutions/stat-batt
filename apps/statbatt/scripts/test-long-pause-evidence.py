import importlib.util
from pathlib import Path
import unittest
import copy
spec = importlib.util.spec_from_file_location('evidence', Path(__file__).with_name('long-pause-evidence.py'))
evidence = importlib.util.module_from_spec(spec); spec.loader.exec_module(evidence)

class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.events = [{'receivedAt': at + 2, 'packet': {'phase':'inhibited', 'sampledAt':at, 'sourceAt':at+1,
            'holdSeconds':120,'key':8,'outcome':0,'battery':True,'adapter':False,'stateOfCharge':80}}
            for at in range(1_000_000_000,121_000_000_000,100_000_000)]
        self.events += [
            {'receivedAt':121_000_000_000,'packet':{'phase':'workerRestoring','recoveryCause':'ownerEOF'}},
            {'receivedAt':121_100_000_002,'packet':{'phase':'restored','sampledAt':121_100_000_000,
                'sourceAt':121_100_000_001,'outcome':0,'key':0,'adapter':True,'battery':False}},
            {'receivedAt':121_200_000_000,'packet':{'phase':'writerReaped','reaped':True}}
        ]
        self.final = {'exit':0,'receivedAt':122_000_000_002,'packet':{'phase':'inspection',
            'sampledAt':122_000_000_000,'sourceAt':122_000_000_001,'outcome':0,'key':0,'adapter':True,'battery':False}}
    def accepted(self, **kwargs):
        args=dict(events=self.events,guardian_exit=0,final_inspection=self.final,fallback_used=False,journal_restored=True)
        args.update(kwargs); return evidence.qualifies(**args)
    def test_complete_bounded_trace(self): self.assertTrue(self.accepted())
    def test_short_stale_gapped_and_wrong_mode_rejected(self):
        self.assertFalse(self.accepted(events=self.events[:20]))
        self.assertFalse(self.accepted(events=self.events[:10]+self.events[30:]))
        for field,value in [('holdSeconds',2),('key',0),('battery',False),('stateOfCharge',49),('sampledAt',999_000_000_000)]:
            altered=copy.deepcopy(self.events); altered[100]['packet'][field]=value
            self.assertFalse(self.accepted(events=altered))
    def test_fallback_failure_or_unclosed_journal_cannot_pass(self):
        self.assertFalse(self.accepted(fallback_used=True))
        self.assertFalse(self.accepted(guardian_exit=1))
        self.assertFalse(self.accepted(journal_restored=False))
        final=copy.deepcopy(self.final); final['packet']['adapter']=False
        self.assertFalse(self.accepted(final_inspection=final))
    def test_late_restoration_and_nonobject_final_packet_rejected(self):
        final=copy.deepcopy(self.final)
        final['packet']['sampledAt']=127_000_000_000
        final['packet']['sourceAt']=127_000_000_001
        final['receivedAt']=127_000_000_002
        self.assertFalse(self.accepted(final_inspection=final))
        for packet in [None, [], "invalid", 1]:
            final=copy.deepcopy(self.final); final['packet']=packet
            self.assertFalse(self.accepted(final_inspection=final))
    def test_parent_only_or_late_worker_restore_cannot_qualify(self):
        for phase in ['workerRestoring','restored','writerReaped']:
            self.assertFalse(self.accepted(events=[e for e in self.events if e['packet']['phase'] != phase]))
        late=copy.deepcopy(self.events)
        late[-2]['packet']['sampledAt']=127_000_000_000
        late[-2]['packet']['sourceAt']=127_000_000_001
        late[-2]['receivedAt']=127_000_000_002
        late[-1]['receivedAt']=127_100_000_000
        self.assertFalse(self.accepted(events=late))
        wrong=copy.deepcopy(self.events); wrong[-3]['packet']['recoveryCause']='sleep'
        self.assertFalse(self.accepted(events=wrong))
if __name__=='__main__' : unittest.main()
