@echo off
setlocal
cd /d "%~dp0"
if exist ".tools\godot\Godot_v4.7.2-stable_win64.exe" (
  start "" ".tools\godot\Godot_v4.7.2-stable_win64.exe" --editor --path "%~dp0godot"
  exit /b
)
where godot.exe >nul 2>nul
if not errorlevel 1 (
  start "" godot.exe --editor --path "%~dp0godot"
  exit /b
)
echo Install Godot 4.7.2 Standard from https://godotengine.org/download/windows/
echo Then import godot/project.godot in the Godot Project Manager.
pause
