# Safe one-step installer for Poing Studios v5.1.0 + Godot 4.5.1
# Run from extracted Gaming Hub project directory in Windows PowerShell:
# powershell -ExecutionPolicy Bypass -File .\release\install_admob_windows.ps1
# Downloads are pinned to published SHA-256 release artifacts.
param([switch]$EnableTestAds)
$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$version = 'v5.1.0'
$release = "https://github.com/poingstudios/godot-admob-plugin/releases/download/$version"
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('gaminghub_admob_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
function Fetch-And-Verify($name,$hash) {
  $file = Join-Path $temp $name
  Write-Host "Downloading $name from official Poing Studios release ..."
  Invoke-WebRequest -Uri "$release/$name" -OutFile $file -UseBasicParsing
  $computed = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLowerInvariant()
  if ($computed -ne $hash.ToLowerInvariant()) { throw "Hash mismatch for $name. Aborted." }
  return $file
}
try {
  $plugin = Fetch-And-Verify 'poing-godot-admob-v5.1.0.zip' '8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f'
  $native = Fetch-And-Verify 'android-template-v4.5.1.zip' 'f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee'
  $addon = Join-Path $ProjectRoot 'addons\admob'
  if (Test-Path $addon) { throw "addons\admob already exists. Back up or review that installation before replacing it." }
  $extract = Join-Path $temp 'plugin'
  Expand-Archive -Path $plugin -DestinationPath $extract -Force
  $cfg = Get-ChildItem -Path $extract -Filter plugin.cfg -Recurse | Where-Object { $_.FullName -match 'admob' } | Select-Object -First 1
  if (-not $cfg) { throw 'Official release zip has no AdMob plugin.cfg; review the archive layout.' }
  $srcAddon = $cfg.DirectoryName
  New-Item -ItemType Directory -Path (Join-Path $ProjectRoot 'addons') -Force | Out-Null
  Copy-Item -Path $srcAddon -Destination $addon -Recurse -Force
  $bin = Join-Path $addon 'android\bin'
  New-Item -ItemType Directory -Path $bin -Force | Out-Null
  Expand-Archive -Path $native -DestinationPath $bin -Force
  # Poing 5.x exports native libraries via EditorExportPlugin GDScript, NOT legacy *.gdap.
  # Official generated paths live under addons/admob/android/bin/{ads,core,...}.
  $exports = @(Get-ChildItem -Path $bin -Filter 'poing_godot_admob_*.gd' -Recurse -ErrorAction SilentlyContinue)
  $aar = @(Get-ChildItem -Path $bin -Filter '*.aar' -Recurse -ErrorAction SilentlyContinue)
  if ($exports.Count -eq 0 -or $aar.Count -eq 0) { throw 'Poing 5.x native release is missing export scripts or .aar files.' }
  $template = Join-Path $ProjectRoot 'monetization\poing_admob_bridge.gd.template'
  if (!(Test-Path $template)) { throw 'Missing Gaming Hub adapter template.' }
  Copy-Item $template (Join-Path $ProjectRoot 'scripts\poing_admob_bridge.gd') -Force
  $project = Join-Path $ProjectRoot 'project.godot'
  $text = [System.IO.File]::ReadAllText($project)
  if ($text -notmatch '\[editor_plugins\]') {
    $text += "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/admob/plugin.cfg`")`n"
  } elseif ($text -notmatch 'res://addons/admob/plugin.cfg') {
    throw 'Editor plugins list exists; enable Poing AdMob manually to avoid overwriting other plugins.'
  }
  if ($text -notmatch 'PoingAdsBridge=') {
    # AdManager must be initialized before the bridge attaches to it.
    $manager = 'AdManager="*res://scripts/ad_manager.gd"'
    if (-not $text.Contains($manager)) { throw 'AdManager autoload not found: cannot safely install the bridge.' }
    $text = $text.Replace($manager, $manager + "`nPoingAdsBridge=`"*res://scripts/poing_admob_bridge.gd`"")
  }
  if ($text -notmatch '\[admob\]') {
    # Test App ID is required for test ads; never put production App ID into a debug build.
    $text += "`n[admob]`ngeneral/android/enabled=true`ngeneral/android/app_id=`"ca-app-pub-3940256099942544~3347511713`"`n"
  }
  [System.IO.File]::WriteAllText($project, $text, [System.Text.UTF8Encoding]::new($false))
  if ($EnableTestAds) {
    $config = Join-Path $ProjectRoot 'monetization\ad_config.json'
    $settings = Get-Content $config -Raw | ConvertFrom-Json
    $settings.mode = 'android_test_sdk'
    $settings.rewarded_enabled = $true
    $settings | ConvertTo-Json -Depth 12 | Set-Content $config -Encoding UTF8
  }
  # Update the signed source inventory after installing verified third-party add-on.
  & python (Join-Path $ProjectRoot 'release/source_manifest.py') --write
  if ($LASTEXITCODE -ne 0) { throw 'Failed to update source integrity manifest.' }
  Write-Host 'Poing AdMob v5.1.0 and binary template installed. Game stays test-only; production ads OFF.' -ForegroundColor Green
  Write-Host 'Next: open this project with Godot 4.5.1, wait for editor import, export Android using Gradle, verify on device.'
} finally {
  Remove-Item -Path $temp -Recurse -Force -ErrorAction SilentlyContinue
}
