# Maze03 中央圣堂交互交付

> 2026-11-18 最新更新：竞速目标为 58 秒，圣堂透视会显示老鼠轮廓，三关 Shift 改为按一下开、再按关闭。北侧墙体连接与当前测试结果见 [最新交付](../maze03_race/TIGHTENING_DELIVERY.md)。下文保留此前验收记录。


正式工程：D:/ChatGPT/献给阿尔吉侬的花束/godot/project.godot。

## 如何使用

进入 Maze03，工具栏选择比赛模式。GO 后进入中央圣堂，靠近已有悬浮立方体（水平距离 1.35 米内），屏幕底部显示“E  激活圣堂”。站在地面上主动按 E 后触发；不靠近、不按 E、跳跃/庆祝、倒数、全图查看或比赛结束时不能激活。

根据补充要求，立方体不增加透视轮廓或额外高亮，保留原有模型、材质、悬浮旋转和 E 提示。建筑、路线、碰撞及摄像机没有修改。

## 全局透视复用

直接继承已有 modules/maze02_items/vision.gd，通过适配器调用它的 install / activate / clear / _process 接口。原药丸模块和资源未修改，也没有复制一套透视 Shader。

复用资源：
- vision_screen.gdshader：原有画面压暗、蓝色边缘光、轮廓合成、聚焦过渡。
- vision_motes.gdshader：原有路线光点，非线框或导航经纬网。
- vision_pickup.gdshader：原有红色遮罩，交由原合成器转换为蓝色轮廓。
- focus_audio.gd 及 focus_gather.wav / focus_hold.wav：原有聚焦声音、环境压低和恢复。
- 原有 0.78 秒渐入、0.72 秒渐出、路线与门洞/出口绘制方法。

渲染仍是原方案：游戏画面上的 ColorRect + 独立透明 SubViewport，不另建全屏后期系统。屏幕合成层位于现有体力条与比赛计时器下方，不遮住必要 HUD，也不截获移动和摄像机输入。

全局高亮来自现有 A/支路与 B 路线的实际地面采样（2232 个采样点，0 处缺少地面），不是玩家附近的小圆圈。药丸原有路线光点约 3140 个实例，完整覆盖两条关键路线、六道能量屏障和出口。不新增假道具；Maze03 当前没有拾取道具，立方体依补充要求排除高亮。未增加建筑网格、经纬线、建筑线框或新的光效风格。

查理使用原网格与蒙皮的一个独立轮廓副本，实时同步骨骼、姿态、世界坐标，绘制到原药丸的提示世界。仅用于蓝色轮廓合成，不改变查理主模型材质或控制器。实际游玩与全局俯视都保留正确位置的查理轮廓；不揭示已隐藏的老鼠。

## 时间凝滞与竞速

Race 管理器持有 sanctuary_used 与 sanctuary_active。成功交互立即原子化领取本场唯一机会，再启动效果及体力恢复。结束效果、离开/重进圣堂、反复按 E、玩家重新定位都不会重置 used；只有调用现有“回到入口”重开整场，或正式重开到另一个模式才重新初始化。

凝滞默认 0.05 倍，只作用于老鼠自己的 runner_clock 和动画倍率，不使用 Engine.time_scale。跑步动画的原有最低播放速度已改成先计算正常步频、再乘独立时间倍率，避免慢动作时腿仍在快跑。转身动画与方向变化也随老鼠时间减缓。外部已有速度倍率继续组合，结束后恢复之前倍率。

查理移动、转向、跳跃、体力、屏障加速与输入均不减速。正向竞速计时继续按原来的真实秒数增长。使用圣堂不会重新校准老鼠来追回损失的时间：不激活仍约 60.00 秒抵达；完整使用本轮凝滞实测约 65.68 秒抵达。

老鼠先到仍不结束比赛，查理继续到终点才结算。但老鼠已经抵达后不能再开始一次新的圣堂激活；比赛实际结束时会清理尚未结束的效果，恢复倍率。

## 持续时间与体力

同一个物理时钟控制持续时间和离开期限：
- 自激活起最长 6 秒，包含渐出时间。
- 第一次离开实际圣堂内部边界时记录离开时间，期限取“激活后 6 秒”和“首次离开后 3 秒”较早值。
- 反复进出不重置离开记录，也不延长截止时间。
- 原药丸渐出在期限前最后 0.72 秒完成；结束时释放透视与老鼠减速。

成功激活调用既有 actor.stamina.restore(maximum, sanctuary)，一次恢复至最大体力，统一接口负责上限与 HUD 更新。没有第二套体力系统，也不占用蓝色屏障的单次恢复次数。

探索模式没有新增圣堂激活或竞速凝滞，原有探索体验保留。药丸渲染与音频只在成功激活时创建；重开、切回探索、退出场景时清理，环境音量与音频总线恢复。

## 可调整参数

