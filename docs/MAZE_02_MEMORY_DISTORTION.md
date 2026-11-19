# Maze 02 · Memory Distortion

在 Godot 打开 `godot/scenes/levels/MazeSelect.tscn`，按 **F6**，选择 **Maze 01** 或 **Maze 02**。左上角的「返回迷宫选择」会卸载当前迷宫。也可以打开 `Maze02.tscn` 按 F6，或在 Windows 双击 `试玩Maze02.cmd`。F5 仍启动 `project.godot` 指定的正式主场景。

两个迷宫在 Godot 桌面版都提供「纯画面 F10」和「全屏 F11」。前者让 3D 画面填满当前窗口，后者切换系统全屏。**Esc** 恢复窗口和栏目。移动、镜头、拾取和 E 开门沿用原操作，**Q** 可以使用已选中的主动道具。浏览器版沿用之前的全屏方式。

## 隔离和复用

当前仓库的 Maze 01 入口是 `scenes/levels/maze_01_greybox.tscn`。它继承旧迷宫布局场景，运行时通过同一套地图和生成器建立建筑、碰撞、路线和四扇门。Maze02 的场景文件独立保存界面与世界节点，运行时复用当前的玩家、跟随和全图摄像机、建筑生成、路线、音频、HUD 和道具脚本。幸运钱币与马蹄铁继续由现有背包和拾取系统管理，保留 Maze02 既有摆放和开门规则。Maze02 局部停用幸运兔脚的生成、测试点与道具栏按钮，重置仍使用原有钥匙流程。Maze01 的兔脚照常运行。

`art/maze02/environment/` 独立保存 WorldEnvironment 使用的 Environment、内嵌 Sky 和 ShaderMaterial、天空着色器和共享天空代码的本地副本。日光、补光和 38 盏局部环境灯通过 Maze02 场景与灯光预设设置。远景城市继续使用已有模型和生成方式，独立应用色彩、雾化及显示开关。云海、薄雾、月亮、星星和流星使用 Maze02 的着色器，原有程序生成器仍供两个关卡复用。道具和机关自身的状态光效继续由各自实例的通用代码控制。

加载检查递归读取场景和资源依赖，包含脚本预加载、相对路径、着色器 include、GLB 及其贴图。两场景仍会加载通用脚本内部引用的旧环境，Maze02 在首帧渲染前应用自己的预设。建筑与道具材质仍按共享资源使用。后续如果要改其中某项外观，应先为 Maze02 增加局部材质覆盖。环境、天空、材质与灯光的修改试验已验证对 Maze 01 无影响。

## 场景效果

天空从奶油金地平线过渡到杏橙中层和更深的橙黄高空。较高处有弥散暖雾和少量微光。云海和远景城市模型保留。低处街区融入缓慢移动的沙尘，塔尖和受光面保留微弱亮度，暖窗沿用克制的小亮点。

保留原有青蓝建筑色块，紫色墙面归入奶油米白。约 55% 的米白表面（487/885）使用浅细砂、石粉及局部剥蚀，由遗迹周边渐变到干净哑光面。残墙接缝将重叠的面内缩错开，断墙细裂纹直接在材质上绘制，远距离颗粒逐步淡出。四扇机关门沿用原釉面材质实例，边角有少量小掉漆，门板上有几道浅划痕，保留门符、充能和机关动画。教堂 G6、G7 和 G8 各有 26 个拱石、上墙和门柱面使用本地石膏纹理。

室外环境使用与 Maze01 同一组近地和中层薄雾节点，Maze02 的本地着色器改为弥漫的浅黄色沙尘，并以较慢速度流动。定时橘色阵风已取消。持续沙粒仍由 `World/Maze02SandParticles` 批量绘制，密度降低，圆厅雾化减弱。

原生截图 `sand_haze_bridge.png`、`apricot_horizon.png` 和 `worn_gate.png` 分别记录桥上的薄雾、远城和机关门掉漆。

雕像院的草地保留干草黄、灰橄榄和少量残绿。H5 三条鱼每隔 **3.2–5.7 秒**轮流跃出约 **0.48 秒**，跃起时向前划弧，鱼心最高约高出水面 **0.18 m**，落水后衔接游动。水珠调小，落点仍有水花与涟漪。

