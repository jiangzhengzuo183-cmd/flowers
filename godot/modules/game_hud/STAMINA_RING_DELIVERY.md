# 闪电圆环体力 HUD 交付（2026-11-18）

后续鼠标、计时数字及连续舞蹈的追加说明见 CURSOR_TIMER_DELIVERY.md。

本报告替代 V2_DELIVERY.md 中横向能量槽、状态插画及菜单返回鼠标的旧说明。

## 完成内容

Maze01、Maze02、Maze03 共用 GameHUD.tscn 中同一个 stamina_widget.gd；三个场景不维护独立体力 UI。体力、冲刺、恢复和增益时长仍由原有系统负责。

使用用户提供的 1280×1141 原始 PNG。original.png 保留原字节，SHA256 为 232A9FC1156B4F283DB8045CE5682F01D2F211E5C5B173DD6982E8C971B33F29。未重新绘制中央闪电或深棕轮廓，未添加白色贴纸外框。旧横条资源保留，但不再显示。

- 环带从右上 45° 位置开始，按顺时针真实裁切进度；不是标准圆线覆盖。填充严格按原图环带像素遮罩，闪电独立。
- 普通状态黄色 #F6C83D；任意蛋糕或屏障加速有效时为蓝色 #80BDE5。两种来源统一读取；颜色与体力比例分离。
- 体力填充平滑跟随真实值；蓝黄渐变自然，不闪白，不因颜色改变恢复体力。
- 空环带为干净奶油白，无气泡、色点或粒子。原手绘颗粒保留在棕色轮廓、闪电及有色颜料中。
- 普通走路、静止时闪电静止；实际奔跑时闪电只有 0–1.2% 的轻微缩放；增益刚触发时短暂弹性最大约 2.3%。圆环本身不旋转、不位移。
- 按最新补充，棕色轮廓常态保留每秒 8 帧、3 个姿态的手绘抽帧感，幅度 0.42 个逻辑像素。只改变轮廓邻域，填充内部保持稳定；暂停时冻结。
- 没有新增低体力规则。当前的 exhausted_restart=20 是耗尽后的恢复阈值，不能被当成警戒阈值。
- 状态与拾取通知均为纯文字，不再显示插画图标。右下道具栏的实际道具图标保留。
- 通知标题、说明分别真正居中；圆角随真实高度取一半，形成完整胶囊，仍使用半透明灰色底和原队列/淡出规则。
- 进入迷宫默认捕获鼠标转向；关闭右上角退出、重开、设置及 ESC 面板后恢复游戏窗口焦点和转向模式。原双击释放鼠标与设置灵敏度保留。

## 布局

1920×1080 下，圆环组件 200×200，左下边距各 40，左上位置 (40,840)，比道具栏单槽/选中槽略大，和右下道具栏底边一致。图像保持原比例。状态提示位于圆环右侧 x=268，使用两列短文字，避免遮住圆环。其它计时、任务、菜单、道具槽、分辨率、相机及场景未改。

## 读取与渲染方式

stamina_presentation.gd 是只读适配器：从 actor.stamina.percentage() 读取进度，从已有冲刺/实际移动状态读取跑步，从原 cake_effects.boost_remaining 和 Maze03 actor.boost_remaining 读取两种加速。它没有自己的加速倒计时或体力数值。

多个增益用逻辑或合并。一个来源结束不会覆盖另一个有效来源。boost_serial 用于一次轻微激活动画，重复触发不会让蓝色错误提前结束。

当前玩法依然是加速不耗体力，期间可按既有规则自然恢复。蓝色长度显示实际体力，绝不会因变蓝而自动填满；增益结束时原本开启的冲刺继续正常消耗。

离线工具 tools/import-stamina-ring.ps1 只从原 PNG 分离资源：base.png 为底层，masks.png 的 R 为环带、G 为闪电内区、B 为棕色轮廓，lightning.png 为上层。source.png 为保留原像素的裁剪。蒙版导入禁用 fix_alpha_border，Shader 同时使用 Alpha，防止透明像素的 RGB 扩散覆盖轮廓。运行时没有逐像素资源扫描或逐帧重建材质。

## 文件清单

修改：
- modules/game_hud/GameHUD.tscn（统一圆环与状态位置）
- modules/game_hud/stamina_widget.gd（圆环展示、颜色和轻微闪电动画）
- modules/game_hud/runtime.gd（接入只读体力状态）
- modules/game_hud/game_hud.gd（状态接口，移除状态插画）
- modules/game_hud/notification_widget.gd（纯文字、居中、完整圆角）
- modules/game_hud/mouse_look.gd（默认及菜单返回转向）

新增：
- modules/game_hud/stamina_presentation.gd
- modules/game_hud/stamina_ring.gdshader
- modules/game_hud/stamina_lightning.gdshader
- assets/UI/HUD/stamina_ring/original.png、regions.gd、derived/ 下 4 张 PNG 和相应导入设置
- tools/import-stamina-ring.ps1
- tests/game_hud/check_stamina_ring.gd、check_stamina_ring_art.gd、check_ring_mouse.gd
- 本报告

没有删除旧资源；未修改角色移动脚本、体力配置、蛋糕/屏障效果、比赛规则、相机或地图。

## 实测

环境：Godot 4.7.2，Compatibility，RTX 4060 Laptop，原生图形窗口，1920×1080。

check_stamina_ring.gd：112 项通过，0 失败。实际运行全部三个迷宫，覆盖：正常走路/冲刺消耗/延迟恢复/归零；实际拾取存储和 E 使用蛋糕；蓝色真实比例；实际屏障穿越；蛋糕先结束、屏障先结束两种重叠；加速结束后继续冲刺恢复消耗；切换场景与重开清除状态；文字无插画、居中和完整圆角。

像素检查包含 0/25/50/75/100% 与蓝色 50%。在排除轮廓抽帧的基准帧中，轮廓、中央闪电、透明背景的修改像素为 0，进度裁切错误为 0，空环带内部色点为 0。另检验抽帧只影响轮廓邻域，不移动填充内部。可见颜料面积会因手绘宽窄及闪电遮挡与角度比例稍有不同，进度按统一圆周角度计算。

check_ring_mouse.gd：实际测试三个迷宫进入即转向、右上三个按钮关闭后恢复、ESC 返回，以及 Maze01 真实面粉惩罚及 Maze02 电视干扰出现/清除且文字无插画。34 项通过，0 失败。

运行截图/日志/结果 JSON 在仓库外部交付目录 ../.verification/stamina-ring/（不提交 Git）。包括每个迷宫 walking_ring、cake_blue_ring，Maze03 overlap_blue_ring，以及各档原图渲染检查图。

本轮没有已知未解决的脚本错误。未重新导出或测试网页版本；浏览器首次鼠标锁定仍遵守浏览器的用户手势限制，不绕过限制。
