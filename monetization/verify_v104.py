from pathlib import Path
import json, re
root=Path(__file__).resolve().parents[1]
c=json.loads((root/'monetization/ad_config.json').read_text())
a=(root/'scripts/ad_manager.gd').read_text()
assert c['mode']=='disabled_prelaunch_no_sdk'
assert c['integration_version']=='10.4'
assert not any(c[f'{x}_enabled'] for x in ('rewarded','interstitial','banner','child_profiles_ads','family_profiles_ads'))
assert c['reward_amount']==50 and c['reward_currency']=='Coins'
assert c['android_test_app_id'].startswith('ca-app-pub-3940256099942544~')
for x in ('rewarded','interstitial','banner'):
 assert c[f'android_test_{x}_unit_id'].startswith('ca-app-pub-3940256099942544/')
 assert re.fullmatch(r'ca-app-pub-\d{16}/\d+',c[f'production_{x}_unit_id'])
assert 'func get_android_test_ids()' in a
assert 'func confirm_native_reward(' in a
assert 'completed_request_ids.has(request_id)' in a
assert 'func request_interstitial_ad()' in a and 'Interstitials remain disabled' in a
print('PASS: offline configuration, test IDs, disabled ads and reward guards')
