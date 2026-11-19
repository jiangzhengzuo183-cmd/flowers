# 三迷宫统一体力系统交付（2026-11-17）

正式工程：D:/ChatGPT/献给阿尔吉侬的花束/godot/project.godot。
本轮功能已接入正式 Maze01、Maze02、Maze03；未更改场景美术、地图路线、普通碰撞、分辨率和全屏设置。按最后补充，画面左上使用简洁的体力读条，详细调试文字默认隐藏。

## 1. 工程检查与兼容方式

- Maze01：scenes/levels/maze_01_greybox.tscn，当前是成品运行入口，名称虽保留 greybox，包含正式美术和现有道具。
- Maze02：scenes/levels/Maze02.tscn。
- Maze03：scenes/levels/Maze03.tscn，使用 modules/maze03_final 下的正式实现。
- 三者的玩家分别经 greybox_player、maze02_player、maze03_final/player，最终都继承 scripts/maze/walk_player.gd；本轮只在这个共同父控制器接入一个 StaminaSystem，不复制三套体力逻辑。
- 修改前没有体力消耗/恢复逻辑。步行 1.6 米/秒、冲刺 2.7 米/秒，以及跳跃、动画、碰撞和镜头算法保留。
- 蛋糕现有机制是自动拾取后立即获得加速，并非存入背包主动使用。本轮保留该设计，只在同一拾取回调调用统一恢复接口。没有另造背包。
- 机关屏障现有感应范围进入时的加速和蓝色反馈保留；新增恢复与其分开判断，要求实际从能量面一侧穿到另一侧。

开始前保存了当前 Git 状态和 314 份源码/配置备份：backups/stamina-before-20261117。已有未提交内容没有丢弃。当前分支 codex/maze02-isolation；本轮没有提交、推送或 Web 导出。

## 2. 体力规则与参数

统一可调资源：modules/stamina/default_stamina.tres。在 Godot 文件系统选中该资源即可在 Inspector 调整。三个玩家继承的 stamina_settings 也可指定独立资源；默认共用同一套参数，当前体力存储在各自玩家实例中。

| 参数 | 当前值 |
|---|---:|
| 最大体力 maximum | 100 |
| 冲刺消耗 sprint_cost_per_second | 18 / 秒 |
| 普通自动恢复 recovery_per_second | 14 / 秒 |
| 停止冲刺后的延迟 recovery_delay | 0.9 秒 |
| 耗尽后的重新冲刺门槛 exhausted_restart | 20 |
| 特殊区域恢复 zone_recovery_per_second | 35 / 秒 |
| 特殊区域恢复延迟 zone_recovery_delay | 0.15 秒 |
| 蛋糕恢复 cake_restore | 45 |
| 每扇屏障恢复 barrier_restore | 30 |

普通步行不扣体力；只有实际位移的冲刺才扣体力。按住 Shift 顶墙、原地不动不扣体力。耗尽后降回步行，恢复至 20 才可重新冲刺，避免按住 Shift 时在零点附近反复抖动切换。若一直按住 Shift，达到门槛后会自然恢复冲刺。

区域内正常走动或停留都可快速恢复；冲刺仍按正常规则消耗，不一边冲刺一边无限补体力。重叠区域不叠加恢复速度。全图查看/控制关闭时暂停体力计算。重置角色或关卡会回满并清除本次统计。

公共接口：
- player.stamina.restore(amount, source)：统一外部恢复，返回实际恢复量。
- player.stamina.percentage()：0～1 的体力比例。
- player.stamina.debug_state()：数值、冲刺、恢复、耗尽、区域、恢复来源和统计。
- changed / restored / exhausted / session_reset 信号，供后续正式 UI 和机制复用。

画面体力条会平滑变化；低体力变为柔和暖色，恢复中略偏绿色。悬停可看详细状态；运行时 Remote Inspector 中 StaminaDebugReadout 的 show_details 可以打开详细文本。没有接入正式闪电、指南针或贴纸 HUD。

## 3. 三张标注图与蛋糕移动

坐标单位为米，X 向东，Z 向南；以下为道具地面锚点，悬浮模型仍沿用原视觉脚本。

