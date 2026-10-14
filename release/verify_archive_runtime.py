#!/usr/bin/env python3
"""Verify the exact source ZIP that would be uploaded, not a richer working folder."""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path
from zipfile import ZipFile
from source_archive import verify_archive


def check(path: Path) -> None:
    count = verify_archive(path)
    with tempfile.TemporaryDirectory(prefix="gaminghub-source-check-") as tmp:
        root = Path(tmp)
        with ZipFile(path) as archive:
            archive.extractall(root)
        commands = [
            [sys.executable, 'release/verify_project_upload.py'],
            [sys.executable, 'tests/run_checks.py'],
        ]
        for command in commands:
            subprocess.run(command, cwd=root, check=True)
    print(f'UPLOAD_ARCHIVE_TESTS_PASS ({count} files)')

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('archive',type=Path)
    args=parser.parse_args()
    check(args.archive.resolve())
