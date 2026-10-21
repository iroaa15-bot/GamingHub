"""Actual Android debug-APK regression; requires an attached emulator/device.

Only operates on com.iroaa15.gaminghub.colyseustest.voicefix118. No production package,
cloud deployment, or simulated JNI. Permission buttons come from UIAutomator.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

PACKAGE = 'com.iroaa15.gaminghub.colyseustest.voicefix118'

def main(adb, apk, output):
    output.mkdir(parents=True, exist_ok=True)
    commands = []
    def call(*args, timeout=120, check=True):
        result = subprocess.run([str(adb), *args], capture_output=True, timeout=timeout)
        commands.append({'args': list(args), 'returncode': result.returncode,
                         'stdout': result.stdout.decode(errors='replace'),
                         'stderr': result.stderr.decode(errors='replace')})
        (output/'adb-commands.json').write_text(json.dumps(commands, indent=2))
        if check and result.returncode:
            raise RuntimeError('adb failed: ' + ' '.join(args))
        return result.stdout.decode(errors='replace')
    call('install', '-r', '--no-streaming', str(apk), timeout=480)
    call('shell', 'pm', 'revoke', PACKAGE, 'android.permission.RECORD_AUDIO', check=False)
    results = []
    for choice in ('deny', 'allow'):
        call('logcat', '-c')
        call('shell', 'am', 'start', '-S', '-n', PACKAGE+'/com.godot.game.GodotApp',
             '--esa', 'command_line_params',
             '--max-fps,15,--script,res://diagnostics/android_voice_runtime.gd,--,--request-microphone')
        tapped = False
        text = ''
        limit = time.monotonic() + 300
        while time.monotonic() < limit:
            time.sleep(2)
            text = call('logcat', '-d', '-v', 'threadtime')
            (output/(choice+'-logcat.txt')).write_text(text)
            if any(marker in text for marker in ('Fatal signal', 'FATAL EXCEPTION', 'ANDROID_VOICE_RUNTIME_FAIL', 'ANDROID_VOICE_TIMEOUT')):
                break
            if 'ANDROID_VOICE_RUNTIME_PASS' in text:
                break
            # Do not tap unobserved screen coordinates or an application control.
            if not tapped and 'ANDROID_AFTER_VOICE_BUTTON' in text:
                call('shell', 'uiautomator', 'dump', '/sdcard/gh-permission.xml', timeout=45, check=False)
                xml = call('shell', 'cat', '/sdcard/gh-permission.xml', check=False)
                (output/(choice+'-permission-ui.xml')).write_text(xml)
                try:
                    nodes = ET.fromstring(xml).iter('node')
                    wanted = ('permission_deny_button',) if choice == 'deny' else ('permission_allow_button', 'permission_allow_foreground_only_button')
                    for node in nodes:
                        if any(node.get('resource-id', '').endswith('/'+name) for name in wanted):
                            bounds = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
                            if len(bounds) == 4:
                                call('shell', 'input', 'tap', str((bounds[0]+bounds[2])//2), str((bounds[1]+bounds[3])//2))
                                tapped = True
                                break
                except ET.ParseError:
                    pass
        # Include Activity/plugin shutdown after the script's success marker.
        time.sleep(3)
        text = call('logcat', '-d', '-v', 'threadtime')
        (output/(choice+'-logcat.txt')).write_text(text)
        expected = 'ANDROID_PERMISSION_CALLBACK=' + ('false' if choice == 'deny' else 'true')
        passed = ('ANDROID_VOICE_RUNTIME_PASS' in text and expected in text and tapped
                  and 'Fatal signal' not in text and 'FATAL EXCEPTION' not in text and 'SCRIPT ERROR:' not in text)
        if choice == 'allow': passed = passed and 'ANDROID_NATIVE_RESTART_COMPLETED' in text
        results.append({'scenario': choice, 'passed': passed, 'actual_android_jni': True})
        (output/'result.json').write_text(json.dumps({'results': results, 'physical_device_tested': False}, indent=2))
        if not passed:
            call('logcat', '-d', '-b', 'crash', check=False)
            raise RuntimeError('Android regression failed: '+choice)
    print(json.dumps({'result': 'ANDROID_VOICE_BUTTONS_PERMISSION_RESTART_PASS', 'results': results}))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--adb', type=Path, required=True)
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    main(args.adb.resolve(), args.apk.resolve(), args.output.resolve())
