param(
    [ValidateSet('debug','release')][string]$Mode = 'debug',
    [string]$Godot = 'godot'
)
$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path (Join-Path $PSScriptRoot '..'))
$version = & $Godot --version
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.5\.1') { throw "Godot 4.5.1 required; found: $version" }
python release/verify_project_upload.py
if ($LASTEXITCODE -ne 0) { throw 'Source upload verification failed' }
python tests/run_checks.py
if ($LASTEXITCODE -ne 0) { throw 'Python checks failed' }
& $Godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $Godot --headless --path . --script res://tests/godot_smoke.gd
if ($LASTEXITCODE -ne 0) { throw 'Godot smoke failed' }
& $Godot --headless --path . --quit-after 60
if ($LASTEXITCODE -ne 0) { throw 'Godot boot failed' }
New-Item -ItemType Directory -Force -Path build | Out-Null
# Godot 4.5 CLI requires --install-android-build-template together with --export-*.
$TemplateArg = @()
if (!(Test-Path 'android/.build_version')) { $TemplateArg = @('--install-android-build-template') }
if ($Mode -eq 'debug') {
  & $Godot --headless --path . @TemplateArg --export-debug Android build/GamingHub-v11.5-debug.apk
  if ($LASTEXITCODE -ne 0) { throw 'Debug APK export failed' }
  python release/verify_android_package.py build/GamingHub-v11.5-debug.apk
} else {
  if (-not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -or -not $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER -or -not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD) {
    throw 'Release keystore path, alias and password must be configured in environment variables'
  }
  & $Godot --headless --path . @TemplateArg --export-release "Android Release" build/GamingHub-v11.5-release.aab
  if ($LASTEXITCODE -ne 0) { throw 'Release AAB export failed' }
  python release/verify_android_package.py build/GamingHub-v11.5-release.aab --release
  if ($LASTEXITCODE -ne 0) { throw 'Invalid signed AAB structure' }
  Write-Host 'NOTICE: AAB targetSdkVersion 36 MUST be verified through bundletool or Play Console before publishing.' 
}
if ($LASTEXITCODE -ne 0) { throw 'Android package verification failed' }
Write-Host 'Build produced; real-device QA and Play approval are still required.'