| 标注图 | 关卡/实例 | 原位置 (X,Y,Z) | 新位置 (X,Y,Z) |
|---|---|---|---|
| 图 1 | Maze01 东侧蛋糕 | (37.2, 0, 25.2) | (42.0, 0, 30.0) |
| 图 2 | Maze02 西北蛋糕 | (1.2, 0, 8.4) | (8.4, 0.9, 13.2) |
| 图 3 | Maze02 东南蛋糕 | (34.8, 0, 42.0) | (44.4, 0, 25.2) |

Maze01 另一枚蛋糕 (13.2,0,8.4) 保留。两关仍各两枚蛋糕。西北新点在抬高回廊上，所以同步使用 0.9 米高度；实际地面射线、导航连通和自动拾取均已验证。没有移动钱币、马蹄铁、兔脚、面粉、胶囊、电视或其他道具，没有修改模型和材质。

蛋糕拾取时恢复 45 体力，同时保留原来 1.3 倍、8 秒加速和黄色线条拖尾。重复拾取仍只刷新加速时间，不叠加速度。拾取对象原有 claimed 保护保留，恢复也只发生一次。

## 4. 教堂与雕像院子

Maze01、Maze02 各增加两个只感应、不阻挡的 Area3D：
- World/ChapelStaminaRecovery：中心 (24,1,22.8)，圆柱半径 2.8、高 2.6；按现有教堂可用半径扣除角色半径设置，覆盖室内主要活动空间。
- World/StatueCourtStaminaRecovery：中心 (22.8,1,15.6)，6×2.6×6 的感应盒，覆盖雕像院子主要停留范围，邻近普通走廊不恢复。

进入区域后调用同一个 StaminaSystem 的区域登记，离开取消登记。未新增复杂特效和实体碰撞。Maze03 不安装这两个恢复区，也没有提前开发中央圣堂的新能力。

## 5. Maze03 六处屏障

每扇屏障使用独立的一次性恢复标记。进入感应区但未越过能量面、或者进去后从同一侧退出，均不会恢复体力。实际越过中心面才调用 restore(..., barrier)。往返同一屏障不会再次补体力，但原有可重复加速保持。

每扇屏障每次挑战恢复一次，满体力穿过也会消耗本次机会。回到入口/重置挑战清除六扇屏障的标记。默认每次 +30；屏障节点 Inspector 的 stamina_restore_override 为 -1 时跟随统一配置，设置非负值则只覆盖该屏障。

未修改屏障材质、位置、门框、粒子、残影或其他视觉参数；没有恢复旧实体门板、道具依赖或解锁逻辑。

屏障加速补充：增益期间统一使用冲刺基速 × boost_multiplier，默认 2.7 × 1.35 = 3.645 米/秒，不再区分按没按 Shift。期间两种输入都不消耗体力，耗尽状态也能获得完整屏障增益；普通恢复仍遵循既有延迟。结束后按当前 Shift 与体力状态恢复正常走/跑。测时记录的 sprint_seconds 统计需要消耗体力的主动冲刺，不把免费屏障加速算入其中。

## 6. Maze03 路线计时准备

现有下方开发工具栏新增“路线测时（开发）”，含 A/B × 三种模式：步行、合理冲刺、尽量持续冲刺。

测试步骤：
1. 打开 Maze03，选择路线与模式。工具会回到入口、回满体力、重置屏障恢复机会，并显示所选参考线。
2. 等待本身不计时。查理在入口感应区内首次真实移动时开始计时。
3. 按选择的条件亲自游玩；模式只是记录条件，不替玩家驾驶。步行模式如果发生冲刺，该记录的 mode_valid 会标为 false。
4. 进入出口感应区后停止记录，只写一次。该出口只是测量终点，不新增胜负判定、剧情或竞速系统。
5. 再选一次菜单即可重复；回到入口或重置会取消尚未完成的测量。开发全图查看期间暂停计时，正式对比时应全程保持游玩视角。

起点中心 (1.2,0.8,44.4)，终点中心 (44.4,0.8,1.2)，都是 1.9×2.2×1.9 的只感应 Area3D。计时按物理帧累计，默认 60 Hz；没有显示倒计时或竞速 HUD。

结果追加写入 user://stamina_tests/maze03.csv。当前电脑对应 C:/Users/30968/AppData/Roaming/Godot/app_userdata/献给阿尔吉侬的花束/stamina_tests/maze03.csv；首次正式完成测试后生成。可在 Godot“项目 → 打开用户数据文件夹”找到。

