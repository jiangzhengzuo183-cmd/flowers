# 主菜单与正式剧情入口

Godot 4.7.2 / Compatibility。工程 F5 进入 MainMenu.tscn。主菜单始终使用 1920×1080、16:9；其他物理屏幕保持比例。仅主菜单接管显示，离开时恢复剧情或迷宫原有配置。

## 当前构图与动画

纸张占据主要画面，主纸以自身视觉中心等比放大；标题、文字和按钮沿用原有尺寸与位置。深暖木桌仅在窄边和局部边角露出，左侧下层纸稍向内收，露出量与其他边缘接近。下层白纸上沿再收回约 4px，增加顶部木纹露出，底边和蓝纸角保持。原有黄色层保留在右下，额外蓝纸只在左下自然露出一个小角。下层均为完整纸张，以不同角度和 7fps 错相微动叠放，不通过切掉一块纸制造纸角；纸层之间有窄阴影，整叠纸在桌面上有更柔和的投影。主纸保留淡点阵；无胶带、手部、查理插画、光斑或半屏明暗。

英文标题保留褐色手绘边、暖黄填充和分段字形。18 字按 FLOWERS / FOR / ALGERNON 顺序原位逐字浮现，约 2.68 秒完成，再显示菜单；各字保持微倾、错落和 8fps 常态抖动。中文菜单和制作名单沿用 YeLiHangJiuLinKaTong 字库、深褐色及 7fps 轻抖动。

三组蓝色／青色油画棒小花共八朵，只有花头，无茎叶。大小和高度错落，按花瓣、花心顺序逐渐绘出，完成后仍轻抖。花朵、标题和中文字共用主纸的微动和破口遮罩；老鼠可踩过，啃穿时同处印迹一并消失。

## 老鼠、铅笔与纸面

用户选定的 mouse_cartoon.png 原图保留。位置、360° 转向和身体引导的弧线每帧更新；10fps 仅用于细微步伐，8fps 保留手绘边缘感。老鼠位于纸面印迹与铅笔上方，不拦截按钮点击。接触阴影根据脚步、速度和转弯持续变化；不是一块固定椭圆。

铅笔在左下竖放，笔尖约向菜单方向偏 12°，较粗的笔杆延伸到下边缘之外。窄接触阴影叠加柔和投影，使其压在纸上。接近并真正跨过笔杆时自动跳跃：0.08 秒轻收身、0.56 秒腾空、约 42px 高度，之后轻微落地回弹；阴影留在纸面、变淡并展开，落地恢复。平行经过不触发，同一次跨越不会反复跳。铅笔及最大破口外缘范围禁啃；身体不在笔上但鼻尖靠近时同样检查。弹窗打开时立即恢复地面显示，避免停在半空。

指针静止 3 秒且老鼠停稳后啃纸。四口逐渐扩大，半径 23–35px、方向、比例、48 点轮廓及纤维边独立随机，最多保留八处。相交破口合并为同一个开口，没有内部白缝；洞中显示同一张连续的英文斜体手写笔记页，纸边含厚度和内投影。移动即中止，重入菜单清空。完整英文笔记页只渲染缓存一次，破口纹理仅在增长或变化时重绘。

纸张摩擦声复用项目已有 Luckius CC0 纸张录音，播放短粒并淡入淡出；待机、腾空、弹窗及失焦时停止。所有移动与跨笔参数仅属于主菜单老鼠，不改变查理或迷宫机制。

## 菜单与指针

开始游戏淡出后进入 res://modules/visual_novel/VisualNovel.tscn，即朋友的正式视觉小说入口；不进入迷宫选择。制作名单是中央奶黄色便利贴，后方变暗，右下折角，文字轻抖；返回、Esc 或空白遮罩触发揭开退出。回到桌面先显示迷宫风格的“是否确认退出游戏？”，确认后正常退出。

主菜单从第一帧绘制已确定的黄色三帧指针，不需进入游戏才替换。复用 game_hud/hand_cursor.gd 的缓存图与热点；菜单内由独立 CanvasLayer 显示，按钮、便利贴和退出框保持同款，离开后交回现有剧情／游戏原生指针。

## 主要文件

| 文件 | 职责 |
|---|---|
| main_menu.gd / MainMenu.tscn | 固定构图、菜单状态、正式剧情接口 |
| title_animation.gd / title_ink.gdshader | 18 字逐字浮现、常态抖动与纸面印迹 |
| menu_typography.gd / hand_wobble.gdshader | 中文手写字体、抖动和踩压 |
| paper_stack.gd / paper_layer.gdshader / paper_motion.gdshaderinc | 完整纸层、居中放大、独立微动、纸边和桌面投影 |
| flower_doodles.gd / flower_ink.gdshader | 三组花头、绘画过程、微动与破口裁切 |
| mouse_companion.gd / contact_shadow.gdshader | 连续跟随、整圈转向、跨笔、禁啃和实时接触阴影 |
| pencil_prop.gd / pencil_ink.gdshader / pencil_shadow.gdshader | 铅笔轮廓、对应作用区域、轻抖与双层阴影 |
| paper_interaction.gd / tear_mask.gd / tear_reveal.gdshader | 随机破口、相交合并、纤维边和内投影 |
| underpaper_notes.gd | 仅从破口露出的连续英文斜体笔记页 |
| menu_cursor.gd | 从首帧生效的菜单三帧自定义指针 |
| note_modal.gd / credits_panel.gd / sticky_corner.gd / paper_fold.gdshader | 制作名单、折角与揭开退出、桌面确认 |
| paper_foley.gd | 短纸张摩擦声及专用音频总线释放 |

