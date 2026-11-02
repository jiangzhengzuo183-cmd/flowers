@echo off
setlocal
cd /d "%~dp0"
where npm.cmd >nul 2>nul
if errorlevel 1 goto portable
if not exist "node_modules\vite\package.json" (
  call npm.cmd install
  if errorlevel 1 goto failed
)
call npm.cmd run dev -- --open
goto end

:portable
set "GAME_NODE=node.exe"
where node.exe >nul 2>nul
if not errorlevel 1 goto portable_npm
set "GAME_NODE=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
if not exist "%GAME_NODE%" goto missing
set "PATH=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin;%PATH%"

:portable_npm
if not exist ".tools\package\bin\npm-cli.js" goto missing
if not exist "node_modules\vite\package.json" (
  "%GAME_NODE%" .tools\package\bin\npm-cli.js install
  if errorlevel 1 goto failed
)
"%GAME_NODE%" .tools\package\bin\npm-cli.js run dev -- --open
goto end

:missing
echo Please install Node.js 24 LTS from https://nodejs.org/ and try again.
:failed
pause
exit /b 1
:end
endlocal
