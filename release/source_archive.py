#!/usr/bin/env python3
"""Build and verify a deterministic GitHub-ready archive of the complete source.

No secrets, build output, cache, or locally generated Android signing keys are included.
"""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

from source_manifest import ROOT, inventory, verify as verify_source

MANIFEST = 'release/source_manifest.json'


def _entries(root: Path) -> dict[str, str]:
    errors = verify_source(root)
    if errors:
        raise ValueError('Invalid source manifest: ' + '; '.join(errors[:5]))
    entries = inventory(root)
    entries[MANIFEST] = hashlib.sha256((root / MANIFEST).read_bytes()).hexdigest()
    return entries


def build(destination: Path, root: Path = ROOT) -> tuple[int, int]:
    entries = _entries(root)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(destination, 'w', compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for name in sorted(entries):
            source = root / name
            if source.is_symlink():
                raise ValueError('Symlinks are forbidden: ' + name)
            info = ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, source.read_bytes(), compress_type=ZIP_DEFLATED, compresslevel=9)
    verify_archive(destination)
    return len(entries), destination.stat().st_size


def verify_archive(archive_path: Path) -> int:
    with ZipFile(archive_path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate paths in source archive')
        for name in names:
            parts = Path(name).parts
            if name.startswith('/') or '..' in parts or '\\' in name:
                raise ValueError('Unsafe archive path: ' + name)
        if MANIFEST not in names:
            raise ValueError('Missing source manifest')
        manifest = json.loads(archive.read(MANIFEST))
        expected = manifest['sha256']
        if manifest.get('file_count') != len(expected):
            raise ValueError('Invalid file count in archive manifest')
        if set(names) != set(expected) | {MANIFEST}:
            raise ValueError('Archive contents differ from source manifest')
        for name in names:
            if name == MANIFEST:
                continue
            if hashlib.sha256(archive.read(name)).hexdigest() != expected[name]:
                raise ValueError('Archive checksum mismatch: ' + name)
        if archive.testzip() is not None:
            raise ValueError('Corrupted ZIP entry')
        return len(names)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path)
    parser.add_argument('--verify', type=Path)
    args = parser.parse_args()
    if args.verify:
        print('SOURCE_ARCHIVE_VERIFIED', verify_archive(args.verify))
    else:
        output = args.output or ROOT.parent / 'GamingHub_v9.5_Hoor_Zain_Visuals.zip'
        count, size = build(output)
        print('SOURCE_ARCHIVE_BUILT', output, count, size)
