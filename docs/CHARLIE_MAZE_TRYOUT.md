# 查理接入迷宫试玩

在当前 `feature/charlie-rig` 工作区导入 `godot/project.godot`，按 F5 后直接进入迷宫，不再经过开场剧情页。当前界面只显示“迷宫试玩”，故事入口隐藏；剧情场景、脚本与文本保留，便于团队后续接回。本次沿用原查理网格、贴图与权重，游戏实例改用 `charlie_refined.glb`：只修订 Run 的六根手臂/手掌骨骼动作；原 `charlie.glb` 与 `charlie_rigged.blend` 保留。

入口简化涉及 `godot/scripts/main.gd`、`godot/scenes/main.tscn`、`godot/tests/check_project.gd`、根 `README.md` 与本说明，共五个文件，无新增或删除文件。启动检查、人物集成与 A/B 路线检查通过，原生画面确认直接进入迷宫；Web release 同步导出。此项没有修改柔和配色参数，其可读性问题仍需另行修正。

## 操作

- WASD / 方向键：走路，1.6 米/秒，步频按实际移动速度加快。
- 按住 Shift + 移动：跑步，2.7 米/秒。
- 松开移动键或被墙挡住：待机。动画速度来自碰撞处理后的实际水平位移。
- 鼠标拖动：观察；滚轮：缩放；“回到入口”：重置人物位置与待机。
- “俯视全貌 / 全图查看”：停用人物操作；“亲自走迷宫”：恢复操作。

迷宫内暂不接物理跳跃；Jump 保留在 `godot/scenes/characters/charlie_preview.tscn`，打开该场景按 F6、数字 4 可独立查看。

## 实现与接口

`godot/scripts/maze/walk_player.gd` 仍负责 `CharacterBody3D` 的输入、重力、碰撞、边界和转向；其视觉子节点改为实例化 `charlie_visual.tscn`，通过现有 `set_locomotion(speed)` 接口驱动 Idle / Walk / Run。原胶囊半径 0.3、高 1.6，地图和墙体碰撞不变。

`maze_scene.gd` 更新走路/跑步提示；`follow_camera.gd` 默认距离 2.8 米、俯角 0.68 弧度，48° 视野，让人物占据更多画面。拖动、2.5–150 米缩放、全图切换和重置仍可用。

`maze.tscn` 采用 AgX（白点 6）、低对比度色彩设置，以及主光、无阴影补光和较淡阴影，减少过曝与生硬明暗。目标是接近 GIF 的柔和观感；实时游戏与 Blender 棚拍预览不能保证逐像素一致。全图镜头、共享入口、全局主题、依赖和地图 JSON 不变。

## 检查

将下列 `godot` 替换为本机引擎可执行文件：

```powershell
godot --headless --path godot --script res://tests/check_project.gd
godot --headless --path godot --fixed-fps 60 --script res://tests/characters/check_charlie.gd
godot --headless --path godot --fixed-fps 60 --script res://tests/characters/check_maze_charlie.gd
godot --headless --path godot --fixed-fps 60 --script res://tests/characters/check_look_refinement.gd
node tools/charlie/check_refined_glb.mjs
```

集成检查覆盖实际输入驱动的待机/走路/跑步、撞墙停止动画、朝向、回到入口、全图模式，以及保持真实碰撞、逐格走完原始路线 A（60 步）和 B（92 步）。同时校验地图原始 SHA-256。

带画面的短流程检查及截图：

```powershell
godot --path godot --fixed-fps 60 --resolution 1280x900 --script res://tests/characters/check_maze_charlie.gd -- --capture --smoke-only
```

截图写入被忽略的 `.verification/charlie/maze_integration/`。`--smoke-only` 只检查操作和视图切换，不遍历完整路线；完整路线使用上面的无界面命令验证。

正面、侧面跑步姿势与默认近景截图可运行：

```powershell
godot --path godot --fixed-fps 60 --resolution 1280x900 --script res://tests/characters/check_look_refinement.gd -- --capture
```

输出到 `.verification/charlie/look_refinement/`。其中正侧面姿势图会临时隐藏墙体显示以便观察手脚；默认视角截图和正常游戏保留墙体。检查比较原版与修正版的动作，确认非手臂动作保持，跑步手掌横向跨度与最高位置下降。

本轮结果：四项 Godot 检查、GLB 差异检查、原地图检查与 TypeScript 检查通过；A/B 路线真实控制器自动通过 60/92 步。Web release 导出成功，内置浏览器实际进入迷宫并执行走路/Shift 跑步，控制台错误和警告均为空。尚未覆盖所有浏览器与设备。

## 本轮外观与动作改动文件

- 修改 `godot/scenes/maze.tscn`、`godot/scripts/maze/follow_camera.gd`、`godot/scripts/maze/walk_player.gd`：光照、近景镜头和走路速度。
- 修改 `godot/scenes/characters/charlie_visual.tscn`：实例化修正版；对外接口不变。
- 修改 `tools/charlie/animate_charlie.py`：供完整构建与增补构建共用的跑步手臂参数。
- 新增 `tools/charlie/refine_run.py`、`tools/charlie/check_refined_glb.mjs`：增补制作与保留性校验。
- 新增 `art/characters/charlie/charlie_refined.blend`、`run_refinement_report.json`，以及 `godot/assets/characters/charlie/charlie_refined.glb`、提取的同名 JPEG 和导入设置。
- 新增 `godot/tests/characters/check_look_refinement.gd` 及 UID；更新 `check_maze_charlie.gd` 与 `godot/tests/check_project.gd` 的速度/镜头验收。
- 更新根 README、本说明与角色 README。截图和网页成品位于被忽略的验证/导出目录。
- 没有删除文件，原模型和原地图文件指纹保持不变；没有改动角色接口、依赖或全局工程配置。

## 后续交付与限制

角色资源、场景、脚本和测试随本次 `feature/charlie-rig` 功能一起交付；仅提交控制器会缺少角色资源。Godot 缓存、引擎和导出产物不提交。根据用户要求提交并推送此功能分支，由团队审阅后决定是否合并 main；用户原有的 `godot/project.godot` 编辑器改动单独保留在本机，不混入功能提交。

基础程序步态仍可能滑步，转向、围裙与腿部混合姿势需要继续试玩润色；胶囊控制碰撞，伸出的手臂不是独立碰撞体。没有新增视错觉结构、门、二层、跳跃规则或出口结算。
