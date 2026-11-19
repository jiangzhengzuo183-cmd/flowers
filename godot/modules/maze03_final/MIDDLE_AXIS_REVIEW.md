# Maze 03：巨构后方中景、环形光柱、直线高速风

日期：2026-11-16。正式工程：D:\ChatGPT\献给阿尔吉侬的花束\godot\project.godot。

## 已完成的视觉调整

1. 巨构受光白度参考迷宫受光面提升，保留蓝灰背光和距离柔化。仅调整远景局部材质，没有改变全局曝光、天空颜色或原有主光。
2. 圆盘顶端从23降到15，仍为六个主体中最低；中央圣堂高约10.3。其后原先用于填空的矩形体块已错开，低圆盘不再紧贴那两块大矩形。
3. 新增四组中景，明确放在现有巨构之后、最外轮廓之前的空间过渡区域，并从巨构之间的角度空隙露出。使用同一套弧形、切口体块和宽体块造型，没有在迷宫与巨构之间新建近景建筑。
4. 中景中心距约235–260个世界单位，前方主要巨构中心距约135–193；外层已有轮廓保持自身前后和强弱变化。中景不参与碰撞。
5. 环形巨构内部新增白蓝色中央光柱，三片交叉光带，每片宽22、高126，核心更明亮、边缘渐隐，参与已有镜面反射。
6. 一盏受限范围的暖色补光实际照到迷宫东北侧，位置(45,13,0)，朝向(33,0,14)，范围33，无实时阴影；没有给每个粒子或建筑创建灯光。
7. 风丝中心线改为严格直线；方向水平，局部高度0.9–2.8、高空5–15，速度分别23和34个世界单位/秒。低处风丝使用浅灰蓝以便在白墙前可辨认，高处保持白色。
8. 风仍为44条、两批网格；改直后移除无用细分，每条仅一个四边形。保留阵风强弱、循环风噪和原有静音控制，没有施加玩家物理风力。
9. 待选建筑贴图没有下载或应用。

## 文件

修改（仅 godot/modules/maze03_final/）：

- enclosure.gd：圆盘与背景体块位置，挂载中景和环形光柱。
- geometric_stone.gdshader：受光面白度与明暗响应。
- wind.gd、wind_flow.gdshader、wind_settings.gd：直线、低处风、流速与精简网格。
- check_final.gd、review_visuals.gd：新增层次、光柱、暖光、风高度等验证和截图。

新增：

- middle_distance.gd
- ring_axis.gd
- ring_axis.gdshader
- 本记录
- MUSIC_CANDIDATES.md

没有删除资产或更改原始模型。修改前备份：backups/maze03-before-middle-axis-20261116/。

## 实际验证

- Godot 4.7.2 Compatibility，NVIDIA RTX 4060 Laptop 原生图形运行。
- A/B完整路线回归：PASS，failures=0。
- 实际图形功能回归：PASS，failures=0。
- 285个受保护源码、场景、配置文件校验一致，意外变化0。
- 验证中景距离确实大于所有主要巨构、光柱确实位于环形体中心、暖光确实位于迷宫附近、低处风进入人物观看高度。
- 六处加速屏障、移动碰撞、水中跑跳波纹水花、音乐和风声循环/静音、纯画面与全屏检查通过。
- 当前保留墙体仍为274/338，与本轮前一致；没有修改路线。
- 原生采样约5.66ms、2495次绘制、609398个图元。固定步长测试不是网页或其他设备稳定帧率承诺。

## 图片与日志

截图目录：.verification/maze03-middle-axis/。

- ring_axis.png：环形巨构白蓝光柱。
- middle_distance.png、environment_overview.png、global_0.png至global_3.png：层次和全景。
- raised_disc_glass.png：最低圆盘及错开后的背景。
- regional_warm_before.png、regional_warm_after.png：同视角局部暖光对比。
- charlie_north/east/south/west.png：实际跟随视角。
- wind_above_maze.png、wind_later.png：直线风不同时间画面。

日志：maze03-middle-axis-routes.log、maze03-middle-axis-native.log、maze03-middle-axis-render.log，均在.verification内。

## 仍待选择

音乐按新增要求完成检索，候选见 MUSIC_CANDIDATES.md。当前BGM未擅自替换。贴图仍等待用户选择，不能把灰色素材底色直接作为正式亮白建筑颜色。

本轮未导出网页、未提交推送。关闭旧试玩窗口后重新运行D盘Maze03即可查看；F10纯画面、F11全屏。
