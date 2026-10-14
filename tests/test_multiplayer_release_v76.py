"""Static regression gates for the portrait multiplayer release candidate.

These are source contracts; they don't substitute for the Godot runtime or Android QA.
"""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'scripts' / 'multiplayer.gd').read_text(encoding='utf-8')

class MultiplayerReleaseV76(unittest.TestCase):
    def test_production_wss_configured(self):
        cfg = json.loads((ROOT / 'data' / 'network_config.json').read_text(encoding='utf-8'))
        self.assertEqual(cfg['server_url'], 'wss://gaminghub-multiplayer.onrender.com')

    def test_active_match_above_lobby(self):
        self.assertLess(SOURCE.index('output.add_child(match_view)'), SOURCE.index('output.add_child(lobby_controls)'))
        self.assertIn('scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED', SOURCE)

    def test_no_self_card_visible(self):
        self.assertIn('msg.get("opponent_card", {})', SOURCE)
        self.assertIn('بطاقتك: ؟؟؟', SOURCE)
        self.assertNotIn('msg.get("your_card"', SOURCE)

    def test_cold_start_timeout_and_retry(self):
        self.assertIn('CONNECT_TIMEOUT_MS: int = 60000', SOURCE)
        self.assertIn('Time.get_ticks_msec() - connect_started_ms > CONNECT_TIMEOUT_MS', SOURCE)
        self.assertIn('try again', SOURCE.lower())

    def test_lobby_disabled_while_queued(self):
        self.assertIn('or matchmaking_pending or not pending_action.is_empty()', SOURCE)
        self.assertIn('matchmaking_pending = str(msg.get("status", "")) == "waiting"', SOURCE)

    def test_questions_are_paginated(self):
        self.assertIn('QUESTIONS_PER_PAGE: int = 6', SOURCE)
        self.assertIn('question_page * QUESTIONS_PER_PAGE', SOURCE)
        self.assertIn('_prev_questions', SOURCE)
        self.assertIn('_next_questions', SOURCE)

    def test_result_displays_winner(self):
        self.assertIn('winner == player_index', SOURCE)
        self.assertIn('winner == -1', SOURCE)

if __name__ == '__main__': unittest.main()
