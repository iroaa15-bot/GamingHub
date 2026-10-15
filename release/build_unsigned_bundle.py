"""Build a CI bundle without transmitting or requiring any upload signing key."""
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
preset = root / 'export_presets.cfg'
original = preset.read_text(encoding='utf-8')
prefix, release = original.split('[preset.1.options]', 1)
try:
    preset.write_text(prefix + '[preset.1.options]' + release.replace('package/signed=true', 'package/signed=false'), encoding='utf-8')
    result = subprocess.run(['godot', '--headless', '--path', str(root), '--export-release', 'Android Release', 'build/GamingHub-v11.7-unsigned.aab'])
    raise SystemExit(result.returncode)
finally:
    preset.write_text(original, encoding='utf-8')
