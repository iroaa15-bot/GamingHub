"""Prepare Godot 4.5.1 Gradle sources and preserve scripted Back on target 36.

Android 16 otherwise bypasses the legacy Back dispatch used by this template.
This is an explicit temporary compatibility opt-out, not a native engine patch.
"""
import os
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

ANDROID='http://schemas.android.com/apk/res/android'

def patch_manifest(text):
    parsed=ET.fromstring(text)
    if parsed.find('application') is None:
        raise ValueError('Android template has no application element')
    def application(match):
        opening=match.group(0)
        attribute=r'android:enableOnBackInvokedCallback\s*=\s*([\"\']).*?\1'
        if re.search(attribute,opening):
            return re.sub(attribute,'android:enableOnBackInvokedCallback="false"',opening)
        return opening[:-1]+' android:enableOnBackInvokedCallback="false">'
    updated,count=re.subn(r'<application\b[^>]*>',application,text,count=1)
    if count!=1 or ET.fromstring(updated).find('application').get('{'+ANDROID+'}enableOnBackInvokedCallback')!='false':
        raise ValueError('Could not preserve scripted Android Back')
    return updated

def prepare(root, template=None):
    build=root/'android/build'
    manifest=build/'AndroidManifest.xml'
    # Generated Gradle resources are not Godot assets. Importing them before a
    # subsequent export creates .import files that break Android's resource merger.
    (root/'android').mkdir(exist_ok=True)
    (root/'android/.gdignore').touch()
    if not manifest.exists():
        if template is None:
            data=Path(os.environ['APPDATA'])/'Godot' if os.name=='nt' else Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))/'godot'
            template=data/'export_templates/4.5.1.stable/android_source.zip'
        with zipfile.ZipFile(template) as archive:
            for info in archive.infolist():
                destination=(build/info.filename).resolve()
                if not destination.is_relative_to(build.resolve()):
                    raise ValueError('Android template path escapes build directory')
            archive.extractall(build)
        if not manifest.exists():raise ValueError('Unexpected Godot Android template layout')
        (root/'android/.build_version').write_text('4.5.1.stable\n',encoding='utf-8')
    original=manifest.read_text(encoding='utf-8')
    manifest.write_text(patch_manifest(original),encoding='utf-8')
    # zipfile does not restore Unix executable bits from the official template.
    wrapper=build/'gradlew'
    if os.name!='nt' and wrapper.exists():
        wrapper.chmod(wrapper.stat().st_mode | 0o111)
    return manifest

if __name__=='__main__':
    print('ANDROID_SCRIPTED_BACK_READY',prepare(Path(__file__).resolve().parents[1]))