记录字段：UTC 时间、路线、模式、总秒数、剩余体力、实际冲刺总时长、耗尽次数、屏障恢复次数、是否经过教堂/院子、模式是否有效。恢复次数大于零即可判断触发过屏障恢复。Maze03 当前不适用教堂/院子快回，两个字段为 false。

自动测试的入口/出口短距离触发样本单独写入 .verification/stamina/route_smoke.csv，不能当作整条路线用时。此次没有决定最终竞速时间。

## 7. 文件及节点清单

新增资源（另有 Godot 自动生成的脚本 UID）：
- modules/stamina/stamina_settings.gd、default_stamina.tres：统一平衡参数。
- modules/stamina/stamina_system.gd：共用数值与接口。
- modules/stamina/recovery_zone.gd：只感应恢复区域。
- modules/stamina/runtime.gd：按关卡安装恢复区、读条与开发测时工具。
- modules/stamina/debug_readout.gd：简洁体力条，详细调试可选。
- modules/stamina/route_timing.gd：开发测量与 CSV 记录。
- tests/stamina/check_stamina.gd：边界及三关实际运行验证。
- modules/stamina/DELIVERY.md：本说明。

修改已有文件：
- scripts/maze/walk_player.gd：实例化 StaminaSystem，统一冲刺资格/消耗/恢复和重置。
- scripts/levels/greybox_scene.gd：Maze01/02 恢复区与读条接入。
- modules/maze_pickups/maze01_perks.gd：Maze01 一处蛋糕新位置、蛋糕恢复接口。
- modules/maze02_items/placements.gd：Maze02 两处蛋糕新位置和地面高度。
- modules/maze03_final/barrier.gd：实际穿越、一次性恢复与重置。
- modules/maze03_final/scene.gd：Maze03 读条、开发测量接入。
- modules/maze03_final/check_final.gd：跑步脚印验证前先补足体力，并确认真的处于冲刺；原测试默认角色可无限跑，该前提现已改变。

动态新增节点：每个 Player/StaminaSystem、ViewportContainer/StaminaDebugReadout（含 StaminaBar）；Maze01/02 各两个恢复 Area；Maze03 的 RouteTimingTest、TimingStart、TimingFinish 和一个开发测时菜单。未删除文件，三个 .tscn、地图 JSON、模型、贴图、灯光、天空、全屏与项目设置均保持原样。

## 8. 验证结果

- tests/stamina/check_stamina.gd：三关真实输入、移动和碰撞检查通过；数值上限/下限、恢复延迟、耗尽重启门槛、普通步行、顶墙、暂停、区域重叠、离开恢复区、实际蛋糕拾取、六屏障及重复往返、场景重置、测量记录均覆盖。
- 原生 Compatibility 游戏窗口：三关体力条、教堂/院子恢复、蛋糕与屏障画面检查；无新增脚本错误。
- 原 Maze01 marked_pickups 测试：PASS，兔脚、钥匙、原加速和面粉等未破坏。
- 原 Maze02 marked_items 测试：0 failures。
- Maze03 check_final --routes：PASS，272/336 原始普通墙体，A/B 完整路线、步石、加速屏障、水中反馈和脚印正常。
- 截图：.verification/stamina/before_maze01.png、before_maze02.png；after_maze1_top.png、after_maze2_top.png、after_maze3_top.png；maze1_chapel_recovery.png、maze2_chapel_recovery.png、maze1_court_recovery.png、maze2_court_recovery.png、maze3_barrier_restore.png。

三处未拾取蛋糕局部图：.verification/stamina/cake_maze01_2.png、cake_maze02_1.png、cake_maze02_2.png；含全部道具的调整后全图为 placement_maze01.png、placement_maze02.png。

## 9. 已知限制与下一步

体力数值是首轮可调参数，下一步应按六组条件亲自完整测量、多次取样后再定竞速节奏。用户要求的阿尔吉侬、圣堂能力、最终 HUD 与全屏成品整合均未开发。

本轮没有重新导出 Web；此处验证的是正式 Godot 工程。批量关闭原生 Maze02 测试时仍可见修改前就存在的两条约 87 KB 纹理释放提示；修改前 baseline.log 已记录同类提示。本轮未扩大范围改动其电视或渲染资源。自动功能测试通过，不把该已有退出提示宣称为已修复。
