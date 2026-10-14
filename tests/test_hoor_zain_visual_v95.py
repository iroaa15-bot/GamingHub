"""Offline regression contracts for the approved game identity and tactile screens."""
import struct
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

class HoorZainVisualV95(unittest.TestCase):
    def test_approved_icon_is_large_square_png(self):
        icon=ROOT/'assets/ui/gaming_hub_icon.png'
        raw=icon.read_bytes()
        self.assertEqual(raw[:8],b'\x89PNG\r\n\x1a\n')
        self.assertEqual(struct.unpack('>II',raw[16:24]),(1024,1024))
        self.assertGreater(len(raw),300_000)

    def test_brand_is_optimized_square_png(self):
        brand=(ROOT/'assets/ui/gaming_hub_brand.png').read_bytes()
        self.assertEqual(brand[:8],b'\x89PNG\r\n\x1a\n')
        self.assertEqual(struct.unpack('>II',brand[16:24]),(512,512))

    def test_home_and_online_lobby_show_approved_art(self):
        main=(ROOT/'scripts/main.gd').read_text()
        online=(ROOT/'scripts/multiplayer.gd').read_text()
        self.assertIn('VisualSkin.add_brand_banner(',main)
        self.assertIn('res://assets/ui/gaming_hub_brand.png',main)
        self.assertIn('res://assets/ui/gaming_hub_brand.png',online)
        self.assertIn('res://assets/ui/gaming_hub_icon.png',(ROOT/'project.godot').read_text())

    def test_question_and_answer_tactile_panels(self):
        skin=(ROOT/'scripts/visual_skin.gd').read_text()
        main=(ROOT/'scripts/main.gd').read_text()
        for feature in ('add_question_panel','add_feedback_panel','decorate_progress'):
            self.assertIn('static func '+feature,skin)
            self.assertIn('VisualSkin.'+feature+'(',main)

    def test_confetti_is_lightweight_and_respects_accessibility(self):
        fx=(ROOT/'scripts/celebration_fx.gd').read_text()
        main=(ROOT/'scripts/main.gd').read_text()
        self.assertIn('mouse_filter = Control.MOUSE_FILTER_IGNORE',fx)
        self.assertIn('queue_free()',fx)
        self.assertIn('if reduced_motion:',main.split('func show_celebration(',1)[1].split('\nfunc ',1)[0])
        self.assertIn('show_celebration(true)',main)
        self.assertIn('show_celebration(false)',main)

    def test_export_names_match_release(self):
        workflow=(ROOT/'.github/workflows/godot-checks.yml').read_text()
        self.assertIn('GamingHub-v11.5-debug.apk',workflow)
        self.assertIn('config/name="Gaming Hub"',(ROOT/'project.godot').read_text())

if __name__=='__main__':unittest.main()
