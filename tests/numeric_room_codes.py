import sys,unittest
from unittest.mock import patch
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from room_codes_local import new_room_code
class Codes(unittest.TestCase):
 def test_numeric_collision_and_bounded_exhaustion(self):
  with patch('room_codes_local.secrets.randbelow',side_effect=[0,0,899999]):
   self.assertEqual(new_room_code({}), '100000')
   self.assertEqual(new_room_code({'100000':object()}),'999999')
  with patch('room_codes_local.secrets.randbelow',return_value=1):
   with self.assertRaises(RuntimeError):new_room_code({'100001':object()})
  codes=set()
  for _ in range(5000):
   value=new_room_code(codes);self.assertRegex(value,r'^[1-9][0-9]{5}$');self.assertNotIn(value,codes);codes.add(value)
unittest.main()
