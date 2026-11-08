param(
    [string]$Godot = "godot",
    [switch]$SkipEditorImport
)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
if (-not (Test-Path "project.godot")) { throw "Run inside the GamingHub Godot project." }
python tools/audit_qaadet_el_sohab.py
if ($LASTEXITCODE -ne 0) { throw "Card audit failed." }
if (-not $SkipEditorImport) {
    & $Godot --headless --editor --path . --import --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot project import failed." }
}
$tests = @(
    "tests/social_rules_regression.gd",
    "tests/open_heart_offline_smoke.gd",
    "tests/act_it_offline_smoke.gd",
    "tests/who_among_us_offline_smoke.gd",
    "tests/show_skill_offline_smoke.gd",
    "tests/truth_or_fiction_offline_smoke.gd",
    "tests/table_flip_offline_smoke.gd"
)
foreach ($test in $tests) {
    if (-not (Test-Path $test)) { throw "Missing test: $test" }
    Write-Host "Running $test"
    & $Godot --headless --path . --script "res://$test"
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $test" }
}
Write-Host "SOCIAL_OFFLINE_TEST_SUITE_PASS"