Maze02 出口暂停生成医生。配乐为 54 秒的原创立体声循环《沙中回廊》。风沙底噪是独立的 24 秒低音量循环，室外约 −27 dB，进圆厅逐渐压至 −41 dB，与原来的声音开关同步。

## 遗迹与改道

以下坐标为从零起算的 `[行, 列]`。三处断拱的主路开口保持净空，落石实际封住相邻支路。断墙保留原墙的 0.30 m 厚度，拱石和断柱沿用约 0.40 m 厚度。缺口有局部断面颗粒、落石、细裂纹和积尘，封堵与残墙使用实际网格碰撞。

| 区域 | 封堵 | 替代路线 |
|---|---|---|
| 西南 G2，断冠拱 | `[16,3] ↔ [16,4]` | `[16,3] → [15,3] → [15,4] → [15,5] → [16,5] → [16,4]` |
| 西北 G3，断柱 | `[5,5] ↔ [5,6]` | `[5,5] → [5,4] → [6,4] → [6,5] → [6,6] → [5,6]` |
| 东北 G5，残拱 | `[1,17] ↔ [2,17]` | `[1,17] → [1,18] → [2,18] → [2,17]` |

本轮新增四处地点，均可用「查看关卡位置」跳转。

| 新遗迹 | 走法 |
|---|---|
| 北侧风蚀墙 | `[1,8] ↔ [1,9]` 新缺口 |
| 西侧石廊旁 | `[10,2] ↔ [10,3]` 新缺口 |
| 东庭残墙 | `[12,17] ↔ [13,17]` 新缺口 |
| 南庭 G4 缺角拱 | 断开右上拱石，保留拱下通行 |

南缘 H1 已恢复原桥面、护栏和通行路线。A/B 参考线沿用原走法，东侧高架桥和 D4 保持原结构。遗迹外的普通碎石沿实体墙脚集中在 42 个格子，约占全图 11.6%，以大中小搭配成小堆。碎石贴合可行走地面，避开水面、机关和拾取点。

三处蓝色幽影已从运行场景暂停挂载，原始场景、模型、材质及位置记录保留。以下坐标为原摆放使用的 `World` 坐标。

| 节点 | 实际位置 | 调整 |
|---|---|---|
| `ChapelEcho` | 中央圆厅，G6 北门内、书台西北侧 (22.72, 0.044, 22.05) | 高约 1.46 m，透明度 0.64，16 粒蓝光 |
| `BridgeEcho` | H2 上层桥，D4 南侧的东护栏内 (40.04, 2.645, 18.02) | 高约 1.36 m，可从侧台和南坡观察，10 粒 |
| `CornerEcho` | H6 南端平地，[11,1] 向 [11,0] 的转角内侧 (3.96, 0.043, 28.09) | 高约 1.27 m，出生点视线受阻，8 粒 |

每个点位是独立 Marker3D，包含 `Figure` 和 `BlueMotes`。幽影的宽深比例收窄，节点距地面约 4–5 cm，上下浮动约 1–2 cm。幽影没有碰撞或通关条件。后续可以通过 `Figure.dissolve_over(seconds)`、`restore()` 和 `dissolved` 信号接入靠近事件或对话。当前探索顺序自由，门厅幽影以更高可见度承担第一次发现的引导。

## 运行和复查

使用 Godot 4.7.2，在项目根目录运行以下检查。Windows 可用 `.tools/godot/` 下的便携引擎替换命令里的 `godot`。

```powershell
godot --headless --path godot --editor --import --quit
godot --headless --path godot --fixed-fps 60 --script res://tests/levels/check_maze02_isolation.gd
godot --headless --path godot --fixed-fps 60 --script res://tests/levels/check_maze02_ruins.gd
godot --headless --path godot --fixed-fps 60 --script res://tests/levels/check_maze01_keys.gd
godot --headless --path godot --fixed-fps 60 --script res://tests/levels/check_maze01_rabbit_foot.gd
godot --headless --path godot --fixed-fps 60 --script res://tests/levels/check_maze_01_greybox.gd
godot --path godot --script res://tests/levels/check_maze02_isolation.gd -- --capture
```

