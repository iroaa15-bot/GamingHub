#!/usr/bin/env python3
"""Auditable release gates. Never equate unit-test success with store readiness.

Usage:
  python release/release_gate.py
  python release/release_gate.py --strict  # exits 1 until all required gates pass
"""
from pathlib import Path
import argparse, json, os, sys
from verify_android_package import check as verify_android_package
ROOT=Path(__file__).resolve().parents[1]
STATUS=ROOT/'release'/'manual_qa.json'

def is_file(path):return (ROOT/path).is_file()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--strict',action='store_true');args=parser.parse_args()
    project=(ROOT/'project.godot').read_text(encoding='utf-8')
    preset=(ROOT/'export_presets.cfg').read_text(encoding='utf-8') if is_file('export_presets.cfg') else ''
    ad=json.loads((ROOT/'monetization/ad_config.json').read_text(encoding='utf-8'))
    manual=json.loads(STATUS.read_text(encoding='utf-8')) if STATUS.exists() else {}
    checks={
        'godot_project_present':is_file('project.godot') and is_file('scenes/Main.tscn'),
        'online_wss_configured':json.loads((ROOT/'data/network_config.json').read_text())['server_url'].startswith('wss://'),
        'android_export_preset_present':'platform="Android"' in preset,
         'release_package_id_set':'package/unique_name="com.gaminghub.prototype"' not in preset,
        'android_target_sdk_36_requested': 'gradle_build/target_sdk="36"' in preset,
        'android_target_sdk_36_verified_in_build':manual.get('android_target_sdk_36_verified_in_build') is True,
        'admob_native_files_installed':(ROOT/'addons/admob/plugin.cfg').is_file() and bool(list((ROOT/'addons/admob/android/bin').rglob('*.aar'))) and bool(list((ROOT/'addons/admob/android/bin').rglob('poing_godot_admob_*.gd'))),
        'signed_release_aab_exists':any(not verify_android_package(p, release=True) for p in (ROOT/'build').glob('*.aab')),
        'godot_runtime_import_passed':manual.get('godot_runtime_import_passed') is True,
        'godot_scene_smoke_passed':manual.get('godot_scene_smoke_passed') is True,
        'android_real_device_passed':manual.get('android_real_device_passed') is True,
        'two_device_internet_match_passed':manual.get('two_device_internet_match_passed') is True,
        'fps_and_memory_checked':manual.get('fps_and_memory_checked') is True,
        'privacy_policy_published':manual.get('privacy_policy_published') is True,
        'store_listing_ready':manual.get('store_listing_ready') is True,
        'play_console_requirements_met':manual.get('play_console_requirements_met') is True,
        'admob_native_adapter_verified':manual.get('admob_native_adapter_verified') is True,
        'admob_test_ads_verified':manual.get('admob_test_ads_verified') is True,
        'families_and_data_safety_reviewed':manual.get('families_and_data_safety_reviewed') is True,
    }
    # This is an intentional hard blocker, not a bug: no ad SDK is integrated.
    if ad.get('mode') == 'disabled_until_native_adapter':
        checks['admob_native_adapter_verified']=False
    for key,passed in checks.items():print(('PASS' if passed else 'BLOCK')+' '+key)
    passed=sum(checks.values())
    print(f'RELEASE GATES: {passed}/{len(checks)} passed; NOT a quality score')
    if args.strict and passed<len(checks):return 1
    return 0

if __name__=='__main__':sys.exit(main())
