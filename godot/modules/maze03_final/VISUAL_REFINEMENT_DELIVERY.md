# Maze 03 视觉与路线修正记录

正式工程：D:/ChatGPT/献给阿尔吉侬的花束/godot/project.godot。
运行入口：D:/ChatGPT/献给阿尔吉侬的花束/godot/scenes/levels/Maze03.tscn。

## 当前保留的实现

- 池边围墙厚度 0.16m、高度 0.80m、圆角半径 0.85m；侧面连续平滑。四角补齐原色地面，水面裁切到圆角轮廓，移除旧方形池沿。
- 移除额外伸出的连接体；仅延伸四处已有墙体：西侧 H_7_5、H_11_5，北侧 V_4_11，东侧 H_8_14。南北池边保留居中出入口，主路线仍连续。
- 十块分离步石改为略不规则圆形并左右错落；厚度 0.105m，尺寸约 0.8×0.74m，保留可见水面间隙，正常行走和跑步均已实测。
- 完全移除入口 H_19_0、H_19_1 的墙体与碰撞。
- 撤除新增的八组中层巨构和五组额外孤立辅助体块；保留六组已选定的主要巨构。
- 原有十七个建筑群重新布置：八组前层建筑群约 216–244m，九组后层建筑群约 268–298m；通过横向展开、不同高度和遮挡关系承接主要巨构，避免再次追加一批大体块。远景减弱过度淡化。
- 方块边长 0.42m、倾斜 45°、浅青蓝半透明、自发光；中心高度 1.22m，按当前查理模型头部位置校准，保留轻微悬浮和旋转。
- 方块内置小型光核及一盏有限范围蓝色灯。中央光束在方块附近收束，在方块体内退让、上下软衔接；连接高度随悬浮更新，亮度与光核同步缓慢变化。
- 室内地面和墙面保持原材质、原颜色。撤销造成黑地面的独立材质替换。仅通过相机局部环境底光（0.38→0.24）、顶部聚光、阴影遮光层及蓝色局部投光加强室内明暗，室外曝光和天空保持原配置。
- 半月使用球面明暗及柔和月相边界。屏障取消预设人形外圈，使用真实深度交界高光并保留自动加速。
- 巨构保留旋转和悬浮；每轮两次大震、可多次小震及白色碎片粉尘保留。风线已恢复先前的 44 条、两个批次；九处全局流动空气保留。
- 背景音乐、人物移动、跳跃、脚印、全屏及其他迷宫均沿用现有系统。没有加入新的圣堂玩法。

## 运行检查

- MAZE03 FINAL PASS failures=0 retained_walls=272/338；脚本/着色器错误 0。日志：[maze03-revision-routes.log](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-revision-routes.log)
- CONTACT ATMOSPHERE PASS failures=0；脚本/着色器错误 0。日志：[maze03-contact-revision-native.log](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-contact-revision-native.log)
- POOL REVISION PASS failures=0；脚本/着色器错误 0。日志：[maze03-pool-revision-native.log](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-pool-revision-native.log)

检查包含完整 A/B 路线、禁止横穿池边与跳过围墙、四角地面碰撞、正常走/跑通过步石、入水跑跳反馈、六个屏障及接触恢复、非叠加加速、大小震动、重置、F10/F11、室内原材质、悬浮和旋转。

项目保护：对模块外 241 个已记录源文件进行比对，变化 0 个。未提交或推送。未重新导出 Web，也没有宣称浏览器帧率达标。

## 实际画面

- [室内与方块](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-pool-revision/interior_lighting_final.png)
- [精简后的圆角池边](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-pool-revision/pool_northwest_corner.png)
- [分离步石](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-pool-revision/rounded_stones.png)
- [入口视角](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-pool-revision/entry_charlie_view.png)
- [前后建筑层次](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-pool-revision/depth_direction_2.png)
- [半月](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-contact-atmosphere/daytime_half_moon.png)
- [实际屏障接触](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-contact-atmosphere/barrier_body_contact.png)

## 文件变化（相对于本轮开始备份）

### 新增

- [check_contact_atmosphere.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/check_contact_atmosphere.gd)
- [check_pool_revision.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/check_pool_revision.gd)
- [day_moon.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/day_moon.gd)
- [day_moon.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/day_moon.gdshader)
- [energy_frame_finish.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/energy_frame_finish.gd)
- [energy_socket.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/energy_socket.gdshader)
- [hover_cube.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/hover_cube.gd)
- [hover_cube.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/hover_cube.gdshader)
- [interior_atmosphere.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/interior_atmosphere.gd)
- [interior_camera_light.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/interior_camera_light.gd)
- [interior_dust.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/interior_dust.gdshader)
- [interior_ray.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/interior_ray.gdshader)
- [pool_boundary.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/pool_boundary.gd)
- [sanctuary_interior.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/sanctuary_interior.gd)
- [small_stone_details.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/small_stone_details.gd)

### 修改

- [atmosphere.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/atmosphere.gd)
- [barrier.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/barrier.gd)
- [beam.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/beam.gdshader)
- [check_final.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/check_final.gd)
- [courtyard.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/courtyard.gd)
- [earthquake.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/earthquake.gd)
- [enclosure.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/enclosure.gd)
- [energy.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/energy.gdshader)
- [generator.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/generator.gd)
- [geometric_stone.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/geometric_stone.gdshader)
- [horizon_haze.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/horizon_haze.gdshader)
- [landscape.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/landscape.gd)
- [megastructure_motion.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/megastructure_motion.gd)
- [sanctuary.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/sanctuary.gd)
- [scene.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/scene.gd)
- [sound.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/sound.gd)
- [surface_finish.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/surface_finish.gd)
- [water.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/water.gdshader)

### 删除

- [middle_distance.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/middle_distance.gd)

本记录：D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/VISUAL_REFINEMENT_DELIVERY.md。新增脚本对应的 Godot UID 为编辑器生成的配套文件。

## 待人工验收

视觉风格、远景层次及室内光影仍以实际游玩验收为准。网页导出需要另外更新后才能包含本轮修正；本轮验收依据是 D 盘正式工程的 Godot 实际运行。