原 menu_decor.gd、paper_ink.gdshader 已被当前分层方式替代并移除引用。原用户素材完整保留。

## 素材映射与生成说明

| 资源 | 用途／来源 |
|---|---|
| assets/background.png / assets/originals/ | 用户原底图和参考；保留源文件 |
| assets/title_handdrawn_v2.png | 已确认的手绘英文标题；完整提示词同名 .prompt.txt |
| assets/mouse_cartoon.png / mouse_cartoon_layout.gd | 用户最终选定老鼠，未经重绘 |
| assets/paper_stack_yellow_blue.png | 保留主纸、纸边与淡点阵的透明叠纸衍生图；提示词同名 .prompt.txt |
| assets/paper_single.png | 完整单张透明纸，用于重建不会漏空的下层白纸、黄纸和蓝纸；完整提示词 paper_single.prompt.txt |
| assets/wood_desk.png | 独立木桌；运行时统一调深、调暖；完整提示词 wood_desk.prompt.txt |
| assets/flower_heads.png | 三个独立蓝／青色花头图集，复用成三组八朵；完整提示词 flower_heads.prompt.txt |
| assets/pencil_handdrawn.png | 2172×724 透明铅笔，Atlas 非破坏裁切；完整提示词 pencil_handdrawn.prompt.txt |
| assets/background_clean_v2.png | 保留作下层笔记页纸纤维来源；提示词同名 .prompt.txt |
| visual_novel/assets/fonts/YeLiHangJiuLinKaTong.ttf | 复用项目中文字库 |
| visual_novel/assets/audio/paper.mp3 | Luckius / Various Paper Sound Effects / CC0 |
| game_hud/hand_cursor.gd / assets/UI/HUD/hand_cursor/ | 复用已有黄色指针和三帧抖动 |

新增及衍生 PNG 使用内置图像生成工具，未使用 API／CLI；生成原件复制到本模块，不覆盖用户源文件。完整最终提示词逐个保存在 assets/*.prompt.txt。PNG 保留 Alpha，导入修正透明边缘并为缩小显示生成 mipmaps。

## 验证与运行

原生窗口验收包括 check_main_menu.gd 的 196 项、check_paper_details.gd 的 21 项、check_pencil.gd 的 11 项。覆盖四种物理尺寸下统一 16:9、标题逐字及常态帧差、完整纸层与底边连续、蓝色小角、桌面投影、花朵绘画、印迹被啃、首帧自定义指针、实时鼠影、双向跨笔、禁啃、弹窗、正式剧情开场／外景及三个原迷宫适配。

check_quit.gd 在 1280×720 窗口实际点击退出、取消、再次退出、确认；check_startup.gd 检查工程默认全屏与入口。最终截图在 docs/screenshots/main_menu/。停止旧运行 F8，再按 F5 看完整菜单；独立打开 VisualNovel.tscn 按 F6 仍是剧情开发入口。

game_entry 可配置正式场景；连接 start_requested 时由接入方负责导航。主菜单不修改三个迷宫的建筑、相机、玩法、体力、道具、竞速或 HUD。

## 参考与限制

- 构图参考：[纸面文具俯拍](https://www.pexels.com/photo/black-pencil-on-white-paper-8489924/)、[笔记本与铅笔](https://www.pexels.com/photo/brown-wooden-pencil-on-spiral-notepad-6991438/)。仅参考摆放、裁切与纸面层次，未下载这些照片作为游戏素材；最终铅笔方向以用户确认的竖放、略朝菜单为准。
- [Godot 2D 灯光和阴影](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)：接触轮廓与柔化参考。本模块为二维 Alpha 阴影与跨越动画，没有增加三维物理场景。
- [纸张拟音原发布页](https://opengameart.org/content/various-paper-sound-effects)：Luckius / CC0，项目授权记录仍在 visual_novel/assets/audio/LICENSE-SOURCES.md。

本轮未重新导出 Web 包。朋友的 24 场剧情无画面走查此前通过，本轮原生检查仅覆盖开场、外景与三个迷宫接入，不将完整 24 场原生走查记为通过。原生关闭时偶见现有自定义指针的两条 OpenGL 纹理释放提示，正常运行与确认退出检查通过。
