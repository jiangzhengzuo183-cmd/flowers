# 查理：骨骼与基础动画

输入为用户提供的桌面 `Untitled.blend`，已在 Blender 5.2.3 LTS 中处理。原文件未改写。

## 文件与预览

当前游戏使用 `charlie_refined.glb`，可编辑源文件为 `charlie_refined.blend`。这是对原成品的增补版本：只收敛 Run 的上臂、前臂和手掌动作；网格、UV、法线、权重、贴图和其他动作保留。原 `charlie.glb`、`charlie_rigged.blend` 与六份 GIF 均保留，旧 GIF 展示的是修订前的跑步姿势。差异记录见 `run_refinement_report.json`。

- `charlie_rigged.blend`：可继续编辑的骨骼、权重与四个 Action，贴图已打包。
- `idle.gif`、`walk.gif`、`run.gif`：循环预览；`run_side.gif` 为新版跑步侧面。
- `jump.gif`、`jump_side.gif`：完整跳跃的正侧面预览，GIF 会重复展示，游戏动作本身只播放一次。
- `build_report.json`：几何、骨骼、贴图、权重与时长统计。
- `../../../godot/assets/characters/charlie/charlie.glb`：可直接导入 Godot 的模型，约 2.8 MiB。
- `../../../godot/scenes/characters/charlie_preview.tscn`：独立预览场景。
- `../../../godot/scenes/characters/charlie_visual.tscn`：供人物控制器挂载的视觉模块。

在 Godot 打开 `charlie_preview.tscn`，按 **F6** 运行当前场景。数字 **1/2/3/4** 切换待机、走路、跑步、跳跃；鼠标左键拖动旋转，滚轮缩放，空格暂停/继续。

在 Blender 打开 `charlie_rigged.blend`，默认已选中骨骼并启用 `Idle`。空格播放；切到“动画”工作区，在动作编辑器的 Action 下拉菜单中选择 `Idle`、`Walk`、`Run` 或 `Jump`。四段动作都保存在文件中。姿态模式可选骨骼修改动作，权重绘制模式可继续调整网格的顶点组。此骨架使用直接旋转的 FK 骨骼，没有 IK 控制器。

## 结构和动作

原模型只有一个网格，无骨骼、无动画、无顶点组；有一张打包的 4K 基础颜色贴图。源文件看似有 2,100 个网格岛，合并重合顶点后主要成为一个相连的表面，不能把它们当作已经拆开的衣服、头发和身体。

绑定使用 24 根骨骼，包括 Root、Hips、Spine、Chest、Neck、Head、左右肩/上臂/前臂/手掌、左右大腿/小腿/脚/脚趾，以及前后围裙。Blender 自动热权重求解失败，因此改用适配该模型的身体分区和贴图颜色掩码，再平滑关节权重。头部整体跟随头骨；鞋子以刚性权重为主；围裙与毛巾跟随专门的围裙骨骼。

运行时模型为 **48,756 个三角面、24,392 个 Blender 网格顶点、一种材质、一张 2048×2048 JPEG 基础颜色贴图**。glTF 会因 UV/法线接缝拆分顶点，因此导入后的顶点数可能更高。所有顶点均已绑定，最多 4 根骨骼影响，权重归一化。使用线性蒙皮，与 Godot 的实际渲染一致。

| Action / Godot 动作名 | 时长 | Blender 范围 | 内容 |
|---|---:|---:|---|
| Idle | 3 秒 | 1–91 | 呼吸、轻微头部和手臂摆动 |
| Walk | 1 秒 | 1–31 | 双腿交替迈步、反向摆臂、围裙摆动 |
| Run | 2/3 秒 | 1–21 | 躯干约 16° 前倾、大幅反向摆臂、后腿回收，膝盖弯曲最高约 112°，有短暂腾空 |
| Jump | 1.4 秒 | 1–43 | 下蹲蓄力、摆臂蹬地、约 43 cm 垂直抛物线、屈膝腾空、落地缓冲和回正 |

