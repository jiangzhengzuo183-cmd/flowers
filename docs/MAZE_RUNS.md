# Maze 01 三次运行基础框架

当前仅完成共同基础、三份配置、独立试玩入口和机关/完成条件接口。三次空间结构、人物、默认灯光与机关规则保持一致。没有制作三套迷宫，也没有实现正式道具、幽影、倒计时或竞速。

## 打开

在原 Godot 工程的文件系统中打开 `res://scenes/maze_runs/maze_runs_preview.tscn`，点击“运行当前场景”（Windows F6）。上方可选择第一次、第二次、第三次或重试；通关后可点“下一次”。这些按钮属于制作检查入口。F5 仍进入原灰模试玩，主入口未更改。

Windows 也可直接双击仓库根目录 `试玩三次迷宫.cmd`。脚本使用原有便携 Godot 或 PATH 中的 godot.exe；不安装依赖。

## 唯一结构来源

```text
maze_runs_preview.tscn → maze_run_controller.gd
  └─ 同一个 Maze01_Base.tscn ＋ run_01 / run_02 / run_03.tres
       └─ 继承原 maze_01_greybox.tscn
            └─ 原 maze.tscn ＋ 原生成脚本及 maze_01_greybox.json
```

空间只由现有 `godot/data/maze_01.json`、`godot/data/levels/maze_01_greybox.json` 和 `godot/scripts/levels/` 中的生成构件控制。不得在三份运行配置中添加单独墙体、桥梁或地形副本。修改共同空间后，重新进入任意一次运行即可同步使用新结构。当前正在运行的实例不会热更新。

## 配置

`godot/data/maze_runs/run_01.tres`、`run_02.tres`、`run_03.tres` 是可在检查器中编辑的资源。脚本为 `godot/scripts/maze_runs/maze_run_config.gd`。

- `initial_gate_states`：D1–D4 初始是否开启；未指定默认关闭。
- `gate_interaction_enabled`：对应机关是否允许操作；未指定默认允许。
- `required_exit_gates`：到出口所需已开启的门。默认 D1/D3/D4，与原试玩一致。
- `environment_override`：可选独立环境资源；运行时复制，不写回共享资源。
- `sun_energy` / `fill_energy`：默认 0.65 / 0.45，保持现有灯光。
- `show_debug_tools`：显示参考线按钮与检查传送下拉。当前入口本身仍是制作工具，不是正式发布界面。
- `item_rules` / `shadow_rules` / `countdown_rules` / `race_rules`：后续机制预留字典，目前必须为空。填入规则会明确报错，不会假装相关功能已经实现。

配置仅供读取。基础场景在进入时保存独立快照；已运行后修改资源不会改变本轮。运行中不要写入 Layout.config() 的静态缓存；缓存只保存所有运行相同的空间参数/计算结果。

## 模块接口与影响范围

仅对原 `greybox_scene.gd` 增加小型扩展点，默认行为保持：

- `try_activate_gate(id) -> bool`：操作规则接口。按 E 时仍先检查距离和视线；此方法供可信运行控制使用，本身不代替空间检测。
- `can_finish() -> bool`：出口规则，原版仍要求 D1/D3/D4。
- `_on_exit_body_entered(body)` / `complete_level()`：出口和完成扩展点。

`greybox_gate.gd` 增加 `set_open_state(open)`：立即设置门位置和碰撞，无开门音、动画或 opened 事件；reset_gate 复用此接口。正常 E 开门动画不变。

`maze01_base.gd` 继承现有灰模脚本，增加：

- 进入场景前设置 `run_config`；场景 ready 后应用初态，不重复生成地图。
- `reset_level()`：回入口、清除完成标记、恢复本轮初始门和开关状态。
- `get_run_state()`：返回独立的运行编号、门、开关、完成状态快照。
- `run_completed(run_id,result)`：每次通关仅一次；`run_reset(run_id)`、`gate_activated(run_id,gate_id)`。
- 门初态、交互许可和出口条件不再固定在基础场景中；门位置、桥上桥下连接与实际碰撞不变。

`maze_run_controller.gd` 提供 `start_run(index)`（0–2）、`retry_run()`、`next_run()` 和 `run_finished(run_id,result)`。切换时先立即移出旧实例，再新建相同基础场景，避免旧输入、门动画和信号继续作用。保存的通关结果是副本；重试相应轮次会清除该轮旧结果。

