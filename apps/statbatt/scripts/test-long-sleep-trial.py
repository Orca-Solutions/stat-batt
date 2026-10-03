import runpy
import unittest
from pathlib import Path
m = runpy.run_path(str(Path(__file__).with_name('long-sleep-trial.py')))
class EvidenceTests(unittest.TestCase):
    def test_restoration_requires_fresh_positive_readback_and_ac(self):
        packet = dict(phase='restored',outcome=0,key=0,adapter=True,battery=False,sampledAt=10,sourceAt=11)
        check=m['restoration_observed']
        self.assertTrue(check([packet],12))
        for changed in (dict(packet,key=8),dict(packet,outcome=1),dict(packet,adapter=False),
                        dict(packet,sourceAt=13),dict(packet,sampledAt=0),dict(packet,sourceAt=9)):
            self.assertFalse(check([changed],12))
        self.assertFalse(check([packet],2_000_000_011))
    def test_default_cannot_execute(self):
        self.assertFalse(m['ENABLED'])
        with self.assertRaises(SystemExit): m['main']()


from unittest.mock import patch
from types import SimpleNamespace
import json
class FlowTests(unittest.TestCase):
    def run_flow(self, fail=False):
        log=[]
        class Input:
            def __init__(self,name): self.name=name; self.closed=False
            def write(self,value): log.append((self.name,value))
            def flush(self): pass
            def close(self):
                if not self.closed: log.append((self.name,'EOF')); self.closed=True
        class Output:
            def __init__(self,fd): self.fd=fd
            def fileno(self): return self.fd
        class Process:
            def __init__(self,name,fd): self.stdin=Input(name); self.stdout=Output(fd); self.returncode=None
            def poll(self): return self.returncode
            def wait(self,timeout): self.returncode=0
        observer=Process('observer',1); child=Process('guardian',2)
        restored=dict(phase='restored',outcome=0,key=0,adapter=True,battery=False,sampledAt=10,sourceAt=11)
        steps=[(1,b'READY\n'),(2,b'{"fresh":false}\n'),(2,b'{"fresh":true}\n'),
               (1,b'WILL_SLEEP\nWILL_SLEEP\n'),(2,json.dumps(restored).encode()+b'\n'),(2,b''),
               (1,b'ACK_RESTORED\n'),(1,b'')]
        def select_fn(streams,*args):
            if fail and len(steps)==5: raise RuntimeError('injected')
            fd,data=steps[0]
            return ([next(x for x in streams if x.fd==fd)],[],[])
        def read_fn(fd,size):
            expected,data=steps.pop(0); self.assertEqual(fd,expected)
            if not data: (child if fd==2 else observer).returncode=0
            return data
        def launch(*args,**kwargs): log.append(('launch',None)); return child
        common=SimpleNamespace(BINARY='fixed',ENV={},positive=lambda p,k:p.get('fresh') is True,continuous_nanoseconds=lambda:12)
        globals_=m['coordinate'].__globals__
        with patch.object(globals_['select'],'select',side_effect=select_fn), patch.object(globals_['os'],'read',side_effect=read_fn), patch.object(globals_['subprocess'],'Popen',side_effect=launch):
            result=m['coordinate'](observer,common,'operation')
        return log,result
    def test_order_and_duplicate_sleep(self):
        log,result=self.run_flow()
        self.assertIsNone(result[-1])
        self.assertEqual(log[:5],[('launch',None),('guardian',b'operation\n'),('observer',b'S'),('guardian','EOF'),('observer',b'R')])
        self.assertEqual(log.count(('guardian','EOF')),1)
    def test_exception_closes_both_owners(self):
        log,result=self.run_flow(True)
        self.assertEqual(result[-1],'RuntimeError')
        self.assertIn(('guardian','EOF'),log); self.assertIn(('observer','EOF'),log)
        self.assertNotIn(('observer',b'R'),log)
if __name__ == '__main__': unittest.main()
