# 三迷宫统一 HUD 交付报告

> 最新界面排版、细白边、物件旁提示及耗尽关闭冲刺，以 [视觉修订说明](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/game_hud/VISUAL_POLISH_UPDATE.md) 为准。

> 2026-11-18后续修订：已按用户最新要求改为整个背包最多三件、动态槽位、蛋糕/药丸入包后按E使用，并重新严格对齐全部HUD。当前行为与最终93项实机检查以 [最新更新说明](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/game_hud/ITEM_STORAGE_UPDATE.md) 为准。下文保留首轮交付记录，涉及即时使用和旧尺寸的描述已被本次修订替代。

正式工程：D:/ChatGPT/献给阿尔吉侬的花束/godot/project.godot。Godot 4.7.2，Compatibility。全部修改位于 D 盘；保留原有未提交内容。修改前备份见 backups/before-unified-hud-20261118。本轮没有提交 Git、推送或重新发布网页试玩包。

## 显示与共享结构

project.godot 统一为 1920×1080、16:9 逻辑画布，启动 Fullscreen（mode=3），canvas_items + keep。窗口备用尺寸1280×720，最小720×405；不改变系统分辨率。非16:9输出保留黑边，不拉伸或裁切。

实际验证1600×1000时有效画面1600×900、上下各50像素；2100×900时有效画面1600×900、左右各250像素。1280×720、1920×1080也保持比例。HUD逻辑尺寸始终1920×1080。原SubViewport、相机FOV、3D建筑及移动规则不变。

三个正式场景只实例化同一个 modules/game_hud/GameHUD.tscn。game_hud.gd负责显示与交互信号；runtime.gd连接已有体力、背包、状态、机关、竞速与圣堂数据。session_clock.gd补齐探索阶段计时；比赛仍读取原race.elapsed，不重复建立比赛计时器。任务文本可在default_configuration.tres及场景的Shared HUD配置中调整。

## 最终界面与交互

| 部分 | 最终表现 |
|---|---|
| 指南针 | 左上380×348，是最大的单个图形组件。黄色指针与黄色圆弧随查理真实朝向一起平滑转动，纸底、方位字母不转；无方向解释文字 |
| 计时器 | 原纯色PNG数字，四个62像素固定宽槽及28像素固定冒号，保持原比例和白边，不随数字跳动；MM:SS |
| 章节与任务 | 计时器下方深褐色手写文字，无背景框、无白描边 |
| 右上菜单 | 仅退出、重开两个原PNG；图像64×64，实际热区76×76。悬停放大至1.08倍，按下0.98倍，移开恢复；无悬停提示框 |
| 体力与背包 | 左右下均360×124，底部距离40；每组3格，统一大小和高度。闪电黄色由左向右连续填充，白色外轮廓保留 |
| 背包图标 | 三个圆形纸槽始终显示。道具等比放在槽内72×86范围，留出白边；保留数量和选择反馈，拾取有轻微弹动，不再隐藏圆槽 |
| 获得与事件通知 | 灰色半透明圆角条540×52，背景Alpha=0.34，圆角16；位于角色中心左侧较高位置，一行图标、名称及短说明，2.8秒后淡出，不堆叠遮住人物 |
| E交互 | 米白圆角提示、黄色E键帽，按真实门/圣堂状态显示开启或激活；缺道具显示需求，不虚报可开启 |
| 退出与重开确认 | 两者均需确认。米白便利贴、顶部小胶带、轻微倾角、黄色确认按钮；取消保持当前进度，确认再执行原动作 |
| 字体与贴纸融合 | 使用圆润稚拙的小赖手写体派生子集；计时数字仍用原PNG。图形白边只做轻微显示柔化及很淡接触影，原图不变，不统一染色 |

指南针原素材为合并PNG；compass.gdshader在显示时分离黄色指针和圆弧，原图不被重绘或覆盖。指向读取查理visual的世界朝向，含平滑过渡；四方向实际渲染检查通过。

