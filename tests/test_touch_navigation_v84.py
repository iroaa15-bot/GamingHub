"""Static v8.4 UI contracts; actual Godot/Android touch tests remain pending."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT/'scripts/main.gd').read_text(encoding='utf-8')
ONLINE = (ROOT/'scripts/multiplayer.gd').read_text(encoding='utf-8')

class TouchNavigationV84(unittest.TestCase):
 def test_android_back_handled_on_both_scenes(self):
  for source in [MAIN,ONLINE]:
   with self.subTest(scene='main' if source is MAIN else 'online'):
    self.assertIn('func _unhandled_key_input(event: InputEvent) -> void:',source)
    self.assertIn('event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK',source)
    self.assertIn('get_viewport().set_input_as_handled()',source)
 def test_main_active_round_exit_requires_confirmation(self):
  self.assertIn('if active_play_screen:\n    confirm_leave_active_game()',MAIN)
  self.assertIn('dialog.confirmed.connect(show_home)',MAIN)
  self.assertIn('"EXIT MATCH"), confirm_leave_active_game)',MAIN)
  self.assertIn('"HOME"), confirm_leave_active_game)',MAIN)
  self.assertIn('"Exit"), confirm_leave_active_game, ACCENT)',MAIN)
 def test_active_flag_tracks_only_gameplay(self):
  self.assertIn('func clear_ui() -> void:\n active_play_screen = false',MAIN)
  self.assertIn('active_play_screen = not picture_done',MAIN)
  self.assertIn('active_play_screen = not memory_done',MAIN)
  self.assertIn('active_play_screen = true',MAIN)
 def test_online_exit_sends_leave_and_closes_socket(self):
  self.assertIn('dialog.confirmed.connect(_exit_to_games)',ONLINE)
  self.assertIn('"type": "cancel_queue"',ONLINE)
  self.assertIn('"type": "leave"',ONLINE)
  section=ONLINE.split('func _exit_to_games() -> void:',1)[1].split('\nfunc ',1)[0]
  self.assertIn('socket.close()',section)
  self.assertIn('pending_action.clear()',section)
  self.assertIn('change_scene_to_file',section)
 def test_scroll_deadzone_and_focus_follow(self):
  for source in [MAIN,ONLINE]:
   self.assertIn('scroll.scroll_deadzone = 22',source)
   self.assertIn('scroll.follow_focus = true',source)
 def test_touch_tweens_are_cancelled(self):
  self.assertIn('func animate_touch_button(',MAIN)
  self.assertIn('previous.kill()',MAIN)
  self.assertIn('target.set_meta("touch_tween", animation)',MAIN)
 def test_reduced_motion_disables_tweens(self):
  self.assertIn('if reduced_motion:\n  target.scale = Vector2.ONE\n  return',MAIN)
 def test_home_shows_xp(self):
  home=MAIN.split('func show_home() -> void:',1)[1].split('\nfunc ',1)[0]
  self.assertIn('xp_progress()',home)

if __name__ == '__main__': unittest.main()
