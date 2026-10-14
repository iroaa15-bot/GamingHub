from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def test_privacy_entry():
 s=(ROOT/'scripts/main.gd').read_text()
 assert 'show_privacy_and_ads' in s and 'PRIVACY & ADS' in s
 assert 'AD INTEGRATION STATUS' in s
def test_ad_safety():
 obj=json.loads((ROOT/'monetization/ad_config.json').read_text())
 assert obj['mode']=='disabled_prelaunch_no_sdk'
 assert obj['child_profiles_ads_enabled'] is False
 assert obj['personalized_ads_default'] is False
 assert not obj['production_app_id']
