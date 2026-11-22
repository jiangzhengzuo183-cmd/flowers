param(
    [string]$GodotExecutable = ""
)
$ErrorActionPreference = 'Stop'
$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$project = Join-Path $repo 'godot'
if (-not $GodotExecutable) {
    $GodotExecutable = Join-Path $repo '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotExecutable)) { throw 'Pass -GodotExecutable with your Godot executable path.' }
$output = Join-Path $repo '.verification/main-menu/cold-start'
New-Item -ItemType Directory -Path $output -Force | Out-Null
# Start the actual project entry. Do not replace SceneTree with a --script fixture:
# fixtures that defer instantiation cannot reproduce a busy root during initial _ready.
foreach ($mode in @('first-frame','running')) {
    $log = Join-Path $output ($mode + '.log')
    $gameArgs = @('--path',$project,'--rendering-method','gl_compatibility','--fixed-fps','60','--disable-vsync','--log-file',$log)
    if ($mode -eq 'first-frame') {
        $gameArgs += @('--write-movie',(Join-Path $output 'frame.png'),'--quit-after','1')
    } else {
        $gameArgs += @('--quit-after','200')
    }
    & $GodotExecutable @gameArgs
    if ($LASTEXITCODE -ne 0) { throw "Default entry failed: $mode, exit=$LASTEXITCODE" }
    $errors = @(Select-String -LiteralPath $log -Pattern '^SCRIPT ERROR:|^ERROR:' | Where-Object { $_.Line -notmatch '^ERROR: Texture with GL ID' })
    if ($errors.Count -gt 0) { throw (($errors | ForEach-Object { $_.Line }) -join [Environment]::NewLine) }
}
$captures = @(Get-ChildItem -LiteralPath $output -Filter 'frame*.png')
if ($captures.Count -lt 1) { throw 'The actual default entry did not render its first frame.' }
Write-Output 'COLD_START_PASS: actual default entry rendered its first frame and ran 200 frames without startup errors.'
