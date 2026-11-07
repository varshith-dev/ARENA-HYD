param([string]$AndroidSdk,[string]$JavaHome,[switch]$InstallPythonDependencies)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
New-Item -ItemType Directory -Force -Path tools/godot/editor_data,build/windows,build/web,build/android | Out-Null
if (!(Test-Path tools/godot/godot.exe)) { throw 'Extract ARENA-HYD-portable-windows.zip here, or place Godot 4.7.2 in tools/godot first.' }
Set-Content -LiteralPath tools/godot/_sc_ -Value '' -Encoding ascii
if ($InstallPythonDependencies) {
    $python = Join-Path $projectRoot 'tools/python/python.exe'
    if (!(Test-Path -LiteralPath $python)) { $python = (Get-Command python3.11 -ErrorAction SilentlyContinue).Source }
    if (!$python) { $python = (Get-Command python -ErrorAction Stop).Source }
    & $python -m pip install --target tools/python-libs -r scripts/requirements.txt
    if ($LASTEXITCODE -ne 0) { throw 'Python dependencies failed' }
}
if ($AndroidSdk -or $JavaHome) {
    if (!$AndroidSdk -or !$JavaHome) { throw 'Supply both -AndroidSdk and -JavaHome for Android export configuration.' }
    if (!(Test-Path -LiteralPath $AndroidSdk) -or !(Test-Path -LiteralPath $JavaHome)) { throw 'Android SDK or Java directory does not exist.' }
    $settings = @"
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$($AndroidSdk.Replace('\','/'))"
export/android/java_sdk_path = "$($JavaHome.Replace('\','/'))"
"@
    Set-Content -LiteralPath tools/godot/editor_data/editor_settings-4.7.tres -Value $settings -Encoding UTF8
}
& ./tools/godot/godot_console.exe --headless --path game --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
Write-Output 'Ready. Open game/project.godot or run scripts/run-editor.ps1. Existing Windows builds run without Python or an Android SDK.'
