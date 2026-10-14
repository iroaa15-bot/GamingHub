# Run this script after extracting GamingHub_v9.3_GitHub_Source.zip.
# Uses GitHub CLI's interactive login. Never requests or stores tokens in a file.
$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path (Join-Path $PSScriptRoot '..'))
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Install Git for Windows first.' }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'Install GitHub CLI (gh) first.' }
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw 'Install Python 3 first.' }
gh auth status
if ($LASTEXITCODE -ne 0) { gh auth login; if ($LASTEXITCODE -ne 0) { throw 'GitHub login failed' } }
python release/verify_project_upload.py
if ($LASTEXITCODE -ne 0) { throw 'Source verification failed' }
python tests/run_checks.py
if ($LASTEXITCODE -ne 0) { throw 'Tests failed' }
python release/sync_to_github.py --publish --branch gaminghub-v9.3-source-upload
if ($LASTEXITCODE -ne 0) { throw 'Upload failed' }
Write-Host 'Upload complete. Review draft PR: https://github.com/iroaa15-bot/GamingHub/pull/1'
