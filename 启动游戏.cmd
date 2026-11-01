@echo off
setlocal
cd /d "%~dp0"
set "GAME_NODE=node.exe"
where node.exe >nul 2>nul
if not errorlevel 1 goto preview
set "GAME_NODE=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
if not exist "%GAME_NODE%" goto missing

:preview
"%GAME_NODE%" scripts\serve-godot.mjs --open
if errorlevel 1 goto failed
goto end

:missing
echo Please install Node.js 24 LTS from https://nodejs.org/ and try again.
:failed
pause
exit /b 1
:end
endlocal
