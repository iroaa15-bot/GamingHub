#!/usr/bin/env python3
"""Prepare an isolated v11.8 voice APK export without changing release files."""
from pathlib import Path
import sys

project = Path("project.godot")
presets = Path("export_presets.cfg")
if not project.is_file() or not presets.is_file():
    raise SystemExit("Run from the GamingHub repository root")
p = project.read_text()
old = 'enabled=PackedStringArray("res://addons/admob/plugin.cfg")'
new = 'enabled=PackedStringArray("res://addons/admob/plugin.cfg", "res://addons/gaminghub_voice/plugin.cfg")'
if old not in p:
    raise SystemExit("Unexpected project plugin configuration")
project.write_text(p.replace(old, new))
s = presets.read_text()
head, sep, tail = s.partition("[preset.1]")
if not sep:
    raise SystemExit("Missing release preset; refusing to edit")
for old, new in [
    ('version/code=117', 'version/code=118'),
    ('version/name="11.7"', 'version/name="11.8-voice-test"'),
    ('package/unique_name="com.iroaa15.gaminghub"', 'package/unique_name="com.iroaa15.gaminghub.voicetest"'),
]:
    if old not in head:
        raise SystemExit(f"Expected debug preset setting absent: {old}")
    head = head.replace(old, new)
presets.write_text(head + sep + tail)
print("VOICE_DEBUG_EXPORT_PREPARED")
print("Release preset remains unchanged; restore files after the isolated export.")
