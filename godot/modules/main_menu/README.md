# 主菜单与正式剧情入口

Godot 4.7.2 / Compatibility。工程 F5 进入 MainMenu.tscn。菜单固定 1920×1080、16:9；完整等比显示用户纸张底图，不自动延展，不拉伸。其他屏幕比例保持 16:9。

## 当前表现

- 英文标题保留已确认的分段字形、褐色手绘边和暖黄填充。18 字按 FLOWERS / FOR / ALGERNON 顺序在原位逐字浮现，每字约 0.16 秒渐显，约 2.68 秒完成；各字保留倾斜错落和持续 8fps 错相抖动。
- 中文菜单和制作名单使用项目现有 YeLiHangJiuLinKaTong 手写字体，深褐 #705039，7fps 小幅手绘抖动。英文标题不随中文换字体。
- 两条半透明胶带位于纸张左上角、右下角。当前不显示查理插画。
- 叠纸划为背纸、黄纸、上层纸三张独立显示层，分别以 7fps 错相轻抖动。整体画布和按钮保持稳定。右侧脏斑已清理，原纸边和叠纸阴影保留。当前不显示额外光斑或半屏明暗效果。
- 开始游戏短暂淡出，进入正式视觉小说 res://modules/visual_novel/VisualNovel.tscn。
- 制作名单是中央奶黄色便利贴：约 0.34 秒轻贴落稳，主菜单在后面变暗。右下角带轻微翘起的折角和浅色纸背；文字轻抖动；返回、Esc 或点击空白遮罩会在约 0.30 秒内从顶部揭开退场。打开时停用老鼠跟随、啃纸与脚步声。
- 回到桌面先显示“是否确认退出游戏？”；复用迷宫 HUD 的纸张样式，取消返回，确认后正常退出。没有抽纸、翻页或旧画面截屏转场。
- 复用迷宫现有三帧黄色自定义指针，保持实际热点和点击位置一致。

## 老鼠与纸面互动

用户选定的 assets/mouse_cartoon.png 原样复制，未经重绘。260px 图集设计高度，实际可见鼠身与尾巴约 225px；位置和转向每帧连续更新，10fps 仅用于细微步伐收放，静止仍有 8fps 手绘抖动。

老鼠由身体朝向引导弧线行进，能连续转过完整 360°，靠近鼠标后自然减速。标题和文字可直接踩过，并出现极轻微的局部下压反馈；完整轮廓仍限制在纸面内，插画不截获菜单点击。指针静止满 3 秒且老鼠停稳后开始啃纸，四口逐渐扩大破口。每次独立随机生成半径 23–35px、长宽比、方向、48 点不规则轮廓和白色纸纤维边；最多保留 8 处，移除旧破口后新轮廓仍保持随机。移动即停止，离开并重入菜单清空。

接触阴影沿 PNG Alpha 轮廓柔化，移动时略散、停下时略收；极轻的边缘亮暗模拟纸面受压。它是二维视觉模拟，没有给鼠标跟随附加物理碰撞。

移动时播放项目已有的 CC0 纸张录音短片段，经带通处理、轻微变调及淡入淡出匹配小步摩擦；待机、弹窗、失焦时停止。素材为纸张拟音，不宣称是真实动物脚步录音。

## 文件职责

| 文件 | 职责 |
|---|---|
| MainMenu.tscn / main_menu.gd | 布局、菜单状态与入口信号 |
| title_animation.gd / title_ink.gdshader | 18 字入场及常态手绘抖动 |
| menu_typography.gd / hand_wobble.gdshader | 中文字体、配色与轻抖动 |
| note_modal.gd / credits_panel.gd | 中央便利贴、揭开退场及退出确认 |
| sticky_corner.gd / paper_fold.gdshader | 透明裁角、纸背及贴边阴影 |
| menu_decor.gd | 左上／右下对角胶带 |
| paper_stack.gd / paper_layer.gdshader / paper_ink.gdshader | 三张纸的独立裁切和错相轻抖、右侧清理合成 |
| mouse_companion.gd | 每帧跟随、整圈转向、身体引导的弧线、步伐及纸边限制 |
| contact_shadow.gdshader / paper_interaction.gd | 接触边缘、压痕及纸洞 |
| paper_foley.gd | 短纸张摩擦声；退出清理专用音频总线 |

## 素材映射

| 资源 | 来源／用途 |
|---|---|
| assets/background.png | 用户 8000×4500 底图，字节原样保留 |
| assets/background_clean_v2.png | 内置图像工具清理后的纸面；仅混合上层纸右侧内部，保留原图边缘；完整提示词 background_clean_v2.prompt.txt |
| assets/originals/ | 用户原参考、底图、标题、老鼠；不参与导出 |
| assets/title_handdrawn_v2.png | 后续授权生成的褐边暖黄标题，1672×941 RGBA；提示词同目录 |
| assets/layout_handdrawn.gd | 18 个 AtlasTexture 区域；原 PNG 不重新编码 |
| assets/mouse_cartoon.png / mouse_cartoon_layout.gd | 用户最终卡通老鼠原图、鼻尖与轮廓数据 |
| visual_novel/assets/fonts/YeLiHangJiuLinKaTong.ttf | 复用项目中文字库，缺字仅本模块回退思源字体 |
| visual_novel/assets/audio/paper.mp3 | Luckius，Various Paper Sound Effects，CC0 |
| game_hud/hand_cursor.gd | 复用既有指针及三帧抖动 |
| assets/letters、menu_0～2.png、mouse.png | 原始标题切片、菜单字形与几何老鼠，保留作来源／回退 |

胶带、纸层遮罩、抖动和啃纸由引擎绘制。原 background.png 保持原样；清理图另存，不覆盖源文件。当前未接入手部插画。

## 运行和接口

game_entry 可配置正式入口；连接 start_requested 时由接入方导航。菜单离开时恢复进入前的显示设置。迷宫仍使用原相机、HUD 和玩法。完整流程用 F5；单独打开 VisualNovel.tscn 后按 F6 会直接进入剧情。

原生图形检查：tests/main_menu/check_main_menu.gd。当前 190 项通过，包含四种物理输出尺寸下的 16:9 构图、原位逐字标题、18 字常态真实帧差、三张纸各自的实际帧差、右侧肌理清理、连续整圈转向、弧线移动、文字穿行、3 秒啃纸与随机破口、便利贴反复开关、退出框完整尺寸、真实剧情开场与三个迷宫适配。

check_quit.gd 在 1280×720 窗口真实点击“回到桌面→取消→回到桌面→确认退出”；check_startup.gd 验证工程默认入口与全屏。check_story_integration.gd 保留朋友的 24 场剧情走查，开发跳过迷宫不生成计分成绩。

## 参考与限制

- [Godot 2D 灯光和阴影](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)：轮廓遮挡、阴影柔化与法线光照的参考；本模块使用适合二维纸面 UI 的 Alpha 接触模拟。
- [Godot CanvasTexture](https://docs.godotengine.org/en/stable/classes/class_canvastexture.html)：二维材质光照参考，未引入额外三维场景。
- [纸张拟音原发布页](https://opengameart.org/content/various-paper-sound-effects)：Luckius，CC0。项目授权记录见 visual_novel/assets/audio/LICENSE-SOURCES.md。

本轮未重新导出 Web 包。24 场完整剧情的无画面走查已通过；原生图形验证覆盖真实开场、外景及三个迷宫接入，未把完整 24 场原生走查记为通过。图形关闭时仍偶见现有自定义指针的两条 OpenGL 纹理释放提示，不影响运行期显示和点击。
