param([string]$GodotExe = "", [switch]$PackageOnly, [ValidateSet("All","Full","Mazes")][string]$Edition = "All")
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
if (-not $GodotExe) { $GodotExe = Join-Path $repo ".tools/godot/Godot_v4.7.2-stable_win64_console.exe" }
$engine = (Resolve-Path -LiteralPath $GodotExe).Path
if ($Edition -eq "All") {
 & $PSCommandPath -GodotExe $engine -Edition Full -PackageOnly:$PackageOnly
 & $PSCommandPath -GodotExe $engine -Edition Mazes -PackageOnly:$PackageOnly
 return
}
$isMaze = $Edition -eq "Mazes"
$preset = if ($isMaze) { "Windows Mazes" } else { "Windows Desktop" }
$folder = if ($isMaze) { "AlgernonMazes" } else { "FlowersForAlgernon" }
$exeName = if ($isMaze) { "三迷宫体验.exe" } else { "献给阿尔吉侬的花束.exe" }
$productName = if ($isMaze) { "献给阿尔吉侬的花束 · 三迷宫体验" } else { "献给阿尔吉侬的花束" }
$iconName = if ($isMaze) { "maze_flowers.ico" } else { "flower_bouquet.ico" }
$entryText = if ($isMaze) { '打开后沿用原有三迷宫选择界面，选择任意迷宫直接游玩。第三次测试默认竞速模式，保留加载、入场、321GO、统一HUD、重开及返回选择。' } else { '主菜单“开始游戏”进入视觉小说。已包含当前工程的新版剧情、进步报告、三个迷宫、加载画面、音乐音效与剧情视频。' }
$project = Join-Path $repo "godot"
$target = Join-Path $project ("exports/windows/"+$folder)
$logs = Join-Path $repo ".verification/windows-package"
New-Item -ItemType Directory -Path $target,$logs -Force | Out-Null
$executable = Join-Path $target $exeName
if (-not $PackageOnly) {
Write-Host "正在整理游戏资源……"
& $engine --headless --path $project --editor --import --quit --log-file (Join-Path $logs "build-import-engine.log") *> (Join-Path $logs "build-import-output.log")
if ($LASTEXITCODE -ne 0) { throw "资源导入失败，请查看 .verification/windows-package/build-import-output.log" }
Write-Host "正在导出完整 Windows 游戏……"
$exportLog = Join-Path $logs "build-export-output.log"
& $engine --headless --path $project --export-release $preset $executable --log-file (Join-Path $logs "build-export-engine.log") *> $exportLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $exportLog -Pattern '(^|\s)(SCRIPT ERROR|ERROR):' -Quiet)) { throw "导出失败，请查看 .verification/windows-package/build-export-output.log" }
}
if (-not (Test-Path -LiteralPath $executable)) { throw "未生成游戏程序" }
$readme = @"
$productName — Windows 电脑版

使用方法
1. 将整个压缩包解压到文件夹。
2. 双击“$exeName”开始游戏。
3. 不需要安装 Godot；游戏资源已全部内置在程序中，可离线运行。

$entryText
迷宫操作与画面设置可在游戏右上角查看。

桌面快捷方式
在游戏程序上点击鼠标右键，创建快捷方式并放到桌面。程序和快捷方式均使用对应版本的新图标。

本包为 Windows x64 免安装版，保持当前工程的游戏内容与存档机制。
第三方资源来源及许可见 licenses 文件夹。
"@
[IO.File]::WriteAllText((Join-Path $target "开始游戏说明.txt"),$readme,[Text.UTF8Encoding]::new($true))
Copy-Item -LiteralPath (Join-Path $project "assets/app_icon/$iconName") -Destination (Join-Path $target "花束图标.ico") -Force
$licenses = Join-Path $target "licenses"
New-Item -ItemType Directory -Path $licenses -Force | Out-Null
$notices = @{
 "tools/desktop/LICENSE-Godot.txt" = "Godot-MIT.txt"
 "godot/assets/fonts/LICENSE.txt" = "SourceHanSans-OFL.txt"
 "godot/assets/UI/HUD/fonts/OFL.txt" = "HUD-font-OFL.txt"
 "godot/modules/visual_novel/assets/fonts/REPORT-FONT-LICENSE.md" = "Report-font-notice.txt"
 "godot/modules/visual_novel/assets/audio/LICENSE-SOURCES.md" = "Story-audio-sources.txt"
 "godot/modules/visual_novel/assets/audio/CC0-1.0.txt" = "CC0-1.0.txt"
 "godot/art/maze01/audio/MUSIC_CREDITS.md" = "Maze01-music.txt"
 "godot/modules/maze02_items/assets/AUDIO_CREDITS.md" = "Maze02-audio.txt"
 "godot/modules/maze03_final/MUSIC_CREDITS.md" = "Maze03-music.txt"
}
foreach ($entry in $notices.GetEnumerator()) { Copy-Item -LiteralPath (Join-Path $repo $entry.Key) -Destination (Join-Path $licenses $entry.Value) -Force }
$head = (& git -C $repo rev-parse HEAD).Trim()
$manifest = [ordered]@{ product=$productName; edition=$Edition; platform="Windows x64"; built_at=(Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'); source_commit=$head; embedded_resources=$true; working_tree_changes=[bool](& git -C $repo status --porcelain); executable=(Split-Path -Leaf $executable); bytes=(Get-Item -LiteralPath $executable).Length; sha256=(Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash.ToLowerInvariant() }
[IO.File]::WriteAllText((Join-Path $target "build-info.json"),($manifest | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
$archiveStem = if ($isMaze) { "献给阿尔吉侬的花束-三迷宫体验-Windows-" } else { "献给阿尔吉侬的花束-Windows-" }
$archive = Join-Path (Split-Path -Parent $target) ($archiveStem+(Get-Date -Format 'yyyyMMdd')+".zip")
Write-Host "正在生成可发送的压缩包……"
Compress-Archive -LiteralPath $target -DestinationPath $archive -CompressionLevel Optimal -Force
$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(($archive+".sha256"),($archiveHash+"  "+(Split-Path -Leaf $archive)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
Write-Host "导出完成：" $archive
Write-Host "解压后双击游戏程序即可游玩。"
