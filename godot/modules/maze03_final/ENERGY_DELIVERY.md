# Maze 03：三圈弧墙、蜂巢屏障与空间共振

日期：2026-11-17。正式工程：D:/ChatGPT/献给阿尔吉侬的花束/godot/project.godot。

## 交付行为

- 西北采用三层不同半径的弧墙，开口错位。外圈分两段，中圈与内圈各一段。内圈墙高0.92m、中圈1.48m，外圈1.58–1.78m；地面平整。保留三道棚顶并调整内两道半径，与弧墙分层对应。
- 删除两块矩形顶棚的运行时生成，保留原有资产文件。绿圈附近H4/H5墙段降至约0.92–1.08m；B5屏障移至B路线[2,6]→[2,7]，不再与G3并排挤在一起。
- 黄圈墙体延长0.85m，与原墙衔接；保留上方1.55m通行口。仅本场景B参考线局部更新为真实弧墙路线，原始地图数据不改。
- 六处屏障保留直接穿越和1.35倍/3秒加速逻辑。新蜂巢有细光芯、柔光、沿边亮点、低对比细网、轻微扫光和少量光屑；穿过时邻近单元按距离依次点亮，门框地面短暂受光。
- 三条旧速度丝带被四个复用的查理定格骨骼姿势替代。共享模型/蒙皮，不创建动画控制器；每0.12秒取样，0.46秒淡出。停下不继续生成，重置清空。
- 环形巨构轴旁256个小蓝色上升粒子，不为每个粒子添加灯。环形巨构58秒周期小角度摆转，低圆盘13秒周期轻微浮动；其余巨构保持稳定。
- 每局随机安排1–2次地震。首次在实际游玩24–38秒后，第二次间隔55–88秒；查看全景时不累计触发时间。镜头震颤约3.4秒，结束后偏移归零；玩家移动与墙体碰撞不变。
- 地震在身边四组墙顶和三处远方巨构边缘释放落尘与有棱角的白色碎石，碎石带翻转，巨构碎石尺度更大。全是无碰撞装饰，数量有上限，复用粒子池，不永久留在地面。
- 修复粉尘黑色方块：使用明确圆软边Alpha的独立粉尘Shader，不再用出错的渐变面片。
- 四段短小道路嵌入流光，随加速提高流速；不是贯穿地图的导航线。原有直风、水中波纹水花、脚印、全屏保持。
- 按用户补充，保留原有our_expanse.mp3。Video Game Trance因站点拒绝自动下载尚未接入，用户已选择推迟。中央建筑没有增加新功能。

## 修改文件

- barrier.gd
- camera.gd
- check_final.gd
- courtyard.gd
- enclosure.gd
- energy.gdshader
- generator.gd
- player.gd
- ring_axis.gd
- scene.gd
- sound.gd
- speed_trails.gd

## 新增文件

- afterimage.gdshader
- check_energy_review.gd
- earthquake.gd
- megastructure_motion.gd
- race_inlay.gdshader
- race_inlays.gd
- stone_powder.gdshader
- 本记录 ENERGY_DELIVERY.md；Godot为新脚本/Shader自动生成对应.uid。

没有删除源文件，没有修改Maze01、Maze02、入口或导出配置。

## 实际验证

- Godot 4.7.2 Compatibility，RTX4060原生图形运行。
- check_final.gd --routes：完整A/B路线真实键盘输入、碰撞通行PASS，failures=0。日志.verification/maze03-energy-final-routes.log。
- check_energy_review.gd：原生图形PASS，failures=0；包括三圈内侧实际可进入、错开的B5、真实冻结骨骼姿势、停止淡出、地震次数上限/间隔、镜头恢复、复用池、静音和重置清理。日志.verification/maze03-energy-render.log。
- 241个受保护源码/场景/配置文件SHA256核对一致，改动0。
- 验收截图目录.verification/maze03-energy-review/：overview、northwest_roof、northwest_arc_layout（临时隐藏棚顶便于看弧墙）、northwest_transition、northwest_charlie、honeycomb_idle、honeycomb_crossing、charlie_afterimages、ring_particles、quake_charlie_view、quake_giant_ring、quake_giant_disc。
- 新效果使用Compatibility可用的基础Shader、复用骨骼和CPU粒子，不依赖体积光或屏幕空间反射。网页实际帧率尚未重新测试，原生固定步长验收不代表网页60帧承诺。

## 运行

关闭旧试玩窗口，在D盘正式工程打开scenes/levels/Maze03.tscn并F6运行；F10纯画面，F11全屏。

本轮未重新导出网页、未提交或推送。

## 2026-11-17：屏障常态蓝光补充

- 常态局部蓝光能量0.95、范围3.6m，穿过时在此基础上增强，六个屏障均常亮。光色#64AAFF，没有增加灯数量或实时阴影。
- 屏障面改为更明确的蓝色，并提高常态自发光与少量底色透明度。
- 穿透变形先检索视觉参考，本次没有把未选定的接触形变方案直接替换进去。
- 原生图形验收截图 blue_without_bounce / blue_with_bounce 对比实际环境受光，不只是材质自发光。

## 2026-11-17：强震起始冲击

- 每次地震开头约0.045秒快速建立侧倾，峰值5.5度，伴随短促画面下挫和1.2度俯仰；随后一次较小反向回弹，在约0.73秒内消退，再接原有持续余震。方向每次随机，事件数量仍为每局1–2次。
- 环形巨构与圆盘同步受到短暂视觉冲击；不旋转可通行地面、墙体碰撞或玩家物理体。
- 重置时立即清空冲击和巨构震颤。原生图形检查通过：首次强倾斜确实可见、结束后镜头水平与偏移恢复、不会触发第三次。日志.verification/maze03-strong-shock-render.log；截图quake_strong_hit.png。
- 六处常态蓝光与原有效果检查通过，日志.verification/maze03-blue-idle-render.log。
- 穿透参考：Mirza Beig交互蜂巢 https://mirzabeig.itch.io/energy-shield-vfx ，Gabriel Aguiar交界发光 https://gabrielaguiarproductions.artstation.com/projects/LRE8y0 ，CGHOW接触光屑 https://cghow.com/particles-on-sphere-interaction-in-ue5-niagara-tutorial/ 。仅作为视觉研究，没有导入外部项目或替换穿透变形。
