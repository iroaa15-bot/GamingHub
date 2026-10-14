#!/usr/bin/env python3
"""Portable source/asset integrity preflight; not a substitute for Godot runtime tests."""
from pathlib import Path
import json, re, sys
ROOT = Path(__file__).resolve().parents[1]
errors=[]
def check(condition,message):
    if not condition: errors.append(message)
project=ROOT/'project.godot'
check(project.is_file(),'Missing project.godot')
main=ROOT/'scenes/Main.tscn'
check(main.is_file(),'Missing Main.tscn')
if main.exists():
    for path in re.findall(r'path="(res://[^"]+)"',main.read_text()):
        check((ROOT/path[6:]).exists(),f'Missing scene dependency: {path}')
if project.exists():
    text=project.read_text()
    for path in re.findall(r'path="(res://[^"]+)"',text):
        check((ROOT/path[6:]).exists(),f'Missing autoload script: {path}')
    check('run/main_scene="res://scenes/Main.tscn"' in text,'Unexpected main scene')
for file in (ROOT/'data').glob('*.json'):
    try:json.loads(file.read_text(encoding='utf-8'))
    except Exception as e:errors.append(f'Invalid JSON {file.name}: {e}')
for script in (ROOT/'scripts').glob('*.gd'):
    check(script.stat().st_size>0,f'Empty GDScript {script.name}')
print(f'Preflight: {len(list((ROOT/"scripts").glob("*.gd")))} scripts, {len(list((ROOT/"data").glob("*.json")))} JSON files')
if errors:
    print('\n'.join('FAIL: '+x for x in errors));sys.exit(1)
print('PASS: static source checks (Godot runtime still untested)')
