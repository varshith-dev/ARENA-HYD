@echo off
cd /d "%~dp0"
if not exist "build\windows\ArenaHyderabad.exe" (
  echo Extract the portable release archive into this project folder first.
  pause
  exit /b 1
)
start "ARENA Hyderabad" "build\windows\ArenaHyderabad.exe"