当前支持逐次运行。隔离检查可同时加载多个场景，但正式输入仍只应交给一个活动场景；没有实现分屏或多玩家。

重置或退出当前轮次时，主动停止并释放尚未播放完的开门声音，避免声音跨轮延续。

## 检查

在仓库根目录运行，godot 替换为本机引擎路径：

```text
godot --headless --path godot --editor --import --quit
godot --headless --path godot --fixed-fps 60 --script res://tests/maze_runs/check_maze_runs.gd
godot --headless --path godot --fixed-fps 60 --script res://tests/levels/check_maze_01_greybox.gd
godot --headless --path godot --fixed-fps 60 --script res://tests/check_project.gd
```

新增检查验证三轮使用同一个基础场景、网格/碰撞结构相同、切换/重试无状态遗留、环境和动画独立、门初态无动画/声音、重置途中动画不会重新禁用碰撞、真实出口触发及下一轮流程。原有完整通行检查继续覆盖 A/B 路线、坡道桥梁和镜头。

## 后续边界

本轮未增加道具锚点或三次具体机制，未改变主入口、项目配置、全局主题或素材。后续先设计道具与机关条件，再逐项接入计时、幽影与竞速。竞速必须保留现有桥上桥下分层，不能直接把 A/B 参考线当成完整 AI 导航。

## 本轮实际验证（2026-11-04）

- 独立功能分支工作目录：基于已交付 fa34f31 的 codex/maze-three-runs；模块已同步到原工程，本轮完成跳跃检查后提交并推送此分支。
- 资源导入、三轮框架检查、原项目入口检查通过；旧灰模完整通行检查 A 60/60、B 92/92，0 失败。
- 三轮检查覆盖共同结构、独立门/环境/动画、配置快照、实际出口区域检测、完成事件、重试及切换。
- 本机 NVIDIA / Compatibility 原生三轮检查通过，并查看真实截图确认三轮按钮、人物和场景显示正常。截图为检查产物，不进入源码。
- 原工程同步时备份两个扩展脚本，并核对 131 个其他受保护文件未改变。未删除任何现有场景或资源。
- 未导出或验证新版 Web，也未制作三轮正式机制与最终界面。

## 跳跃接入（2026-11-04）

空格起跳；WASD 保持空中方向控制，Shift 可边跑边跳。仅落地后可再次起跳，按住不会连跳，空中按键不会排队到落地自动再跳。全图查看和 UI 消费的空格不触发跳跃。

物理仍由原 CharacterBody3D 控制，向上初速度 3.9m/s、重力 18m/s²，离地高度约 0.4m。保留原 1.6m 胶囊、坡道贴地和全部地图碰撞。复用原 GLB 的 Jump，运行时 JumpInPlace 去除 Root 升降；根据真实上升/下降采样 0.30–0.90 秒腾空姿势，落地恢复实际 Walk/Run/Idle，避免人物与碰撞重复抬升。回入口、重置机关、切换轮次均清除跳跃状态。

新增视觉接口 begin_physics_jump / update_physics_jump / end_physics_jump / cancel_jump，仅供人物控制器调用；原预览的 play_jump 接口和原动画资源保留。没有修改输入映射、工程配置、模型、贴图或地图。

验证命令：godot --headless --path godot --fixed-fps 60 --script res://tests/maze_runs/check_maze_jump.gd
专项覆盖原地/步行/跑步跳跃、长按与二段跳防护、真实落地、斜坡桥面与桥下、下沉地面、关门和墙体阻挡、头顶碰撞、中途重置及三轮切换。-- --capture 可用原生渲染保存腾空截图到被忽略的 .verification 目录。

本轮跳跃交付检查：check_maze_jump（空格、跑跳、落地、禁二段跳/长按连跳、坡道桥梁、门墙和顶头、中途重置及三轮）通过；check_maze_runs、check_charlie、check_project 与旧灰模完整 A/B 通行检查均通过，A 60/60、B 92/92，0 失败。NVIDIA Compatibility 原生跳跃检查通过，已查看 jump_apex.png。原工程同步前备份，核对 137 个其他受保护文件未改。Web 未重新导出。
