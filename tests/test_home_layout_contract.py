#!/usr/bin/env python3
"""Non-invasive static checks for the optional home layout.

These tests deliberately do not claim Godot runtime or real-device coverage.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
CATALOG = (ROOT / "scripts/home_layout_catalog.gd").read_text(encoding="utf-8")
NETWORK = (ROOT / "data/network_config.json").read_text(encoding="utf-8")
DAILY = (ROOT / "scripts/daily_rounds.gd").read_text(encoding="utf-8")
IMAGES = (ROOT / "scripts/daily_ai.gd").read_text(encoding="utf-8")
LIVEOPS = (ROOT / "scripts/live_ops.gd").read_text(encoding="utf-8")

class SafeHomeTests(unittest.TestCase):
    def test_original_home_still_present(self):
        self.assertIn("func show_home_legacy() -> void:", MAIN)
        self.assertIn("func show_home_v2() -> void:", MAIN)
        self.assertRegex(MAIN, r"func show_home\(\) -> void:\n if HomeLayoutCatalog.enabled\(\):\n  show_home_v2\(\)\n  return\n show_home_legacy\(\)")

    def test_new_home_routes_existing_features(self):
        block = MAIN.split("func show_home_v2() -> void:", 1)[1].split("func show_games_list_v2() -> void:", 1)[0]
        for route in ("open_guess_multiplayer", "start_guess_offline", "show_games_list_v2", "show_languages", "show_accessibility", "show_privacy_and_ads"):
            self.assertIn(route, block)

    def test_games_list_uses_existing_tiles(self):
        block = MAIN.split("func show_games_list_v2() -> void:", 1)[1].split("func show_home_legacy() -> void:", 1)[0]
        self.assertIn("range(GAMES.size())", block)
        self.assertIn("make_game_tile", block)
        for route in ("start_surprise_arcade", "start_championship", "show_ai_daily", "start_daily"):
            self.assertIn(route, block)

    def test_feature_off_by_default(self):
        self.assertIn('if not FileAccess.file_exists(FLAG_PATH):\n  return false', CATALOG)
        self.assertIn('"available": false', CATALOG)

    def test_existing_services_still_configured(self):
        self.assertIn("wss://gaminghub-multiplayer.onrender.com", NETWORK)
        self.assertIn("gaminghub-multiplayer.onrender.com/content/history.json", DAILY)
        self.assertIn("gaminghub-multiplayer.onrender.com/ai_daily", IMAGES)
        self.assertIn("gaminghub-multiplayer.onrender.com/liveops/rotation.json", LIVEOPS)

    def test_party_game_catalog_complete(self):
        for name in ("pass_the_bomb", "whos_most_likely", "odd_one_out", "truth_or_dare", "draw_disaster", "crazy_emoji", "fake_it", "secret_mission"):
            self.assertIn(name, CATALOG)

if __name__ == "__main__":
    unittest.main()
