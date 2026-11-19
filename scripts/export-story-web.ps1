$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engineCommand = Get-Command godot.exe -ErrorAction SilentlyContinue
$enginePath = if ($engineCommand) { $engineCommand.Source } else { Join-Path $projectRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $enginePath)) {
    $enginePath = Join-Path $projectRoot '../flowers-bakery-integration/.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Godot not found. Install Godot 4.7.2 and its Web export template.' }
& $enginePath --headless --path (Join-Path $projectRoot 'godot') --export-release Web
if ($LASTEXITCODE -ne 0) { throw 'Godot Web export failed.' }
& node (Join-Path $PSScriptRoot 'package-story-media.mjs')
if ($LASTEXITCODE -ne 0) { throw 'Story media packaging failed.' }
Write-Output 'Web game and local story video exported. No publication was performed.'
