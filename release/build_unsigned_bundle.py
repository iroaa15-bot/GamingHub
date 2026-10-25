"""Build a CI bundle without transmitting or requiring any upload signing key."""
import pathlib
import argparse
import subprocess

parser=argparse.ArgumentParser()
parser.add_argument('--godot',default='godot')
parser.add_argument('--output',default='build/GamingHub-v11.7-unsigned.aab')
args=parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]
preset = root / 'export_presets.cfg'
original = preset.read_text(encoding='utf-8')
prefix, release = original.split('[preset.1.options]', 1)
try:
    preset.write_text(prefix + '[preset.1.options]' + release.replace('package/signed=true', 'package/signed=false'), encoding='utf-8')
    result = subprocess.run([args.godot, '--headless', '--path', str(root), '--export-release', 'Android Release', args.output])
    raise SystemExit(result.returncode)
finally:
    preset.write_text(original, encoding='utf-8')
