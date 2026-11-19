# 主界面与正式剧情入口

Godot 4.7.2 / Compatibility。F5 打开 `MainMenu.tscn`。主界面固定 1920×1080、16:9，完整显示原纸张底图；不扩展背景纹理、不拉伸，不同屏幕等比显示。

## 当前效果

- 18 个原分段字形，以独立 AtlasTexture 播放入场；三行按不同节奏落下，带轻微回弹、压缩恢复。落定后每字保留约 ±1.8° 的倾斜、上下错落和错相三帧抖动（8fps）。
- 用户后续明确授权重新生成标题：当前 `assets/title_handdrawn_v2.png` 使用褐色手绘轮廓、暖黄色纸笔肌理。透明背景及镂空保留。使用内置图像生成工具制作；完整提示词同目录 `title_handdrawn_v2.prompt.txt`。
- 开始游戏、制作名单及返回：新纸先从底部露出，再向上抽出覆盖旧页、轻轻落稳，约 1.32 秒。转场期间拦截输入，结束释放画面纹理。
- 开始游戏直接进入 `res://modules/visual_novel/VisualNovel.tscn`，不打开迷宫选择，不使用旧三句占位序章。
- 制作名单沿用原底图，含用户提供的完整说明及返回按钮。
- 回到桌面调用正常退出；鼠标复用原有三帧手绘指针。
- 当前游戏老鼠仍是用户原几何线稿。增加大小与可读性、平滑跟随、转向、避让、观察、点击反应和待机啃纸；所有交互均穿透到菜单按钮。
- 接触效果沿原线稿 Alpha 形成细窄、低透明度的暖褐接触阴影和微弱亮边，没有独立椭圆投影。
- 鼠标停留 5 秒后啃纸，四口逐渐形成小的不规则纸洞；移动即停止；制作名单与标题入场期间停用；重新进入场景清空。

## 待用户选定的老鼠预览

`previews/cartoon_mouse_smooth_v2.png` 为俯视卡通版预览，保留第一版平整奶白身体与粉耳，四爪收在身体下面。尚未替换游戏老鼠。`previews/.gdignore` 防止预览进入游戏导出。提示词在同目录，原生成图保留。

## 素材映射

| 文件 | 来源／用途 |
|---|---|
| assets/background.png | 用户 8000×4500 底图，字节原样复制 |
| assets/originals/ | 用户原参考、底图、标题、老鼠，未覆盖；不导出 |
| assets/letters/ | 原标题无损切片，保留作回退资源 |
| assets/title_handdrawn_v2.png | 后续授权生成的褐边暖黄标题；1672×941，RGBA |
| assets/layout_handdrawn.gd | 18 个图集区域，原 PNG 不重新编码 |
| assets/menu_0～2.png | 从原参考图与底图差分提取的原中文菜单字形 |
| assets/mouse.png | 原几何线稿老鼠，仅裁去空白边界 |

`main_menu.gd` 管菜单状态；`title_animation.gd` 管字母；`mouse_companion.gd` 与 `companion_path.gd` 管跟随与保护区；`paper_interaction.gd` 管非破坏性纸洞；`paper_transition.gd` 管抽纸；`credits_panel.gd` 管制作名单。

## 接口与验证

`game_entry` 可配置正式入口；连接 `start_requested` 时由接入方负责导航。菜单临时设置自身设计画布，离开时恢复原显示设置，不改动迷宫 HUD 布局或移动、体力、道具、竞速规则。

实际运行检查：`tests/main_menu/check_main_menu.gd`，原生 Compatibility 图形界面。当前 125 项通过，含 18 字落定后真实帧差、16:9 构图、四种输出尺寸、避让、啃纸、制作名单抽纸返回、真实剧情入口及三个原迷宫适配。截图在仓库 `.verification/main-menu/`。16:10 分辨率只验证保持 16:9，不再做额外排版。

`check_quit.gd` 验证缩放窗口下点击退出；`check_startup.gd` 验证工程全屏默认入口。`check_story_integration.gd` 沿用朋友的 24 场剧情走查，迷宫使用明确标记、无计分的开发完成回调；不把跳过当作实际通关成绩。
