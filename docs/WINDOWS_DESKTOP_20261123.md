# Windows 电脑版打包

交付当前工作工程的 Windows x64 免安装版。导出预设为 Windows Desktop，使用同版本 Godot 4.7.2 官方运行模板，Compatibility 渲染，资源内嵌 EXE。原 Web 预设保留。未改动剧情文本、迷宫布局、速度、体力、道具或竞速规则。

用户花束 PNG 原样保存在 godot/assets/app_icon/flower_bouquet.png；ICO 包含 16、24、32、48、64、128、256 像素透明帧，已写入 EXE 资源和产品信息。项目图标已切换，旧 SVG 保留。

原 story_video 只在 Web 播放 MP4，桌面直接跳过。本轮增加 native_story_video，以内置 VideoStreamPlayer 播放同一原片转出的 Theora/Vorbis，保留原片与 Web 播放。开始、自然结束、Esc 或按钮跳过共用原 completed 回调，恢复原有剧情及音乐，不新增外部播放器和网络依赖。原片 1280×720、约 5.14 秒，FFmpeg 6.1.1 转为 24fps；转换后完整解码无错误，并检查 Godot 实际画面。最初旧编码器的破块版本已替换，不作为交付资源。

## 导出与分发

- 双击仓库根目录“导出Windows电脑版.cmd”，或运行 tools/export-windows.ps1。可通过 GodotExe 参数指定引擎；另一台开发电脑需在 Godot 安装同版本 Windows 导出模板。
- Godot“项目 → 导出”可直接选择 Windows Desktop；目标 godot/exports/windows/FlowersForAlgernon/献给阿尔吉侬的花束.exe。
- 一键脚本还生成说明、花束 ICO、资源授权、build-info.json 以及带日期 ZIP 和 SHA256 文件；PackageOnly 选项用于仅封装已验证的 EXE。
- 玩家只需解压并双击 EXE，无需 Godot。程序不依赖源码目录。跨进程存档仍沿用当前工程，未新增存档机制。
- 构建产物、引擎和视频转换工具被 Git 忽略；源码中保留导出配置、图标、转码视频、原片和脚本。

## 验证

直接用导出的 EXE 内嵌包（非源码工程）运行 check_package.gd：31 项通过。覆盖必需 JSON、默认主菜单与标题动画、加载进入新版视觉小说、工具栏、原生进步报告、真实剧情网关进入三个迷宫、全画布 HUD、Maze03 竞速模式、退出迷宫、原生视频解码推进、自然结束返回剧情、按钮跳过只完成一次。日志没有 SCRIPT ERROR 或 ERROR；综合退出仍有此前既存的 ObjectDB 清理提示。截图位于 docs/screenshots/desktop。没有将完整剧情逐句通关、所有报告页或其他电脑的运行记为本次已验证。

另以导出的 EXE 本身、不附加测试脚本启动，并使用运行模板支持的录帧功能检查默认入口。官方运行模板禁止外部脚本路径覆盖，所以自动接入检查由同版本引擎加载 EXE 内嵌包，真实 EXE 启动单独检查，共录制 240 帧，正常退出码 0；两者没有混为同一个测试。

参考：[Windows 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)、[内置视频格式](https://docs.godotengine.org/en/stable/tutorials/animation/playing_videos.html)。

## 两个独立版本

1. Windows Desktop：花束图标，默认纸面主菜单 → 完整视觉小说 → 三迷宫。ZIP 文件名保持“献给阿尔吉侬的花束-Windows-日期.zip”。
2. Windows Mazes：新迷宫图标，默认现有 scenes/main.tscn → 原 scenes/levels/MazeSelect.tscn。按用户要求保留原入口、排版和三个按钮，没有新增选择界面。三个关卡仍为现有成品，Maze03 默认 Race；不加入剧情流程。ZIP 为“献给阿尔吉侬的花束-三迷宫体验-Windows-日期.zip”。

通过 maze_desktop 自定义导出特征覆盖第二版的 main_scene、名称、图标和用户目录；源码的 F5 默认入口及完整剧情版不受影响。迷宫版排除主菜单与视觉小说的场景、脚本、数据和美术，仅保留加载画面实际共用的字体；没有复制或改写三个关卡。

一键脚本默认生成两版；Edition Full / Mazes 可单独导出，另有“导出三迷宫体验版.cmd”。第二版真实内嵌包 43 项检查通过，包括原版选择页、三迷宫加载、全画布 HUD、入场输入锁定及倒计时结束放行、竞速默认模式、重开与返回原选择、鼠标和暂停状态恢复。没有脚本错误；退出仍有此前既有 ObjectDB 提示。实际 EXE 不附测试脚本启动、录制 240 帧并正常退出。

视频再次核对：从最终完整剧情 EXE 中抽出实际内嵌 Theora，逐帧解码 121 帧、退出码 0，SHA256 为 45520c6d055ccd476f6566034f03f2643835179126e14427aafd7ffc9005dff8。当前包内的原生播放截图已确认无之前的破块；聊天中旧破块截图对应被替换的中间转换文件。