全部按 30 fps 烘焙为可导出的骨骼关键帧，首尾姿势相同。GLB 中前三个动作带 `-loop` 后缀，Godot 导入后名称为 `Idle`、`Walk`、`Run` 并自动循环；`Jump` 为一次性动作，结束后返回当前行走状态。所有动作均无水平根位移；Jump 含 Root 的垂直位移，其余动作 Root 固定。身高含头顶发梢约 1.6 米，原点位于脚底。

## 接口与整合范围

角色制作阶段新增了资源、独立视觉模块、预览和工具；随后已将查理接入现有迷宫控制器。当前 F5 运行主游戏进入迷宫后可用 WASD / 方向键走路、Shift 跑步，停止或撞墙时恢复待机。迷宫内不接物理跳跃。完整操作、改动范围与测试见 `../../../docs/CHARLIE_MAZE_TRYOUT.md`。

角色资源范围：本目录的 `.blend`、六份 GIF、构建报告与说明；`godot/assets/characters/charlie/` 的 GLB、JPEG 贴图及导入设置；`godot/scenes/characters/` 的两个场景；`godot/scripts/characters/` 的两个脚本与 UID；`godot/tests/characters/` 的资源与迷宫集成检查；`tools/charlie/` 的制作与校验脚本。迷宫接入还调整了人物控制器、跟随镜头和操作提示；按用户要求将试玩入口改为直接进入迷宫，并补充使用文档。没有修改地图、主题、依赖或构建配置。工作分支为 `feature/charlie-rig`，按用户要求提交推送，等待团队审阅后合并。

后续外观与动作修订新增了 `tools/charlie/refine_run.py`、`check_refined_glb.mjs` 和 `check_look_refinement.gd`，并在迷宫场景中调整 AgX 色彩、补光与镜头。修正版的正侧面检查通过；新版网页已在内置浏览器进入迷宫并执行走跑操作，控制台无错误或警告。完整文件清单见迷宫试玩说明。

现有 `CharacterBody3D` 已实例化 `charlie_visual.tscn` 替换占位外观，并按碰撞后的实际水平位移驱动动画。视觉模块对外提供：

```gdscript
# 节点 ready 后，每帧把实际水平速度传给视觉模块。
$CharlieVisual.set_locomotion(Vector2(velocity.x, velocity.z).length())

# 或明确切换动作；第二个参数为播放速度倍率。
$CharlieVisual.play_clip(&"Walk", 1.0)

# 展示完整跳跃（含视觉升降）。
$CharlieVisual.play_jump()

# 接入物理跳跃时，由 CharacterBody3D 控制真实高度，避免重复升高。
$CharlieVisual.play_jump(false)
```

新增接口只影响独立视觉模块及预览。`play_jump(use_baked_height: bool = true)` 播放一次，期间 `set_locomotion()` 只记录速度，结束后恢复对应动作并发出 `jump_finished` 信号。`play_jump(false)` 使用运行时复制生成的 `JumpInPlace`，将 Root 升降清零；每个角色的动画资源独立，不修改原 GLB。

Jump 的蓄力为 0–0.30 秒，腾空为 0.30–0.90 秒，落地缓冲和回正为 0.90–1.40 秒。地面阶段用离线双骨骼求解固定脚踝，再烘焙为 FK；腾空 Root 最高 0.43 米。Godot 默认曲线优化后实测顶点采样峰值略低，约 0.425 米。物理接入时须按这组时序启动跳跃和落地，否则仍可能出现脚步滑动或时序不符；当前没有修改迷宫控制器的移动、碰撞或跳跃规则。

`set_locomotion()` 在速度低于 0.05 时选择 Idle，低于 2.0 时选择 Walk，其余选择 Run，并平滑切换。当前迷宫走路 1.6 米/秒、跑步 2.7 米/秒；视觉模块的动画参考速度仍是 WALK_SPEED=1.2、RUN_SPEED=2.7，因此走路动画按约 1.33 倍播放，避免只加快位移而不加快步频。仍需按实际步幅继续润色，减少滑步。

视觉模块与 GLB 都朝 **Godot -Z**。Blender 工作文件朝 **-Y**；导出时脚本额外旋转场景根节点 180°，抵消坐标转换后的方向差异。直接在 Blender 使用默认导出菜单会失去这一步，应核对朝向。

