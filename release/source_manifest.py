#!/usr/bin/env python3
"""Deterministic manifest for the Godot project source; detects partial/stale uploads.

Does not include build artifacts, credentials or this manifest itself.
"""
import argparse, hashlib, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIRS = ('docs', 'addons', '.github/workflows', 'assets', 'scenes', 'scripts', 'data', 'tests',
        'server', 'ai_daily', 'liveops', 'monetization', 'release', 'native', 'tools')
TOP = ('project.godot', 'export_presets.cfg', 'render.yaml', '.gitignore',
       'README_START_HERE_AR.md', 'RELEASE_v11.5_AR.md', 'RELEASE_v11.4_AR.md', 'RELEASE_v11.3_AR.md', 'RELEASE_v11.2_AR.md', 'RELEASE_v11.1_AR.md', 'RELEASE_v10.7_AR.md', 'RELEASE_v10.6_AR.md', 'RELEASE_v10.5_AR.md', 'RELEASE_v10.4_AR.md', 'RELEASE_v10.3_AR.md', 'RELEASE_v10.2_AR.md', 'RELEASE_v10.1_AR.md', 'RELEASE_v10.0_AR.md', 'RELEASE_v9.9_AR.md', 'RELEASE_v9.8_AR.md', 'RELEASE_v9.2_AR.md', 'RELEASE_v9.3_AR.md', 'RELEASE_v9.4_AR.md', 'RELEASE_v9.5_AR.md', 'RELEASE_v9.6_AR.md', 'RELEASE_v9.7_AR.md')
EXCLUDE = {'release/source_manifest.json'}

TEXT_SUFFIXES = {'.gd', '.uid', '.godot', '.cfg', '.json', '.yml', '.yaml', '.md',
                 '.txt', '.py', '.ps1', '.sh', '.html', '.svg', '.b85', '.tres',
                 '.tscn', '.csv', '.xml', '.gradle', '.kt', '.kts', '.pro', '.properties', '.bat'}

def source_bytes(path):
    data = path.read_bytes()
    if path.suffix in TEXT_SUFFIXES or path.name in {'.gitignore', '.gitkeep', 'Dockerfile', 'gradlew'}:
        return data.replace(b'\r\n', b'\n')
    return data

def included(root=ROOT):
    files = [root / name for name in TOP if (root/name).is_file()]
    for directory in DIRS:
        if (root/directory).is_dir():
            files.extend(p for p in (root/directory).rglob('*') if p.is_file())
    def enabled_binary(path):
        name = path.relative_to(root).as_posix()
        if name.startswith('addons/admob/ios/bin/'):
            return False
        if name.startswith('addons/admob/android/bin/'):
            return name.startswith('addons/admob/android/bin/ads/') or name in {
                'addons/admob/android/bin/package.gd', 'addons/admob/android/bin/package.gd.uid'}
        return True
    return sorted((p for p in files if enabled_binary(p) and p.relative_to(root).as_posix() not in EXCLUDE
                   and '__pycache__' not in p.parts and p.suffix not in {'.pyc', '.import'}
                   and '.godot' not in p.parts and 'build' not in p.parts
                   and '.gradle' not in p.parts and '.kotlin' not in p.parts and p.name != 'local.properties'),
                  key=lambda p: p.relative_to(root).as_posix())

def inventory(root=ROOT):
    return {p.relative_to(root).as_posix(): hashlib.sha256(source_bytes(p)).hexdigest()
            for p in included(root)}

def verify(root=ROOT):
    target = root/'release/source_manifest.json'
    if not target.is_file():
        return ['Missing release/source_manifest.json']
    try:
        saved = json.loads(target.read_text(encoding='utf-8'))
        expected = saved['sha256']
        if not isinstance(expected, dict):
            return ['Invalid manifest structure']
    except (OSError, ValueError, KeyError, TypeError) as exc:
        return [f'Invalid manifest: {exc}']
    actual = inventory(root)
    errors = []
    for name in sorted(expected.keys() - actual.keys()):
        errors.append('Missing source file: '+name)
    for name in sorted(actual.keys() - expected.keys()):
        errors.append('Untracked source file: '+name)
    for name in sorted(actual.keys() & expected.keys()):
        if actual[name] != expected[name]:
            errors.append('Modified source file: '+name)
    if saved.get('file_count') != len(expected):
        errors.append('Incorrect manifest file_count')
    return errors

def write(root=ROOT):
    data = inventory(root)
    output = root/'release/source_manifest.json'
    output.write_text(json.dumps({'schema':1,'file_count':len(data),'sha256':data},
                                 indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    return len(data)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--write',action='store_true',help='Rebuild hashes after reviewed source changes')
    parser.add_argument('--root',type=Path,default=ROOT)
    args = parser.parse_args()
    if args.write:
        print('MANIFEST_UPDATED',write(args.root))
    else:
        issues=verify(args.root)
        if issues:
            print('MANIFEST_FAIL:',*issues,sep='\n - ')
            raise SystemExit(1)
        print('MANIFEST_PASS',len(inventory(args.root)))
