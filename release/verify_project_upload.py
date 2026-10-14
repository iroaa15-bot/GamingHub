#!/usr/bin/env python3
"""Fail fast if GitHub contains only the backend or a partial Godot upload."""
from pathlib import Path
import argparse, sys

def verify(root: Path) -> list[str]:
    errors=[]
    required = ['project.godot','export_presets.cfg','scenes/Main.tscn',
                'scenes/Multiplayer.tscn','scripts/main.gd','scripts/multiplayer.gd',
                'data/cards.json','assets/ui/gaming_hub_icon.png',
                'tests/godot_smoke.gd']
    for name in required:
        p=root/name
        if not p.is_file() or p.stat().st_size == 0:
            errors.append('Missing or empty: '+name)
    # Some cards are inlined in GDScript, but image and sound files must be present.
    for directory,extension,minimum in [('assets/generated','.webp',8),
                                        ('assets/audio','.wav',3),
                                        ('assets/campaign','.webp',3)]:
        count=len(list((root/directory).glob('*'+extension)))
        if count<minimum:
            errors.append(f'Asset upload incomplete: {directory} ({count}/{minimum} minimum)')
    # Verify exact source parity, not just representative files.
    try:
        from source_manifest import verify as verify_manifest
    except ImportError:
        import sys
        sys.path.insert(0,str(Path(__file__).resolve().parent))
        from source_manifest import verify as verify_manifest
    errors.extend(verify_manifest(root))
    return errors

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    args=parser.parse_args()
    problems=verify(args.root)
    if problems:
        print('FAIL: full Godot source is not present')
        for issue in problems: print(' -',issue)
        sys.exit(1)
    print('PASS: full source and representative asset inventory present (not runtime validation)')
