# Maze02 幽影引导与随风消散

工程：`D:\ChatGPT\献给阿尔吉侬的花束\godot`。只在 `Maze02.tscn` 接入。

## 最终表现

两处幽影复用 `res://art/maze02/memory_shade/MemoryShade.tscn`，其中模型为 `Ghost_MemoryShade_Modified.glb`，动画为现有 `look_around_001` 和 `walk_001`。原 GLB、材质、动画和预览场景未修改。

本轮实例的身体透明度为 0.33、衣服 0.56、头发 0.47，主体更明确地偏蓝，轮廓柔光略增强，保留透感和原有微粒。

根据最终要求，**蓝色经纬线已取消，没有 AtlasGlobeEffect 场景、节点或运行时调用**。教堂幽影抵达后停留 1 秒，再逐渐化为蓝白发光微粒，顺着当前沙尘的 +X 风向飘散，约 3.6 秒后完全淡出。桥洞幽影始终保留，不消散。

## 布置与实际路线

相对于 `Maze02/ViewportContainer/Viewport/World`：

| 节点 | 脚底坐标 / 朝向 |
|---|---|
| `Maze02GhostEvent/Ghost_Church` | `(25.4, 0, 23.45)`，初始 Y 转角 -2.5 弧度 |
| `Maze02GhostEvent/Ghost_BridgeUnderpass` | `(39.75, 0, 15.65)`，初始 Y 转角 -π/2 |

教堂书台原位置为 `(24, 0.025, 22.8)`；幽影在其侧后方，独立书籍及台座保持不动。阿特拉斯原位置 `(22.8, 0, 15.6)`，幽影停在东南侧 `(23.6, 0, 16.75)`。

复用现有道具系统从真实碰撞生成的 `walkable_routes.gd` 图。`Maze02KeyItems.guidance_routes()` 只暴露这一个现有图引用，不创建第二套导航。

当前实测简化路线：`(25.4,0,23.45) → (23.1,0,19.5) → (23.6,0,16.75)`，经过教堂北门 G6。简化每段均通过原有玩家胶囊的碰撞扫掠；幽影以 0.95 米/秒、`CharacterBody3D.move_and_slide()` 实际移动，不传送、不穿墙。步行动画速度按原片段步幅同步。

桥洞为 H2 的 `LevelArchitecture/ArchedUnderpass`，有效范围 X=38.65–40.55、Z≈14.99–16.81，拱顶 2.4 米。第二处幽影稍靠北侧，保留通行宽度，角色碰撞层为 0，不阻挡玩家。

## 状态和未来对话接口

`ghost_actor.gd`：

`Idle → PlayerDetected → LookAtPlayer → StartGuidance → WalkingToAtlas → Arrived → Dissolving → Dissolved`

两处各有 `Approach` Area3D，半径 2.1 米、mask=2，仅识别现有玩家。教堂接近还需视线不被建筑遮挡，转向停留约 1 秒，事件每次关卡只执行一次；桥上不能隔地板触发桥洞人物。

- 教堂：`player_approached(ghost, player)`，观察结束后的 `guidance_requested(ghost)`，公开 `start_guidance()`，`guidance_started`，`guidance_finished(ghost)`，`dissolved(ghost)`。
- 未来接入对话时设置 `auto_start_guidance=false`，监听 `guidance_requested`；对话结束后调用 `start_guidance()`。当前没有对话监听器或 UI。
- 桥洞：独立 `player_approached`、`dialogue_requested(ghost, player)` 信号。本轮没有连接对话系统，接近不会移动、转状态或触发消散。
- 重置关卡会恢复两处初始位置、蓝色材质、待机动画和一次性触发状态，并移除上一轮消散粒子。

## 消散实现

`ShadeWindDissolve.tscn` / `shade_wind_dissolve.gd` / `shade_dissolve_mask.gdshaderinc` 为独立效果组件。

保留现有蓝色材质，仅为教堂这一实例的材质链复制 Shader 并叠加柔和细粒消散遮罩；原始 Shader 文件和资源不变。变体在场景初始化时准备，避免抵达时才准备全部变体。重置和退出均恢复原 Shader 引用。

读取现有 GLB 网格、蒙皮权重和当时的骨骼姿态，在真实人物表面采样 260 个起点。复用现有 `MemoryMotes.tscn` 的柔边粒子纹理，采用两个 MultiMesh 绘制蓝白亮芯和较大的低强度蓝色柔光。身体约 1.45 秒逐渐碎化；微粒有错开的释放时间，向 +X 漂移，轻微上扬并有扰动，最后缩小淡出。没有粒子灯光，不改全局 Glow、环境或音频。

