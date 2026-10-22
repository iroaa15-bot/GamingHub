"""Run an explicitly packaged QA scene against the actual isolated Android app."""
import argparse
import json
from pathlib import Path
import subprocess
import time
from run_android_voice_runtime import PACKAGE


def main(adb, script, marker, output):
    output.mkdir(parents=True, exist_ok=True)

    def call(*args):
        result = subprocess.run([str(adb), *args], capture_output=True, text=True,
                                timeout=60, check=True)
        return result.stdout

    call('logcat', '-c')
    launch = call('shell', 'am', 'start', '-S', '-n', PACKAGE+'/com.godot.game.GodotApp',
                  '--esa', 'command_line_params',
                  '--max-fps,15,--script,res://diagnostics/'+script)
    (output/'launch.txt').write_text(launch)
    log = ''
    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        time.sleep(2)
        log = call('logcat', '-d', '-v', 'threadtime')
        (output/'logcat.txt').write_text(log)
        if marker in log or any(x in log for x in (
                'Fatal signal', 'FATAL EXCEPTION', 'SCRIPT ERROR:', 'RECOVERY_TIMEOUT')):
            break
    time.sleep(3)
    log = call('logcat', '-d', '-v', 'threadtime')
    (output/'logcat.txt').write_text(log)
    passed = marker in log and not any(x in log for x in (
        'Fatal signal', 'FATAL EXCEPTION', 'SCRIPT ERROR:'))
    result = {'passed': passed, 'marker': marker, 'actual_android_execution': True,
              'physical_device_tested': False}
    (output/'result.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result))
    if not passed:
        raise SystemExit(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--adb', type=Path, required=True)
    parser.add_argument('--script', required=True)
    parser.add_argument('--marker', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    main(args.adb.resolve(), args.script, args.marker, args.output.resolve())
