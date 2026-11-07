@echo off
cd /d "%~dp0"
if not exist "tools\python\python.exe" (
  echo Extract the portable release archive first, or run scripts/streetview_capture.py with Python 3.11.
  pause
  exit /b 1
)
"tools\python\python.exe" "scripts\streetview_capture.py" %*
pause