手写字体由Xiaolai Regular v3.126子集化并改名Algernon HUD Hand，保留463字形，文件157,784字节；未改变字形轮廓。完整SIL OFL随资源和字体内嵌许可保留，原Source Han Sans为未覆盖字符后备。来源与许可见assets/UI/HUD/fonts/SOURCE.md及OFL.txt。字体构建工具仅开发时使用，不增加游戏运行依赖。

## 数据与玩法保持

- 体力继续绑定现有StaminaSystem.changed；未改最大值、冲刺消耗、恢复、Shift切换或屏障免费冲刺规则。
- 背包继续使用现有LuckyRabbitFoot、LuckyCoin、LuckyHorseshoe，数量、对应门及消耗规则不变。数字键选择，Q或双击主动使用兔脚；被动钥匙只在对应门前按E消耗。
- 蛋糕继续拾取立即恢复45体力并1.3倍加速8秒；胶囊继续原概率即时生效。没有为显示图标把它们改成背包道具。
- 状态只显示真实生效的蛋糕、面粉、胶囊透视/减速、电视反向、兔脚引导、屏障加速及圣堂时限；到期自动清除。未提供独立PNG的状态保留文字与时间，不伪造道具。
- Maze01/02与Maze03探索在可操作阶段正向计时；Maze03比赛从GO开始读取原比赛时钟。老鼠先到后计时继续到查理抵达。暂停菜单中计时与玩法一同暂停。
- 58秒阿尔吉侬标定、固定路线、比赛结果、圣堂一次机会及独立减速均未修改。

## ESC、重开与返回

原上下工具栏和主界面外壳在正式游玩中隐藏。原控件保留原节点位置，由ESC面板代理原操作，避免破坏现有脚本引用；返回原迷宫选择页时恢复选择界面。

ESC保留适用的音乐开关与音量、全图、俯视、重置视角、路线A/B、位置检查、关卡重置、署名、路线测时等功能。Maze03另有探索/比赛选择；比赛开始后变化排队，重开后才生效。Maze01/02不显示比赛选项。

右上不设设置按钮；音乐控制在ESC。退出/重开确认和ESC会暂停，取消恢复。重开重新创建当前关卡，重置查理、体力、背包、状态、计时、机关、老鼠、比赛及圣堂使用标记，并保留Maze03已选择的模式。

背景音乐经共用GameHUDMusic总线控制，默认100%保留原曲音量，开关与音量在本次运行内跨重开/换迷宫保留。F11切换桌面全屏，F10关闭打开面板。编辑器自身边框不属于游戏HUD；独立桌面窗口已验证全屏。浏览器仍须玩家主动点击网页全屏入口；本轮没有重新导出或验收网页包。

## 素材保护

assets/UI/HUD/ASSET_MAP.md记录逐张尺寸与用途。11张原PNG保存在originals，逐一SHA-256与桌面源文件一致。24张slices仅透明边界拆分及收紧裁切，不重绘、改色、拉伸或覆盖原图。

保留用户确认的纯色0–9及冒号版本；纸纹02:35示例未使用。缺少计时底图按确认保留透明底；设置图标不再需要。导入无损、保留Alpha及边缘修正、等比显示。sticker_finish.gdshaderinc仅在运行时轻微处理白色外边缘，不修改资源像素。

## 实际测试结果

