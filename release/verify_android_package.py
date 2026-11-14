#!/usr/bin/env python3
"""Validate APK/AAB output signatures and structural completeness (not Google Play approval)."""
import argparse, pathlib, zipfile, sys

UNNEEDED_PERMISSIONS = ('android.permission.READ_CONTACTS','android.permission.WRITE_CONTACTS',
    'android.permission.READ_PHONE_STATE','android.permission.READ_BASIC_PHONE_STATE',
    'android.permission.READ_EXTERNAL_STORAGE','android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.AD_ID','com.google.android.gms.permission.AD_ID',
    'android.permission.USE_BIOMETRIC','android.permission.USE_FINGERPRINT',
    'android.permission.ACCESS_ADSERVICES_ATTRIBUTION','android.permission.ACCESS_ADSERVICES_AD_ID',
    'android.permission.ACCESS_ADSERVICES_CUSTOM_AUDIENCE','android.permission.ACCESS_ADSERVICES_TOPICS',
    'com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE',
    'android.permission.FOREGROUND_SERVICE','android.permission.WAKE_LOCK')

def check(path: pathlib.Path, release: bool=False):
    errors=[]
    if not path.is_file(): return [f'Missing: {path}']
    if path.stat().st_size < 200_000: errors.append('Suspiciously small Android package')
    if not zipfile.is_zipfile(path): return errors+['Not a ZIP-format Android package']
    with zipfile.ZipFile(path) as z:
        bad=z.testzip()
        if bad: errors.append(f'Corrupted entry: {bad}')
        names=set(z.namelist())
        manifest_name='base/manifest/AndroidManifest.xml' if path.suffix=='.aab' else 'AndroidManifest.xml'
        if manifest_name in names:
            manifest=z.read(manifest_name)
            for permission in UNNEEDED_PERMISSIONS:
                if permission.encode() in manifest or permission.encode('utf-16-le') in manifest:
                    errors.append('Unnecessary Android permission: '+permission)
        if path.suffix=='.apk':
            if 'AndroidManifest.xml' not in names: errors.append('Missing AndroidManifest.xml')
            if 'resources.arsc' not in names: errors.append('Missing compiled Android resources')
            if 'classes.dex' not in names and not any(x.startswith('lib/') and x.endswith('.so') for x in names): errors.append('No executable Android content')
        elif path.suffix=='.aab':
            for entry in ('BundleConfig.pb','base/manifest/AndroidManifest.xml'):
                if entry not in names: errors.append(f'Missing {entry}')
            if release and not any(x.startswith('META-INF/') and x.endswith('.SF') for x in names):
                errors.append('AAB has no JAR signing metadata (.SF)')
        else: errors.append('Expected .apk or .aab')
    return errors

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('file',type=pathlib.Path);p.add_argument('--release',action='store_true');a=p.parse_args()
    errors=check(a.file,a.release)
    for e in errors: print('FAIL',e)
    if not errors: print('PASS',a.file,a.file.stat().st_size,'bytes')
    sys.exit(bool(errors))
