$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$editor = Join-Path $projectRoot 'tools/godot/godot.exe'
if (!(Test-Path -LiteralPath $editor)) { throw 'Extract the portable tools release archive into the project folder first.' }
Start-Process -FilePath $editor -ArgumentList '--editor','--path',('"'+(Join-Path $projectRoot 'game')+'"')
