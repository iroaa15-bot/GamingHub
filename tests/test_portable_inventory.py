import hashlib
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'release'))
from source_manifest import inventory, write
from source_archive import build, verify_archive

class PortableInventoryTests(unittest.TestCase):
    def test_windows_and_linux_text_match_without_changing_binary(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'scripts').mkdir()
            (root / 'assets').mkdir()
            script = root / 'scripts/probe.gd'
            script.write_bytes(b'extends Node\r\n')
            binary = b'\x00PNG\r\n\xff'
            (root / 'assets/probe.png').write_bytes(binary)
            windows = inventory(root)
            script.write_bytes(b'extends Node\n')
            self.assertEqual(windows, inventory(root))
            self.assertEqual(windows['assets/probe.png'], hashlib.sha256(binary).hexdigest())

    def test_archive_and_manifest_agree_after_checkout_line_conversion(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / 'source'
            (root / 'scripts').mkdir(parents=True)
            (root / 'release').mkdir()
            script = root / 'scripts/probe.gd'
            script.write_bytes(b'extends Node\r\n')
            write(root)
            script.write_bytes(b'extends Node\n')
            archive = Path(folder) / 'source.zip'
            count, _ = build(archive, root)
            self.assertEqual(count, verify_archive(archive))