| 检查 | 结果 |
|---|---|
| 最终界面交互 check_polish.gd | 原生实际运行95项通过、0失败；覆盖三个迷宫、手写字体、悬停及稳定热区、真实拾取/E开门、圆槽、圣堂提示、两类确认框、取消/重开/退出与模式重置 |
| 最终统一布局 check_redesign.gd | 原生实际运行52项通过、0失败；覆盖两枚菜单、无任务框、下方统一尺寸、无解释文字、实际人物朝向、黄色圆弧四方向像素检查、圆槽保留、通知及ESC音乐 |
| 初始完整HUD与数据绑定 check_hud.gd | 136项通过、0失败；全屏、计时、暂停、拾取、机关、状态、比赛与重开。后续样式修改由上述最终检查覆盖 |
| 窗口比例 check_aspect.gd | 39项通过、0失败；16:9、16:10、超宽屏、固定数字槽与部分体力填充 |
| 单独入口 check_standalone.gd | 18项通过、0失败；三个独立场景及F6选择页的返回与重开 |
| 实际道具双击 check_double_use.gd | 3项通过、0失败；生成真实引路光团，只消费一次，空槽不重复 |
| 通知反馈 check_feedback.gd | 6项通过、0失败；真实开门通知、圣堂状态显示 |
| 原有体力、免费屏障冲刺、圣堂及竞速集成 | 均PASS；原机制保持，含查理先到/老鼠先到/平局及模式排队 |

未使用圣堂时老鼠记录58.000002秒；HUD用例查理59.566667秒到达，老鼠先到后计时正确持续。圣堂完整6秒用例老鼠63.684169秒到达，独立时间减速仍有效。这些是功能用例数据；查理测试通过终点触发验证结算，不代表人工跑图成绩。

最终记录见.verification/unified-hud/polish.log、polish-results.json、redesign.log、redesign-results.json。未进行Mac、集显或浏览器帧率验收，不承诺这些环境的性能。

已知原有问题：Maze02实例退出后，进程结束时仍可报告两项87,380字节GL纹理未释放警告，重复加载对应重复；本轮没有修改其电视/幽影资源。当前最终检查没有新增GDScript报错。浏览器包尚未重导出，因此现有线上试玩不会自动更新。

## 文件清单

本轮修改的已有文件：

- godot/project.godot：统一逻辑分辨率、比例及启动显示模式。
- godot/scripts/main.gd：隐藏游玩外壳、返回与重开接口。
- godot/scripts/maze/maze_scene.gd：正式三迷宫共用HUD安装点及配置。
- godot/scripts/levels/maze01_key_scene.gd：Maze01/02交由共享HUD管理显示，旧预览保留。
- godot/modules/maze03_final/scene.gd：Maze03使用共享HUD。
- godot/modules/maze_items/maze_inventory.gd：显示信号、snapshot/select/use接口，原功能不变。
- godot/tests/maze03_sanctuary/check_sanctuary.gd：适配共享HUD层级与音乐总线检查。

新增资源与脚本：

- godot/modules/game_hud/：GameHUD.tscn、game_hud.gd、runtime.gd、assets.gd、digit_timer.gd、stamina_widget.gd、stamina_fill.gdshader、inventory_widget.gd、notification_widget.gd、interaction_widget.gd、compass_widget.gd、compass.gdshader、note_decor.gd、sticker.gdshader、sticker_finish.gdshaderinc、session_clock.gd、configuration.gd、default_configuration.tres及Godot标识文件。
- godot/assets/UI/HUD/：11张原图、24张拆分PNG、字体及许可、导入描述、素材映射和原图校验清单。
- tools/import-hud-assets.ps1、tools/build-hud-font.cjs：可复现素材拆分和字体子集构建工具。
- godot/tests/game_hud/：共用HUD、原生交互、布局、比例、入口、双击与反馈检查。
- 本报告及.verification/unified-hud/日志、结果JSON与截图。

未删除原场景、原PNG、机关资源或开发按钮。未修改三个迷宫路线、建筑、相机FOV、移动、体力数值、道具机制、竞速规则及圣堂机制。

## 最终1920×1080实机截图

- [Maze01](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze_1080.png)
- [Maze02](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze02_1080.png)
- [Maze03](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze03_1080.png)
- [拾取后的圆槽及半透明通知](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze_pickup_redesign.png)
- [门前E提示](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze_opening_prompt.png)
- [圣堂E提示](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/maze03_sanctuary_prompt.png)
- [退出便利贴](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/exit_confirmation.png)
- [重开便利贴](D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/restart_confirmation.png)

打开上述D盘project.godot后F5，从原选择页进入迷宫即可体验；ESC打开开发面板。
