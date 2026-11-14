import contextlib,sqlite3,subprocess,sys,tempfile,unittest
from pathlib import Path
from service import Store
class FirstAdmin(unittest.TestCase):
 def test_explicit_local_first_admin_only(self):
  with tempfile.TemporaryDirectory() as td:
   db=str(Path(td)/'first-admin.sqlite');store=Store(db)
   with store.db() as c:c.execute("INSERT INTO users(id,name,email) VALUES('owner','Test owner','test@example.test')")
   command=[sys.executable,str(Path(__file__).with_name('service.py')),'--db',db,'--grant-first-super-admin','owner']
   refused=subprocess.run(command,capture_output=True);self.assertNotEqual(refused.returncode,0)
   granted=subprocess.run(command+['--confirm-first-admin'],capture_output=True);self.assertEqual(granted.returncode,0)
   again=subprocess.run(command+['--confirm-first-admin'],capture_output=True);self.assertNotEqual(again.returncode,0)
   with store.db() as c:
    self.assertEqual(c.execute("SELECT role FROM users WHERE id='owner'").fetchone()[0],'super_admin')
    self.assertEqual(c.execute("SELECT count(*) FROM audit WHERE action='grant-first-super-admin'").fetchone()[0],1)
   print('PASS: explicit local first-admin grant, repeat blocked, audited; disposable test DB only')
if __name__=='__main__':unittest.main()
