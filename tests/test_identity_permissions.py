"""Reject accidental legacy/ads permissions from merged native library manifests."""
import sys,tempfile,unittest,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'release'))
from verify_android_package import check,UNNEEDED_PERMISSIONS

class IdentityPermissions(unittest.TestCase):
 def test_forbidden_permissions_rejected_in_utf8_and_utf16_manifests(self):
  with tempfile.TemporaryDirectory() as directory:
   apk=Path(directory)/'test.apk'
   for permission in UNNEEDED_PERMISSIONS:
    for encoding in ('utf-8','utf-16-le'):
     with zipfile.ZipFile(apk,'w') as archive:
      archive.writestr('AndroidManifest.xml',permission.encode(encoding))
     self.assertIn('Unnecessary Android permission: '+permission,check(apk))
 def test_identity_library_declares_sdk_to_avoid_implicit_legacy_permissions(self):
  manifest=(ROOT/'native/android-identity/src/main/AndroidManifest.xml').read_text()
  self.assertIn('android:minSdkVersion="24"',manifest)
  self.assertIn('android:targetSdkVersion="36"',manifest)
