@echo off
cd /d "%~dp0"
if not exist "tools\godot\godot.exe" (
  echo Extract the portable release archive into this project folder first.
  pause
  exit /b 1
)
start "ARENA editor" "tools\godot\godot.exe" --editor --path "%~dp0game"
