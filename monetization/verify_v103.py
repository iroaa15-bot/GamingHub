#!/usr/bin/env python3
"""Offline structural checks; not an Android SDK or device integration test."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
subprocess.run(['python3',str(root/'monetization/validate_admob_release.py')],check=True)
s = (root/'scripts/ad_manager.gd').read_text()
for token in ('integration_diagnostics()', '"production_ads_enabled": false', 'confirm_native_reward(request_id, reward_type, amount)', 'completed_request_ids[request_id] = true'):
 assert token in s, token
assert not (root/'addons').exists() or not list((root/'addons').rglob('*.aar')), 'Unexpected bundled Android binary: audit before release'
print('PASS: v10.3 offline structural diagnostics; no native SDK/device test performed')
