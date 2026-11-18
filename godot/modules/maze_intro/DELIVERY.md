# 三个迷宫统一入场动画（2026-11-18）

正式工程：D:/ChatGPT/献给阿尔吉侬的花束/godot/project.godot。仅在此工程内修改，原有未提交内容保留。

## 交付行为

Maze01、Maze02、Maze03 统一实例化 modules/maze_intro/MazeIntroController.tscn。俯视采用当前真实 3D 迷宫，临时相机放在玩家所属的同一个 3D 世界中，俯视构图由实际地图尺寸、视口比例与 FOV 自动计算，不使用静态地图。

| 时段（秒） | 表现 |
| --- | --- |
| 0–0.45 | 展示完整迷宫俯视，HUD 隐藏，锁定操作 |
| 0.45–1.35 | 四个方向不同速度的奶白云雾逐渐合拢 |
| 1.15–1.55 | 深褐色测试标题轻微缩放、淡入 |
| 1.55–2.55 | 标题稳定保持约 1 秒 |
| 2.55–4.8 | 不规则云窗从中央打开，云层退向边缘 |
| 2.65–4.95 | 镜头沿平滑曲线下降，推进到原游戏相机位置和角度 |
| 4.65–5.0 | HUD 淡入，完成精确相机交接，清除临时相机与输入遮挡 |

标题分别为「第一次测试」「第二次测试」「第三次测试」。Maze03 比赛模式显示小号「竞速模式」。使用项目已有中文手写字体，云雾为程序 Shader，无新增下载素材、黑屏、扫描线或科技网格。

Maze01/02：5 秒过场后继续原有 3、2、1、GO，GO 后恢复操作并启动计时。Maze03 比赛模式：过场结束后才进入原有准备和 3、2、1、GO；阿尔吉侬路线、犹豫点、变速、55.5 秒目标和计时结算规则保持。Maze03 探索模式：过场结束即可操作和计时，不生成比赛专用倒数或老鼠。

入场期间屏蔽移动、冲刺开关、跳跃、道具使用、交互及相机输入；角色保持原位置。独立暂停竞速准备阶段，未使用 Engine.time_scale，也未修改移动、体力、屏障、蛋糕或圣堂机制。临时相机交接后恢复原跟随与鼠标转向；保留滚轮缩放与现有菜单。

## 本次同时调整

- 查理从原始长舞蹈连续播放前 4.5 秒，1 倍速、非循环，不重复短动作。完成或胜负结算仍在动作结束后出现。
- 手绘鼠标按最新反馈进一步放大至可见高度 84px（比上一版 52px 增大约 62%），帧画布 80×92；三帧抽帧抖动保持，点击热点 (7,6) 随新尺寸重新计算并在各帧中固定。原 PNG 未改。
- 计时数字和冒号只去除白边，字重使用原深褐字形的范围，不将原白边补成棕色，不额外加粗。所有非透明像素保持统一 #4C3D2F；只闭合一像素的内部细小接缝。原始 PNG、画布比例、固定显示槽与 HUD 布局保留。timer_bold 目录名仅沿用历史引用，不代表继续加粗。
- 新进入 Maze03 默认 Race；ESC 仍可选择 Explore，显式选择后重开保留该模式。返回选择页重新进入 Maze03 则默认 Race。

## 配置与接口

controller.gd 的 Inspector 参数：duration_seconds（默认 5）、overview_padding（默认 1.16）、overview_height（0 为自动）、overview_center（INF 为地图中心）。install(adapter, information) 可接收 maze_number、title、game_mode、game_camera、overview_height、overview_center。默认读取共享 HUD 适配器提供的真实场景、玩家出生位置与当前游戏相机。

started / completed 信号用于观察入场生命周期；active 表示输入锁定阶段。重复重开在同一控制器上重置，不生成多套系统。离开场景释放世界中的临时相机和整套云雾节点；临时相机异常丢失时恢复原相机、HUD 和操作。快速切换场景时，已离开的旧场景不会继续执行延迟的鼠标捕获。

Race 新增 set_entrance_active(bool)，只延后准备/倒数，不改变正式比赛的推进和计时。PlayFlow 新增 hold_for_intro / begin_gameplay，原有正常入场倒数和完成结算继续由 PlayFlow 负责。

