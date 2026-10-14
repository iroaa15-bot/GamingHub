# Install verified Poing Studios AdMob v5.1.0 for Godot 4.5.1

Official repository: https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0

| Artifact | SHA256 |
|---|---|
| poing-godot-admob-v5.1.0.zip | `8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f` |
| android-template-v4.5.1.zip | `f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee` |

The Windows installer downloads these assets, verifies hashes, installs Poing add-on and the native Android archive, sets official Google test App ID and optionally enables test ads.

Use `-EnableTestAds` only in a DEBUG APK; the included Poing bridge explicitly refuses to show ads outside an Android debug build and without UMP consent and selected adult (18+) age category. Children/teen/unknown profiles never see ads. Banners and interstitials remain disabled until they pass separate placement/consent/policy QA.

The `.gd.template` script is installed as `.gd` only after the official add-on is installed because the source uses `class_name` types declared by Poing. An uninstalled base project imports cleanly with ads disabled.

The plug-in must be installed and verified on Windows after downloading the project. This ZIP intentionally does not pretend to contain downloaded external AAR binaries.
