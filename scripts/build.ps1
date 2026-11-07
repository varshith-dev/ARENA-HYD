param([switch]$SkipAndroid,[switch]$TestOnly)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
$godot = Join-Path $projectRoot 'tools/godot/godot_console.exe'
if (!(Test-Path $godot)) { throw 'Run scripts/setup-tools.ps1 first.' }
$python = Join-Path $projectRoot 'tools/python/python.exe'
if (!(Test-Path -LiteralPath $python)) { $python = (Get-Command python3.11 -ErrorAction SilentlyContinue).Source }
if (!$python) { $python = (Get-Command python -ErrorAction Stop).Source }
& $python scripts/prepare_map.py
if ($LASTEXITCODE -ne 0) { throw 'OSM geometry preparation failed' }
& $python scripts/validate_map.py
if ($LASTEXITCODE -ne 0) { throw 'OSM geometry validation failed' }
& $godot --headless --path game --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
$ErrorActionPreference = 'Continue'
$testOutput = & $godot --headless --path game --quit-after 600 -- --test 2>&1
$testExit = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
$testOutput | Set-Content build/gameplay-tests.log
$testOutput | Write-Output
if ($testExit -ne 0 -or ($testOutput -join "`n") -notmatch 'ALL TESTS PASSED' -or ($testOutput -join "`n") -match 'SCRIPT ERROR:') { throw 'Gameplay tests failed' }
if ($TestOnly) { exit 0 }
& $godot --headless --path game --export-release Web ../build/web/index.html
if ($LASTEXITCODE -ne 0) { throw 'Web export failed' }
& $godot --headless --path game --export-release 'Windows Desktop' ../build/windows/ArenaHyderabad.exe
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed' }
if (!$SkipAndroid) {
    & $godot --headless --path game --export-debug Android ../build/android/ArenaHyderabad.apk
    if ($LASTEXITCODE -ne 0) { throw 'Android export failed' }
}
$bytes = (Get-ChildItem $projectRoot -Recurse -File -Force | Measure-Object -Property Length -Sum).Sum
if ($bytes -gt 50000000000) { throw "Storage exceeds 50 GB: $bytes bytes" }
Write-Output ('Workspace storage: {0:N2} GB / 50 GB' -f ($bytes/1e9))
