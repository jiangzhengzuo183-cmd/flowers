# 三个迷宫统一镜头入场（2026-11-18）

正式工程：D:/ChatGPT/献给阿尔吉侬的花束/godot/project.godot。

## 当前入场流程

三个迷宫共用 MazeIntroController.tscn。按最新要求，已取消测试字幕与屏幕云雾遮盖，画面从真实 3D 迷宫全貌自然推进到查理。保留玩家输入锁定、HUD 渐显、相机交接和计时保护。

| 时段 | 表现 |
| --- | --- |
| 0–0.8 秒 | 稳定展示完整俯视图 |
| 0.8–5.85 秒 | 镜头缓慢起步，中段顺畅滑行，下降穿过对应场景的空气层，靠近查理时减速 |
| 5.64–6 秒 | HUD 渐显，镜头停稳并精确交回原跟随相机 |
| 6 秒后 | Maze01/02 和 Maze03 比赛模式继续原有准备/321GO；Maze03 探索模式直接开始 |

采用连续曲线与五次缓动，起止速度、加速度均归零；原游戏相机的距离、俯角、FOV 和滚轮缩放保留。

## 穿过迷雾、风沙与风流

空气层位于真实三维世界中，沿镜头路径的三个深度位置分布，位置固定在场景内，不随镜头贴屏移动。镜头实际走进、穿出这些区域，形成前景掠过、透视放大和近中远遮挡差异。

- Maze01：轻暖偏粉白的薄雾团与缓慢流动的雾丝，沿用场景原有色调；穿入时局部对比降低，穿出后恢复清晰。
- Maze02：暖黄沙尘层与三维沙粒；沙粒横向流动，并因离镜头远近而呈现不同尺寸和速度感。
- Maze03：清淡冷白空气与较近的笔直风丝，直接复用已有风丝 Shader、风向和流速设定。

场景原有雾、沙、风、灯光、天空和阴影持续运作。额外空气层仅服务镜头路径，颜色参照各场景与太阳色，接近镜头时柔化消失；抵达后全部释放，不改变正式游玩中的美术参数、碰撞或玩法。没有屏幕云雾贴层或字幕。

## 保护与复用

入场期间禁止移动、冲刺开关、跳跃、道具使用、机关交互和相机输入，计时保持为零。Maze03 的老鼠准备和倒数等待入场完成，正式 55.5 秒竞速规则、独立圣堂减速、体力与加速规则均不变。

重开在同一控制器上重置；中途离开释放临时相机与空气层。临时相机异常丢失时恢复原相机、HUD 和操作。已离开的旧场景不会继续处理鼠标焦点通知。

可调整参数：duration_seconds（默认 6 秒）、overview_hold_seconds（默认 0.8 秒）、overview_padding（默认 1.16）、overview_height（0 自动）、overview_center（INF 为地图中心）。install(adapter, information) 可传入相机和俯视构图参数；started/completed 信号与 active 状态保持。

## 本轮文件

- modules/maze_intro/controller.gd：纯镜头流程、缓动节奏、临时空气层生命周期。
- modules/maze_intro/air_passage.gd：世界坐标中的雾、沙粒与近处风流。
- modules/maze_intro/air_mist.gdshader：柔和雾层、深度接触和镜头近处淡化。
- modules/maze_intro/air_grain.gdshader：柔边沙粒及透视尺寸。
- modules/game_hud/mouse_look.gd：离开场景后的焦点通知保护。
- tests/maze_intro/check_intro.gd、check_edges.gd：更新入场时序、穿越检测与清理检查。
- 本交付说明。

删除已停用的 modules/maze_intro/clouds.gdshader 及 UID。共用 MazeIntroController.tscn 保留；三个关卡的建筑、路线、模型、HUD 布局、环境资源和玩法参数均未改。

## 当前已保留的相关设置

查理连续播放原舞蹈前 4.5 秒；鼠标可见高度 84px（三帧 80×92，热点 7,6）；计时数字按原字形去白边，不额外加粗；新进入 Maze03 默认 Race，明确选 Explore 后重开保留 Explore。

## 运行验收

环境：Godot 4.7.2 Compatibility，RTX4060 Laptop，原生 1920×1080 图形窗口。

最终完整流程 113 项、边界回归 24 项，均通过，日志无脚本异常。验证三个迷宫及 Maze03 两种模式、0.8 秒俯视停留、真实穿入三维空气层、原环境持续运行、空气层清理、镜头交接误差为 0、控制/暂停/计时、圣堂和加速、重开与 F5/F6 入口。阿尔吉侬完整实跑仍为 55.4999977 秒；结算通过真实终点触发器验证，未当作人工通关成绩。

当前验收记录见 .verification/maze-intro/final-passage.log 与 final-passage-edges.log。旧带字幕/云雾的截图与日志仅为历史版本。

实际截图每个迷宫包含：01_overview、02_departure、03_glide、04_approach、05_countdown、06_gameplay。路径为 D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze-intro/，截图未提交至 Git。

运行方式（工程根目录）：

```powershell
& './.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path godot --rendering-method gl_compatibility --fixed-fps 60 --disable-vsync --script res://tests/maze_intro/check_intro.gd
& './.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path godot --rendering-method gl_compatibility --fixed-fps 60 --disable-vsync --script res://tests/maze_intro/check_edges.gd
```

本轮未重新导出 Web。Compatibility 中空气体积由多层三维软雾和粒子表现，其他设备与浏览器性能尚需对应平台实测。