## 验证与已知限制

已检查：四段动画在 Godot 4.7.2 可导入、可播放；前三段循环，Jump 单次播放；骨骼数量与时长正确；腿部姿势发生变化；Root 没有水平位移；视觉模块速度切换与预览场景可用。已用本机 Compatibility 渲染实际截图检查材质、朝向和动作。Blender 中逐帧检查循环首尾和脚底高度，数值穿地误差仅为浮点误差量级。原项目的检查也已运行，结果见本次交付说明。

验证结果：`CHARLIE_CHECK: PASS (0 failures)`；原项目 `GODOT CHECK: PASS`，包含地图、剧情、标记、碰撞、路线显示、镜头和场景生命周期。角色制作阶段的采样记录为：四段动画首尾顶点误差均为 0，最低脚底高度大于 -0.00000005 米。迷宫接入后，`CHARLIE MAZE CHECK: PASS`，真实控制器自动走完原始 A/B 路线 60/92 步；带画面短流程与截图检查通过，Web release 已重新导出。目标浏览器的新版角色仍待单独验收。角色资源检查还涵盖跑步膝盖弯曲超过 100°、Jump 单次播放、升降轨迹、跳跃期间行走状态保护、结束后恢复行走，以及去除重复升降的 JumpInPlace。

这是一版可试玩的基础动画，不包含表情、手指动作、运行时 IK 脚部锁定、真实布料模拟或自动重定向配置。程序制作的步态仍可能滑步；地面高度修正保证采样帧不穿地，不等同于在楼梯、斜坡或跨动作混合时自动贴地。跑步幅度加大后，围裙使用更大的前后摆动以让开膝盖，局部仍可能穿插。源网格为 Tripo 生成表面，缺少规范关节面流，极端抬臂、屈膝和近景仍可能出现压缩或穿插。

进入正式关卡前，需从迷宫的实际镜头检查腋下、手腕、膝盖、围裙与裤腿；测试 Idle/Walk/Run 混合、转向与 Jump 的起跳落地时序；校准移动速度、碰撞胶囊和脚底落点；在目标浏览器检查性能。若需要电影级近景或大幅度动作，应再做关节重拓扑、手工权重和专门的动画润色。

## 复现

修订跑步手臂时，使用下面的增补脚本，不要重新运行完整建模流程：

```powershell
& 'D:/SteamLibrary/steamapps/common/Blender/blender.exe' --background --factory-startup --disable-autoexec 'art/characters/charlie/charlie_rigged.blend' --python 'tools/charlie/refine_run.py'
node tools/charlie/check_refined_glb.mjs
```

脚本写出 `charlie_refined.blend`、`charlie_refined.glb` 和差异报告，不改原版。只重新写入 Run 的六根手臂骨骼旋转关键帧；导出矩阵分解可能让相关手臂的平移/缩放产生极小浮点差异，校验容差为 0.000002，网格和纹理要求字节一致。原版 Run 的上臂摆动约 43°、前臂屈肘约 61–91°；修正版摆动约 28°、屈肘约 46–64°，并补偿 A 字休息姿势，让手臂靠近躯干。

在仓库根目录运行，替换本机 Blender 和输入文件路径：

```powershell
& 'D:/SteamLibrary/steamapps/common/Blender/blender.exe' --background --disable-autoexec 'C:/Users/30968/Desktop/Untitled.blend' --python 'tools/charlie/build_charlie.py'
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --editor --import --quit
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --script res://tests/characters/check_charlie.gd
```

构建脚本专门适配本次单网格、无骨骼的原始输入；再次运行会重新生成本模块的 Blender 与 GLB 成品，不能用来保留成品文件中的手工修改。重新导出手工编辑后的文件时，应保留线性蒙皮、最多 4 权重、30 fps、Actions、采样、动画起点归零，以及导出场景的方向补偿。

Godot 格式与循环标记参考：[推荐 glTF/GLB](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)、[动画 loop 后缀](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html)。

生成新版正侧面预览：用 Blender 加载成品 `.blend`，执行 `tools/charlie/render_motion_previews.py`，PNG 写入被忽略的 `.verification/charlie/motion_v2_frames/`。
