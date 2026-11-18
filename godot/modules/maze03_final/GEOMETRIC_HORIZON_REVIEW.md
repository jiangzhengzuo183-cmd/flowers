# Maze 03 简洁几何远景调整记录

日期：2026-11-16。正式工程：D:\ChatGPT\献给阿尔吉侬的花束\godot\project.godot。

## 本轮结果

依照已选建筑参考提炼轮廓，撤下上一轮近处柱梁、六段实体连接廊和复杂堆叠主体。远景形成三组主要几何体、五组较低较弱的辅助体块，以及原有十七组最外层轮廓。没有改动迷宫内部建筑、角色、路线、水池、天空基础颜色或光照配置。

- 东北：厚实弧形体，连续曲面，一处主要开口。
- 西侧：完整白色体块，一个贯穿椭圆切口。
- 东南：宽阔、低矮的椭圆圆顶。
- 辅助层：五组安静的低体块或弧形片段，不再用梁柱把它们连接。
- 三个主体中心距离迷宫中心约188–208个世界单位；所有新增实体的包围范围均在中心120个世界单位以外。原地图宽约46个单位，近层不再安排巨构。
- 最外层原有八组、九组建筑轮廓实例进一步后退；源模型未修改，已有隐藏窗光和去尖顶的实例处理继续保留。
- 新增实体采用不透明几何表面，底部融入天空与低处云雾；没有半透明穿透建筑的效果。
- 远景明暗按现有太阳方向计算，采用克制的白色与蓝灰背光。没有新增实时灯光或阴影贴图，也没有增加实体碰撞。
- 新远景继续参与现有镜面水池的反射。

## 文件

修改：

- godot/modules/maze03_final/enclosure.gd：远景体块组合、距离、局部云雾和镜面可见层。
- godot/modules/maze03_final/landscape.gd：撤下旧复杂巨构，调整原有外层轮廓的实例距离。
- godot/modules/maze03_final/check_final.gd：远景距离、材质、无碰撞、无额外灯光等回归检查；原玩法检查保留。
- godot/modules/maze03_final/review_visuals.gd：新远景的实际游戏截图视角和输出位置。

新增：

- godot/modules/maze03_final/geometric_masses.gd：封闭弧形实体、单切口体块和圆顶网格。
- godot/modules/maze03_final/geometric_stone.gdshader：不透明远景白色明暗与大气透视。
- 本记录。

没有删除模型或资源。旧版本及旧截图已备份至 backups/maze03-before-simple-geometry-20261116/。

## 实际验证

Godot 4.7.2 Compatibility，桌面原生图形运行，NVIDIA RTX 4060 Laptop。

1. 带 --routes 的完整路线回归：PASS，failures=0。
2. 原生图形功能回归：PASS，failures=0。
3. 原有274段保留墙体与已批准的移除记录相符；这轮没有新增墙体移除。
4. 六处屏障、加速刷新、角色移动跳跃、步石通行、水中跑步与跳跃波纹水花、音乐、F10纯画面及F11全屏检查通过。
5. 新远景没有碰撞，不产生覆盖迷宫的远处巨构阴影。
6. 四方向实际跟随镜头和多组总览截图已输出并检查。
7. 修改前记录的281个受保护源码、场景和配置文件校验一致，意外变化为0。

日志：

- .verification/maze03-simple-geometry-routes.log
- .verification/maze03-simple-geometry-native.log
- .verification/maze03-simple-geometry-render.log

原生测试采样平均帧间隔约6.02ms，2489次绘制、609302个图元。此数据来自固定步长测试流程，不代表各设备或网页稳定帧率。本轮未导出或更新网页，也未提交推送GitHub。

## 图片

实际游戏截图存放于 .verification/maze03-simple-geometry/：

- hero.png、hero_west.png、global_0.png 至 global_3.png：整体远景。
- horizon_northeast.png、horizon_west.png、horizon_southeast.png、horizon_southwest.png：主要方向轮廓。
- charlie_north.png、charlie_east.png、charlie_south.png、charlie_west.png：查理实际跟随镜头。
- mirror_pool.png：水池和反射。

## 试玩

关闭旧试玩窗口，在D盘正式工程重新运行Maze03场景，或从现有迷宫选择界面进入迷宫三。F10切换纯游戏画面，F11切换全屏，Esc恢复。

本轮交付的是可运行的远景调整，轮廓、大小和距离仍需人工视觉验收。
