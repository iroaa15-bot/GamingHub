import importlib.util
import unittest
from pathlib import Path
from xml.etree import ElementTree as ET

spec=importlib.util.spec_from_file_location('android_template',Path(__file__).resolve().parents[1]/'release/prepare_android_template.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class AndroidBackTemplateTests(unittest.TestCase):
    def test_preserves_existing_manifest_and_overrides_predictive_default(self):
        text='<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.INTERNET"/><application android:label="GamingHub" android:enableOnBackInvokedCallback="true"><activity android:name="com.godot.game.GodotApp"/></application></manifest>'
        updated=module.patch_manifest(text)
        app=ET.fromstring(updated).find('application')
        self.assertEqual(app.get('{'+module.ANDROID+'}enableOnBackInvokedCallback'),'false')
        self.assertEqual(app.get('{'+module.ANDROID+'}label'),'GamingHub')
        self.assertIn('android.permission.INTERNET',updated)
        self.assertEqual(module.patch_manifest(updated),updated)

    def test_adds_attribute_without_rewriting_other_elements(self):
        text='<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n<application android:label="GamingHub">\n<!-- retained -->\n</application></manifest>'
        updated=module.patch_manifest(text)
        self.assertIn('<!-- retained -->',updated)
        self.assertIn('android:enableOnBackInvokedCallback="false"',updated)

    def test_rejects_missing_or_invalid_template(self):
        for text in ['<manifest/>','not XML']:
            with self.assertRaises((ValueError,ET.ParseError)):module.patch_manifest(text)

if __name__=='__main__':unittest.main()
