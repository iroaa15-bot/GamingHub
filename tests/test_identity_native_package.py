"""Reject stale native identity binaries before shipping an APK."""
import hashlib,io,json,unittest,zipfile
from pathlib import Path
from xml.etree import ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
ANDROID='{http://schemas.android.com/apk/res/android}'

class NativeIdentityPackage(unittest.TestCase):
 def test_packaged_classes_match_reviewed_native_sources(self):
  for variant in ('debug','release'):
   with self.subTest(variant=variant),zipfile.ZipFile(ROOT/f'addons/gaminghub_identity/bin/gaminghub-identity-{variant}.aar') as aar:
    evidence=json.loads(aar.read('assets/gaminghub_identity_build.json'))
    self.assertEqual(evidence['schema'],2)
    for name,digest in evidence['sources'].items():
     actual=hashlib.sha256((ROOT/name).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
     self.assertEqual(actual,digest,'Rebuild identity AAR after changing '+name)
    self.assertIn('native/android-identity/src/main/java/com/gaminghub/identity/ProviderLogin.java',evidence['sources'])
    self.assertIn('native/android-identity/src/main/java/com/gaminghub/identity/AvatarPicker.java',evidence['sources'])
    with zipfile.ZipFile(io.BytesIO(aar.read('classes.jar'))) as classes:
     for name in ('GamingHubIdentityPlugin','ProviderLogin','AvatarPicker'):
      self.assertIn('com/gaminghub/identity/'+name+'.class',classes.namelist())
    manifest=ET.fromstring(aar.read('AndroidManifest.xml'))
    sdk=manifest.find('uses-sdk')
    self.assertEqual(sdk.get(ANDROID+'minSdkVersion'),'24')
    # AGP may omit targetSdk from library AARs; the app export targets API 36.
    self.assertGreaterEqual(int(sdk.get(ANDROID+'targetSdkVersion',sdk.get(ANDROID+'minSdkVersion'))),24)
    metadata={item.get(ANDROID+'name'):item.get(ANDROID+'value') for item in manifest.findall('application/meta-data')}
    for key in ('AutoInitEnabled','AutoLogAppEventsEnabled','AdvertiserIDCollectionEnabled','AutoLogProductImprovementEnabled'):
     self.assertEqual(metadata.get('com.facebook.sdk.'+key),'false')
