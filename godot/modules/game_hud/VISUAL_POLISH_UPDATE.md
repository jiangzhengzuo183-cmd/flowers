# 三迷宫 HUD 视觉与交互提示修订

工程：D:/ChatGPT/献给阿尔吉侬的花束/godot/project.godot。Godot4.7.2，Compatibility。本轮修改仅位于D盘正式工程，未推送或重新导出网页包。修改前备份：backups/hud-object-prompts-20261118。

## 最终显示

- 计时与右上退出/重开图标一起下移16逻辑像素，上沿y=56。数字区域从288×80收至240×64，仍用固定字槽和原PNG比例，时间变化不跳位。
- 章节统一为“第一章”。三个迷宫使用用户指定任务原文：
  - 迷宫一：请尽情探索这个迷宫并尝试找到出口。
  - 迷宫二：迷宫似乎发生了变化，请尝试发现它并熟悉路线。
  - 迷宫三：这是你和阿尔吉侬的终极比拼，全速前进吧！
  - Maze03探索与比赛均采用上述迷宫三任务，未修改其玩法。
- 选中道具的圆槽与内部图案整体平滑放大至1.10倍；其他槽恢复正常。放大以底部中心为支点，格子位置和点击范围不跟随变动，避免抖动或错误点击。
- 获得/使用通知改为屏幕中下方居中，640×56，中心x=960、静止y=892。保留半透明灰色圆角条和原队列、淡入淡出，不再放在左侧。
- 退出/重开仍是米白便利贴；区域580×340，标题32、说明24、按钮文字24。内容垂直居中且下移，按钮横向居中，至少176×56。取消/确认仍执行原逻辑。

## 白边与指南针清理

按用户最后补充，指南针和体力图形保留白边，收细白边；没有采用去白边版本。

原指南针是一张合并PNG。现在分成底盘、指针、黄色圆弧和轴心四个派生图层，清理旧指针残影、外缘碎点；旋转只作用于指针与黄弧，不再跟着转动附近纸底。原纸张、方位字母及装饰保留，用户原始PNG字节不变。

指南针仍为384×352，按实际圆盘主体的上沿定位。白边通过收窄原轮廓保留；闪电保留约2个逻辑像素的白边，黄色填充仍来自真实体力。保留原黄色，不统一染色。

辅助图层按透明边界收紧裁切，避免三张整图纹理的额外占用。compass_regions.gd通过预加载纳入游戏依赖，不依靠网页导出过滤规则包含JSON。tools/split-hud-compass.ps1可复现分层与边缘处理。原PNG保留不覆盖；11张原始PNG与源目录SHA-256复核一致。

## 门和立方体旁的提示

取消固定在屏幕下方的门/圣堂交互提示。继续使用同一个HUD组件，通过当前3D相机投影，将简短提示定位在对应门或立方体旁边，随着物件和镜头更新。

- 门可开启：黄色E键帽＋“开启”。
- 立方体可激活：黄色E键帽＋“激活”。
- 缺钥匙：简短显示需要的道具，不假装可开门。
- 离开交互范围、物件移出视野、暂停或确认界面打开后隐藏。
- E的原交互优先级、道具消耗、圣堂一次机会与效果不变；不修改建筑、碰撞或相机。

## 体力耗尽后的冲刺

三个迷宫共用的walk_player.gd现在监听现有体力耗尽信号，并立即关闭sprint_toggled。体力恢复后仍保持走路，需要再次按Shift才重新冲刺。在耗尽状态按Shift不会预先挂起一个恢复后自动冲刺的请求。

没有改变体力消耗、恢复阈值或速度参数。Maze03屏障免费加速不依赖此切换状态，仍可在耗尽时生效，期间不耗体力。

## 实际验证

原生实际运行三个迷宫，check_object_prompts.gd：112项通过，0失败。覆盖：

- 第一章及三迷宫任务原文、较小的计时数字、计时和菜单下移。
- 数字选格、选中圆槽放大、其他槽复原、点击范围稳定。
- 真实拾取蛋糕后居中通知、道具继续入包等待使用。
- 门/立方体旁的简短提示、随镜头更新、E仍只执行正确交互。
- 便利贴文字与按钮居中、字号/按钮尺寸、真实取消点击。
- 指南针四方向联动、底盘旧指针移除、细白边、半体力填充截图。
- 三迷宫实际跑动耗尽后关闭冲刺，恢复后不自动跑，新Shift按键才恢复冲刺。

原屏障免费加速回归check_barrier_free_sprint.gd：PASS，0失败，包括普通/冲刺输入同速、刷新不叠加、免体力、耗尽时仍能穿屏障加速及结束后恢复原规则。

日志：.verification/unified-hud/object-prompts.log、object-prompts-results.json、free-sprint-regression.log。Maze02进程退出时原有的GL纹理释放警告仍在，本轮未改电视/幽影资源；最终运行检查无新增脚本报错。网页包尚未重新导出，因此现有线上试玩不会自动同步。

## 文件范围

修改：modules/game_hud下GameHUD.tscn、layout_metrics.gd、configuration.gd、digit_timer.gd、assets.gd、compass_widget.gd、compass.gdshader、stamina_fill.gdshader、inventory_widget.gd、interaction_widget.gd、game_hud.gd、runtime.gd；scripts/maze/walk_player.gd仅接入耗尽自动关闭冲刺。

新增：4张compass派生PNG、compass_regions.gd及构建用JSON、tools/split-hud-compass.ps1、tests/game_hud/check_object_prompts.gd。字体子集补齐新任务文案（478字形、162528字节），许可保留。旧HUD检查用例同步新尺寸和通知位置。本轮不改背包三件上限、道具机制、主路线、建筑、竞速时间或圣堂规则。

## 当前实机截图

- [Maze01整体](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze_ui_refined.png)
- [Maze02整体](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze02_ui_refined.png)
- [Maze03整体](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze03_ui_refined.png)
- [道具选中放大](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze_selected_slot.png)
- [门旁E提示](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze_door_attached_prompt.png)
- [立方体旁E提示](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze03_cube_attached_prompt.png)
- [获得通知居中](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze_centered_notice.png)
- [退出便利贴](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/exit_centered_note.png)
- [重开便利贴](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/restart_centered_note.png)

重新运行D盘正式工程查看最新版本；已在运行的旧实例不会自动更新。
