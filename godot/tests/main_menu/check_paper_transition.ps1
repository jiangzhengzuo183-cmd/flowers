param([string]$GodotExecutable = "")
$ErrorActionPreference = 'Stop'
$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
if (-not $GodotExecutable) { $GodotExecutable = Join-Path $repo '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' }
$output = Join-Path $repo '.verification/story-handoff'
New-Item -ItemType Directory -Force -Path $output | Out-Null
foreach ($script in @('check_paper_transition','check_day01_complete')) {
    $log = Join-Path $output ($script + '.log')
    & $GodotExecutable --path (Join-Path $repo 'godot') --rendering-method gl_compatibility --fixed-fps 60 --disable-vsync --script ("res://tests/main_menu/" + $script + ".gd") --log-file $log
    if ($LASTEXITCODE -ne 0) { throw "$script failed with exit $LASTEXITCODE" }
    $errors = @(Select-String -LiteralPath $log -Pattern '^SCRIPT ERROR:|^ERROR:')
    if ($errors.Count -gt 0) { throw (($errors | ForEach-Object { $_.Line }) -join [Environment]::NewLine) }
}
Write-Output 'PAPER_TRANSITIONS_PASS: paper monologue, real report animation and complete DAY01 reach DAY02 without runtime errors.'
