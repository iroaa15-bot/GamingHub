"""Static release gates only; not Godot or Android runtime evidence."""
import json, pathlib, unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]

class TestReleaseSafetyV115(unittest.TestCase):
    def test_android_target_sdk_and_gradle_requested(self):
        txt = (ROOT/'export_presets.cfg').read_text()
        self.assertEqual(txt.count('gradle_build/target_sdk="36"'), 2)
        self.assertEqual(txt.count('gradle_build/use_gradle_build=true'), 2)
        self.assertIn('gradle_build/export_format=1', txt)

    def test_children_no_ads_and_test_only_rewards(self):
        main = (ROOT/'scripts/main.gd').read_text()
        ad = (ROOT/'scripts/ad_manager.gd').read_text()
        conf = json.loads((ROOT/'monetization/ad_config.json').read_text())
        self.assertIn('show_age_group_selection()', main)
        self.assertIn('age_group == "18plus"', main)
        self.assertIn('AdManager.set_audience("adults" if age_group == "18plus" else "children")', main)
        self.assertIn('current_audience == "adults"', ad)
        self.assertIn('request_id != pending_request_id', ad)
        self.assertEqual(conf['mode'], 'android_test_sdk')
        self.assertEqual(conf['reward_amount'], 50)
        self.assertFalse(conf['child_profiles_ads_enabled'])

    def test_plugin_installer_and_debug_only(self):
        powershell = (ROOT/'release/install_admob_windows.ps1').read_text()
        bridge = (ROOT/'monetization/poing_admob_bridge.gd.template').read_text()
        self.assertIn('Get-FileHash -Algorithm SHA256', powershell)
        self.assertIn('poing_godot_admob_*.gd', powershell)
        self.assertIn('Get-ChildItem -Path $bin -Filter', powershell)
        self.assertIn('OnUserEarnedRewardListener', bridge)
        self.assertIn('UserMessagingPlatform.consent_information.update', bridge)
        self.assertIn('OS.has_feature("debug")', bridge)
        self.assertIn('earned_reward.emit(accepted_request, "Coins", 50)', bridge)
        self.assertNotIn('OnUserEarnedRewardListener', (ROOT/'scripts/main.gd').read_text())
        self.assertTrue((ROOT/'addons/admob/plugin.cfg').exists())

    def test_ci_hard_gates(self):
        ci = (ROOT/'.github/workflows/godot-checks.yml').read_text()
        for token in ('platforms;android-36', 'build-tools;36.0.0','targetSdkVersion', 'godot --headless --path . --install-android-build-template --export-debug'):
            self.assertIn(token, ci)

if __name__ == '__main__': unittest.main()