对照检查覆盖 4,339 个共用世界节点及 120 个天空和氛围材质实例。角色测试走通恢复后的 H1、三个新缺口与之前的三条替代路线。四扇门的 16 种开关组合对照可达区域。选择入口依次切换 Maze 01 → Maze 02 → Maze 01 并检查旧世界释放与纯画面模式。截图和测试日志位于被 Git 忽略的 `.verification/maze02/`。

本机无窗口检查及 OpenGL Compatibility 原生检查均通过。两个场景分别通过钥匙拾取、开门、出口和重置检查。原 Maze 01 另通过幸运兔脚专项。

无窗口检查覆盖三条鱼各自的出水和落水涟漪。Godot 原生测试环境曾记录着色器缓存无法写入和 OpenGL 退出时的纹理释放提示。未重新导出 Web 或测试长时间性能。

## 文件与回滚

- 隔离阶段新增 `godot/scenes/levels/Maze02.tscn`、`godot/scripts/levels/maze02_scene.gd`、`godot/art/maze02/environment/` 中的环境和着色器副本、`godot/tests/levels/check_maze02_isolation.gd` 及 `试玩Maze02.cmd`。
- 视觉阶段修改 `Maze02.tscn`、`maze02_environment.tres`、`maze02_lighting.tres`、`maze02_lighting.gd`、`path_breeze.gdshader`、`sky_memories/distant_city.gdshader`、`maze02_scene.gd` 和 `check_maze02_isolation.gd`。
- 新增 `environment/Maze02_SandParticles.tscn`、`environment/maze02_sand.gd`、`environment/maze02_sand.gdshader`。新增 `memory_ghost/Maze02_MemoryEchoes.tscn` 和源幽影资源的六个项目内副本及 Godot 导入元数据。源幽影资产位于项目 `res://` 之外，因此在 `godot/art/maze02/memory_ghost/` 保存运行副本。
- 选择入口新增 `godot/scenes/levels/MazeSelect.tscn` 和 `godot/scripts/levels/maze_select.gd`。本说明及新资源的 Godot `.uid` 文件也随模块交付。
- 本任务无删除文件。隔离检查点为 `codex/maze02-isolation` 上的 `e723978`，只记录 Maze02 隔离相关文件。回滚需保留当前工作区原有的 Maze 01 开发文件，因为其中有尚未提交的共享依赖。
- 风沙强化修改 Maze02 的 `maze02_sand.gd`、`maze02_sand.gdshader`、`path_breeze.gdshader`、`cloud_sea.gdshader`、`maze02_environment.tres` 和 `maze02_lighting.gd`，未新增运行文件或修改共享接口。
- 本轮色彩调整新增 Maze02 局部 `memory_plaster.gd`、`memory_plaster.gdshader`、`memory_plaster_fade.gdshader`、`memory_plaster.gdshaderinc` 和 `maze02_key_items.gd`。修改 `maze02_scene.gd`、`maze02_lighting.gd`、`maze02_environment.tres`、`dream_sky.gdshader`、`dream_sky_background.gdshaderinc`、`check_maze02_isolation.gd` 和本说明。无文件删除或共享接口修改。
- 记忆风化细化新增 `maze02_dry_garden.gd`、`maze02_fish_leaps.gd`、`fish_ripple.gdshader`。遗迹轮新增 `maze02_generator.gd`、`art/maze02/ruins/` 内的几何和材质、`audio/sandstone_corridor_loop.wav` 及 `check_maze02_ruins.gd`。
- 本轮新增 `maze02_floor_debris.gd`、`maze02_gate_wear.gd` 和 `audio/sand_wind_bed.wav`，附 Godot 导入信息。调整 Maze02 场景脚本、石膏和遗迹材质、远城、沙雾和两项关卡检查。删除已取消的定时阵风脚本及着色器。两迷宫的桌面纯画面切换接入现有 `maze01_key_scene.gd` 和 `maze01_fullscreen_layout.gd`。
