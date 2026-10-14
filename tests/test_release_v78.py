"""Static contracts for multiplayer cold-start; NOT Godot runtime verification."""
import unittest
from pathlib import Path
SOURCE=(Path(__file__).resolve().parents[1]/'scripts/multiplayer.gd').read_text(encoding='utf-8')
class MultiplayerColdStart(unittest.TestCase):
 def test_create_join_survive_initial_connect(self):
  section=SOURCE.split('func _connect_server() -> void:',1)[1].split('func _process(',1)[0]
  self.assertLess(section.index('var queued_action: Dictionary = pending_action.duplicate()'),section.index('\n _reset_match_state()'))
  self.assertLess(section.index('\n _reset_match_state()'),section.index('pending_action = queued_action'))
  self.assertIn('_update_lobby()',section)
 def test_cancel_during_connect_cannot_autocreate_room(self):
  section=SOURCE.split('func _leave_match() -> void:',1)[1].split('func _request_action(',1)[0]
  self.assertIn('WebSocketPeer.STATE_CONNECTING',section)
  self.assertIn('socket.close()',section)
  self.assertIn('pending_action.clear()',section)
 def test_no_overwrite_pending_join_during_connect(self):
  section=SOURCE.split('func _request_action(',1)[1].split('func _connect_server(',1)[0]
  self.assertIn('if not pending_action.is_empty():',section)
 def test_pending_actions_cleared_on_lobby_response(self):
  section=SOURCE.split('func _handle(',1)[1].split('func _match_note(',1)[0]
  for kind in ('"queue":','"room":','"started":'):
   self.assertIn('pending_action.clear()',section.split(kind,1)[1].split('\n  "',1)[0])
 def test_no_instance_variable_defaults_in_gdscript(self):
  root=Path(__file__).resolve().parents[1]
  main=(root/'scripts/main.gd').read_text()
  multi=(root/'scripts/multiplayer.gd').read_text()
  for old in ['key: String = audience','key: String = deck']:
   self.assertNotIn(old,main)
  self.assertNotIn('parent: VBoxContainer = output',multi)
 def test_android_internet_and_wss(self):
  root=Path(__file__).resolve().parents[1]
  self.assertIn('permissions/internet=true',(root/'export_presets.cfg').read_text())
  self.assertIn('wss://gaminghub-multiplayer.onrender.com',(root/'data/network_config.json').read_text())
if __name__=='__main__':unittest.main()