## 文件改动

新增本目录的 3 个 TSCN、3 个脚本、1 个 Shader include、本说明及 Godot 自动生成的 UID 文件；新增 `tests/levels/check_maze02_ghosts.gd`。

仅修改以下已有文件：

- `scenes/levels/Maze02.tscn`：独立事件场景实例。
- `scripts/levels/maze02_scene.gd`：初始化与关卡重置调用。
- `scripts/levels/maze02_key_items.gd`：只读导航引用接口。
- `tests/levels/check_maze02_isolation.gd`：对照排除新增事件分支，原有世界节点仍完整比较。

没有删除任何任务开始前已有的资源。经纬线相关的本轮试作文件已移除；没有改动 Maze01、共享玩家、原始幽影与雕像、建筑路线、碰撞、天空、灯光、入口或道具摆放。

## 运行与验证

打开 `scenes/levels/MazeSelect.tscn`，F6 后选择 Maze02，再走近教堂书台侧的幽影；也可直接 F6 运行 Maze02。项目正式主入口保持原样。

命令行（在 Godot 根目录，`godot` 替换为实际引擎）：

```powershell
godot --headless --path . --fixed-fps 60 --quit-after 1800 --script res://tests/levels/check_maze02_ghosts.gd
godot --path . --fixed-fps 60 --quit-after 1800 --script res://tests/levels/check_maze02_ghosts.gd
godot --headless --path . --fixed-fps 60 --script res://tests/levels/check_maze02_isolation.gd
godot --headless --path . --fixed-fps 60 --script res://tests/levels/check_maze02_items.gd
```

幽影检查覆盖真实 Area 触发、桥上/桥下隔离、一次性行为、路径逐段可通行、整段运动不穿墙、脚底位置、玩家同时可移动、抵达后延迟消散、角色表面采样、实际渲染粒子的顺风位移、结束淡出、对话接口等待/恢复、重置和场景释放，随后加载 Maze01。

无画面模式的 MultiMesh 图形读回恒为零，故图形实例位移只在有画面的运行中断言。截图采用当前 Maze02 的真实渲染，拍摄时仅隐藏查理以避免遮挡；正式场景不隐藏玩家。

### 本轮实测结果

- Godot 4.7.2 / GL Compatibility：有画面的完整幽影测试与无画面物理测试均通过，`MAZE02_GHOSTS PASS failures=0`。
- 原有 Maze02 道具回归：`MAZE 02 MARKED ITEMS: 0 failures`。
- Maze01 钥匙与机关回归：`MAZE 01 GATE KEYS: PASS (0 failures)`。
- 两场景隔离对照：比较 4287 个原有世界节点、递归检查 248 个依赖，`failures=0`。建筑、原碰撞、原有相机/环境组织和通用系统的检查均通过。
- 本轮开始前的原始幽影 GLB、MemoryShade 场景/脚本/材质、雕像 GLB/场景、书台、Maze01 场景、共享玩家及 project.godot 已用 SHA256 再次核对。本轮没有写入这些文件。
- 当前工作区还有其他已有或同时发生的改动；检查期间也检测到 `scripts/main.gd`、`MazeSelect.tscn`、`maze_select.gd`、`dream_pink.tres` 的独立变化，本轮没有写入或覆盖它们。上述运行测试基于当前工作区。

新增消散仅有 260 个表面采样点和两批粒子绘制，不创建单粒子光源。本机实际渲染和流程检查通过；尚未做低配置硬件或 Web 导出性能测试。

Windows 的 Compatibility 渲染在退出测试进程时仍会输出两条既有纹理释放日志（每条 87380 bytes）；在本轮接入前的原场景截图运行中已能复现。本轮最终测试没有新增脚本解析错误、运行异常或断言失败；该退出日志未在本轮修复。

验证日志和分阶段截图：`C:\Users\30968\.codex\visualizations\2026\11\08\01a1bc3b-28c7-7653-91b4-630ad88e0bdd\ghost-atlas-20261115`。关键文件为 `final-native-ghost.log`、`final-ghost.log`、`final-items.log`、`final-isolation.log`、`final-maze01.log`，视觉阶段为 `farewell_body_to_grains.png`、`farewell_wind.png`、`farewell_end.png`。
