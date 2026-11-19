# 三关冲刺开关与 Maze03 难度补充（2026-11-18）

正式工程仍为 D:/ChatGPT/献给阿尔吉侬的花束/godot/project.godot。

## 完成内容

1. 北侧墙体：根据用户确认的水池北侧与截图，延长原有 VerticalWalls/WallSegment_V_4_12（X=28.8），从原来约 Z=9.45–12.15 延至 Z=14.34，与池沿北侧外表面 Z=14.32 接合。没有另堆连接块或改变其他墙。修复该墙原网格终点被误当成实际端点的裁切，保持白色墙面连贯，实体碰撞与可见墙面一致。实际查理尝试横穿原缺口已被截断；2231 段参考路线检查确认新增墙体没有侵入 A/B 路线所需角色半径。

2. 竞速：正式资源和默认参数均改为 58.0 秒。沿用开局冲刺、四次屏障加速、两次 0.8 秒犹豫以及中途隐藏/终点再现，重新按实际路线校准。完整运行实测 58.000002 秒。圣堂的时间凝滞仍会真实延迟老鼠，不强制追回 58 秒；完整使用实测约 63.68 秒。

3. 老鼠轮廓：圣堂透视直接复用原药丸轮廓 Shader，为阿尔吉侬增加一个实时蒙皮提示副本，与真实老鼠世界位置和骨骼同步。即使老鼠的普通模型处于中途隐藏状态，透视提示层仍显示它的蓝色轮廓。仅在透视合成中显示，不将普通模型强制解隐藏；效果结束恢复原本的隐藏规则。没有加定位球、箭头或额外线框。立方体仍无额外高亮。视野外的对象需转动镜头或使用现有俯视查看，提示位于真实场景位置。

4. Maze01、Maze02、Maze03 共用冲刺开关：按一次 Shift 开启，再按一次关闭，松开不会关闭。忽略键盘重复事件，按住不会来回切换；重新开始清空开关。停止移动不耗体力，体力耗尽退回步行，开关保留，恢复至既有阈值后可继续冲刺。屏障的免费跑步增益仍按原规则生效，不叠加，结束后恢复当前选择的步行/冲刺状态。跳跃、移动方向、镜头和所有道具倍率保留。

操作说明已同步为“Shift 开/关冲刺”，未新增最终 HUD。

## 修改文件

- scripts/maze/walk_player.gd：共用冲刺状态及 Shift 按键边沿处理。
- scripts/maze/maze_scene.gd、scripts/levels/greybox_scene.gd、scripts/levels/maze01_key_scene.gd、modules/maze03_final/scene.gd：只更新操作提示文字。
- modules/maze03_race/settings.gd、default_settings.tres：58 秒目标及 Inspector 范围。
- modules/maze03_final/generator.gd、wall_joints.gd：仅北侧指定墙体的延伸和接缝处理。
- modules/maze03_sanctuary/vision_adapter.gd、interaction.gd：复用同款轮廓并接入老鼠。
- tests/levels/check_maze_01_greybox.gd：测试移动通过真实 Shift 轻按切换所需冲刺状态。
- tests/stamina/check_stamina.gd、check_barrier_free_sprint.gd：适配新输入方式，基础速度跑道避开自动屏障增益。
- tests/maze03_sanctuary/check_sanctuary.gd：凝滞抵达时间随配置计算，不固定旧的 65.7 秒。
- 新增 tests/maze03_tightening/check_changes.gd 与 Godot 对应 .uid：三关真实按键、墙体、58 秒及老鼠轮廓验收。

没有修改 Maze01/Maze02 建筑、路线、碰撞、美术、道具效果、天空、全屏、原药丸 Shader 或原始模型。本轮 shared player 的输入改动仅为用户要求的三关共同冲刺方式。

## 验证

- 原生 Godot Compatibility / RTX 4060 Laptop：三关 Shift 轻按开关、松开保持、键盘重复、站立不消耗、体力耗尽、重开、跳跃与屏障兼容均通过，0 失败。
- 原生真实完整老鼠路线：58.000002 秒，四次加速、两次犹豫保留。
- 北侧三处射线和实际查理横穿测试：模型与碰撞匹配，缺口封住。
- 对新增墙体做两条现有参考路径与角色半径净空检查：2231 段通过。此检查针对新增墙体；水上步石的可行走性仍沿用实际角色物理，不用会误判脚下小缝的直线下沉扫掠代替。
- 圣堂原整合测试：6 秒上限、离开后 3 秒、反复进出不续时、单场一次、输入与音频清理，PASS，0 失败；完整凝滞老鼠约 63.684 秒抵达。
- 三关 stamina 整合测试：PASS，0 失败。
- 屏障免体力跑步专项回归：PASS，0 失败。

截图和日志：D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-tightening/。
- north_wall_after.png：北侧连接后的实际画面。
- global_vision_mouse.png：透视中查理与老鼠的全局真实位置。
- mouse_outline_close.png：验收镜头下隐藏老鼠的实时轮廓。
- native.log、stamina.log、sanctuary.log、free_boost.log、routes.log。

原生多关测试退出时仍有此前已存在的 Maze02 两张纹理释放提示；本轮功能测试无脚本错误。Web 未重新导出，未提交或推送 Git。

开发前检查点 backups/maze03-before-tightening-20261118/；本轮源文件差异见 .verification/maze03-tightening/isolation.json，没有缺失文件。
