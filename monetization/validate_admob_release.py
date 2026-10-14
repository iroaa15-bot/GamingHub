#!/usr/bin/env python3
"""Fail-closed static checks for Gaming Hub AdMob configuration."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
cfg = json.loads((ROOT/'monetization/ad_config.json').read_text(encoding='utf-8'))
assert cfg['mode'] in ('disabled_prelaunch_no_sdk', 'android_test_sdk'), 'Unsafe advertising mode'
if cfg['mode'] == 'android_test_sdk':
    addon = ROOT/'addons/admob'
    assert (addon/'plugin.cfg').is_file(), 'Native AdMob plugin missing'
    assert (ROOT/'scripts/poing_admob_bridge.gd').is_file(), 'Verified native bridge missing'
    assert list((addon/'android/bin').rglob('*.aar')), 'Android AAR files missing'
    assert list((addon/'android/bin').rglob('poing_godot_admob_*.gd')), 'Poing export scripts missing'
for key in ('rewarded_enabled','interstitial_enabled','banner_enabled','child_profiles_ads_enabled','family_profiles_ads_enabled'):
    if key == 'rewarded_enabled' and cfg['mode'] == 'android_test_sdk':
        assert cfg[key] is True, 'Test SDK mode requires rewarded_enabled'
    else:
        assert cfg[key] is False, f'Unsafe setting: {key}'
for key in ('consent_required_before_ads','requires_ump_consent','requires_verified_native_sdk','reward_only_on_native_earned_callback'):
    assert cfg[key] is True, f'Missing gate: {key}'
assert cfg['reward_amount'] == 50 and cfg['reward_currency'] == 'Coins'
assert cfg['production_app_id'].startswith('ca-app-pub-') and '~' in cfg['production_app_id']
for fmt in ('rewarded','interstitial','banner'):
    assert cfg[f'production_{fmt}_unit_id'].startswith('ca-app-pub-')
    assert cfg[f'android_test_{fmt}_unit_id'].startswith('ca-app-pub-3940256099942544/')
source = (ROOT/'scripts/ad_manager.gd').read_text(encoding='utf-8')
for guard in ('consent_resolved','native_adapter_ready','pending_request_id','completed_request_ids','reward_type !=','amount !='):
    assert guard in source, f'Missing code guard: {guard}'
print('PASS: AdMob release gates fail closed; all three test/production IDs present.')