## 文件清单

新增：

- modules/maze_intro/MazeIntroController.tscn
- modules/maze_intro/controller.gd
- modules/maze_intro/clouds.gdshader
- tests/maze_intro/check_intro.gd、check_edges.gd
- 本交付说明

修改：

- modules/game_hud/runtime.gd：统一挂载、默认 Race、入场输入屏蔽和交互提示同步。
- modules/game_hud/play_flow.gd：过场结束后启动原有倒数，异常时释放操作。
- modules/game_hud/mouse_look.gd：过场期间屏蔽视角输入，结束恢复捕获，退出保护。
- modules/maze03_race/controller.gd：竞速准备等待过场，保留原规则。
- scripts/maze/maze_scene.gd：入场期间不转发相机输入。
- scripts/characters/charlie_visual.gd：连续舞蹈 4.5 秒。
- tools/import-hand-cursor.ps1、assets/UI/HUD/hand_cursor/regions.gd 与三张派生帧。
- tools/import-bold-timer.ps1、assets/UI/HUD/timer_bold/ 的 11 张派生字形。
- modules/game_hud/CURSOR_TIMER_DELIVERY.md：追加当前更新说明。

三个迷宫关卡场景、建筑、路线、原始模型、相机默认参数、体力数值、HUD 排列和玩法资源均未修改。

## 实际运行验证

Godot 4.7.2、Compatibility、RTX4060 Laptop 原生图形窗口，1920×1080。当前验收入口为 tests/maze_intro 下的测试；旧 HUD 测试记录针对当时无过场/7.2 秒舞蹈流程。

完整流程检查 check_intro.gd：95 项通过、0 失败，实际启动 Maze01、Maze02、Maze03，并检查 Maze03 Explore。

- 所有地图四个角完整进入俯视构图；标题正确；云雾、HUD 和倒数阶段衔接正常。
- 入场期间 E、Shift、空格、滚轮和鼠标运动不会开始交互或改动默认相机；计时始终为零。
- 三条相机路径均未穿越实际实体碰撞，最终相机交接位置误差均为 0；原距离 7、俯角 0.45、FOV 48 保留。
- 三个迷宫的控制、鼠标转向、ESC 暂停和正向计时恢复正常。
- Maze01/02 原始连续舞蹈到 4.5 秒结束；Maze03 比赛完成流程同样等待 4.5 秒再结算。
- 阿尔吉侬实跑两次均为 55.4999977 秒；老鼠先到后计时继续，结算用例在 56.6333333 秒把查理送入实际终点触发区，届时才判负并停止计时。
- 探索模式、同场景重开、中途切换场景、单一控制器与素材字形/鼠标热点检查通过。

边界检查 check_edges.gd：22 项通过、0 失败，且日志无脚本异常。验证相机 0.16m 近裁剪净空、圣堂透视/时间凝滞及真实计时、蛋糕和屏障原有加速、比赛中延后切换模式、确认重开、过场中再次重开、临时相机丢失恢复、设置关闭自动鼠标转向，以及 F5/F6 选择迷宫三默认比赛。

舞蹈与结算使用现有完成标志/真实终点触发器验证，未将自动化结算用例当作人工通关成绩。

截图和详细断言：D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze-intro/（未纳入 Git，避免提交大量验收图片）。每个迷宫包含 overview、clouds、title、descent、countdown、gameplay 六张实际运行截图。

运行命令（工程根目录）：

```powershell
& './.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path godot --rendering-method gl_compatibility --fixed-fps 60 --disable-vsync --script res://tests/maze_intro/check_intro.gd
& './.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path godot --rendering-method gl_compatibility --fixed-fps 60 --disable-vsync --script res://tests/maze_intro/check_edges.gd
```

本轮验收使用原生图形窗口，未重新导出或发布 Web。云雾由实时 Shader 绘制，其他显卡/浏览器的性能仍需对应平台实测。

最新鼠标尺寸复核：84px 可见高度、80×92 三帧导入、固定尖端及实际原生鼠标动画检查，共 9 项通过、0 失败；日志 .verification/cursor-enlarged-verified.log。
