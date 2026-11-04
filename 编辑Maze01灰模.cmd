@echo off
setlocal
cd /d "%~dp0"
set "ENGINE=%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe"
if exist "%ENGINE%" goto launch
set "ENGINE=%~dp0..\..\..\.tools\godot\Godot_v4.7.2-stable_win64.exe"
if exist "%ENGINE%" goto launch
where godot.exe >nul 2>nul
if errorlevel 1 goto missing
set "ENGINE=godot.exe"
:launch
start "" "%ENGINE%" --editor --path "%~dp0godot" res://scenes/levels/maze_01_greybox.tscn
exit /b
:missing
echo Open Godot, import godot/project.godot, then open
echo scenes/levels/maze_01_greybox.tscn and run the current scene.
pause