参数位于 modules/maze03_race/settings.gd，通过现有 default_settings.tres 读取，可在 Godot 资源检查器中调整：

| 参数 | 默认 |
|---|---:|
| sanctuary_mouse_speed | 0.05 |
| sanctuary_max_seconds | 6.0 秒，运行时也限制不超过 6 |
| sanctuary_exit_seconds | 3.0 秒 |
| sanctuary_interaction_radius | 1.35 米 |

原有 sanctuary_activated / sanctuary_ended 信号已接通，分别在成功领取和效果结束时发出。新增有效速度查询与一次使用接口位于 Race 管理器，交互范围和允许动作由独立交互节点检查。

## 文件清单

新增：
- godot/modules/maze03_sanctuary/interaction.gd：E 交互、非阻挡 Area、提示、期限、体力恢复和透视生命周期。
- godot/modules/maze03_sanctuary/vision_adapter.gd：复用原药丸，并由圣堂时钟控制期限。
- godot/modules/maze03_sanctuary/character_cue.gd：查理实际骨骼姿态的提示层副本。
- godot/modules/maze03_sanctuary/DELIVERY.md：本说明。
- godot/tests/maze03_sanctuary/check_sanctuary.gd：完整整合验收。
- Godot 自动生成的对应 .uid。

修改已有文件：
- godot/modules/maze03_race/controller.gd：圣堂的全场单次状态、独立时间倍率与重开/结束清理。
- godot/modules/maze03_race/mouse.gd：动画步频在最终阶段乘以时间倍率。
- godot/modules/maze03_race/settings.gd：上述集中参数。
- godot/project.godot：仅追加此前不存在的 interact 输入动作，绑定物理 E 键；原有设置和未提交改动保留。

没有修改 Maze01/Maze02 场景、药丸源脚本/Shader、玩家移动脚本、体力脚本、屏障源脚本、GLB、建筑材质、天空或全屏设置。未删除文件。

## 测试与结果

实际使用 Godot 4.7.2 Compatibility，RTX 4060 Laptop GPU。测试通过程序输入驱动真实角色与 Area，并实际渲染截图。

| 场景 | 结果 |
|---|---|
| 远离/仅进入建筑/靠近但不按 E | 不触发 |
| 跳跃时按 E | 不触发 |
| 站稳、在范围内按 E | 触发，体力一次恢复 |
| 留在圣堂 | 6.00 秒结束 |
| 第 1.05 秒离开后反复重进 | 总计 4.05 秒结束，离开后 3 秒 |
| 第 5 秒后才离开 | 仍在 6.00 秒结束 |
| 凝滞中查理步行 0.5 秒 | 约 0.8 米，维持 1.6 米/秒 |
| 同期老鼠自身时间 | 约 0.025 秒，5% 流速 |
| 同期比赛计时 | 正常增加 0.5 秒 |
| 不使用凝滞的完整鼠路线 | 60.00 秒 |
| 使用完整凝滞的完整鼠路线 | 65.6842 秒 |
| 效果结束/离开再回来/玩家重新定位 | 不恢复使用机会 |
| 新比赛重开 | 使用机会、音频、视觉和速度全部正确重置 |
| 激活中直接退出场景 | 无残留音频总线，时间倍率正常 |

check_sanctuary.gd：headless 与原生实机均 PASS，0 失败；立方体高亮移除后的最终版本再次实机通过。

已有 check_maze02_items.gd：原 Maze02 药丸七秒效果、音频恢复、道具与 E 机关，0 失败。

已有 check_stamina.gd：Maze01 / Maze02 / Maze03 统一体力及屏障恢复，PASS，0 失败。

已有 check_mouse_boost.gd：未使用圣堂时 60 秒抵达、不同步长校准、开局加速与隐藏再现，PASS，0 失败。

原生截图：
- .verification/maze03-sanctuary/before_activation.png
- .verification/maze03-sanctuary/active_player_view.png（最终版无立方体额外高亮）
- .verification/maze03-sanctuary/active_global_overview.png（全局路线及查理位置）
- .verification/maze03-sanctuary/fading.png

日志和数值：同目录 integration.log / native.log / measurements.json / pill_regression.log / stamina_regression.log / no_activation_race.log / active_exit.log。

开发前备份：backups/maze03-before-sanctuary-20261117/。356 个已有源资源哈希对比仅上述四个旧文件变化，0 缺失。原药丸与 Maze01/Maze02 文件完全一致。

## 性能与范围

沿用现有 Compatibility 可用的透明提示 SubViewport 和一次屏幕合成，额外只有查理单份蒙皮提示网格，不添加实时阴影灯或全局后处理特效。额外渲染只在短暂激活期间开启，清理后提示 SubViewport 停止更新。原生实机通过；未对 Web 重新导出或作浏览器帧率承诺，本轮没有提交或推送 Git。
