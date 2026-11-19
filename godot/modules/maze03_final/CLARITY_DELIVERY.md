# Maze 03：远景清透度、底部过渡与小震修正

## 本轮结果

- 远景受光面保持白色，背光面由灰蓝调整为清透浅蓝；通过方向性明暗保留形体，而不是整体加曝光。建筑数量、形状和位置未增加或重排。
- 六组巨构按各自真实底部和高度控制渐变，底部在模型结束前完全融入背景；渐变随巨构旋转、浮动稳定移动。渐变边界轻微错落，半圆巨构的局部云带适当加宽，缓和直切感。
- 小震随机间隔从 18–30 秒改为 15–24 秒，首次小震约 9–15 秒。强度、持续时间和两次大震的上限保持不变。
- 人物保留相同 GLB、贴图、骨骼与动作，仅对 Maze 03 实例增加轻度贴图暗部柔化及受光补偿；颜色保持棕发、暖色衣服、蓝围裙。按照最新反馈，人物停止进一步修改，后续以稍远的游玩视角验收。
- 本轮没有修改默认相机距离、摄像机操作、天空基础颜色、地面、建筑布局或机制。

## 实际检查

- 同机位修改前后渲染：CLARITY BEFORE / AFTER PASS。
- 自然小震调度：60 秒内触发时间约 10.42、34.08、49.83 秒，间隔符合 15–24 秒范围；不计入大震数量。
- 屏障实际穿越、接触恢复、悬浮方块、大小震动、重置：CONTACT ATMOSPHERE PASS。
- 两条完整路线、移动跑跳、水面反馈、加速和全屏：MAZE03 FINAL PASS，保留墙段 272/336。
- 模块外 445 个已记录源文件及 GLB 校验：变化 0 个。Maze 01、Maze 02 和共享角色资源保持不变。
- 自然调度的 headless 检查结束时有 6 个 ObjectDB 清理警告；原生渲染检查没有脚本或着色器报错。未做浏览器帧率承诺，未重新导出 Web。

## 画面对比

- [远景修改前](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-clarity/before/south_depth.png) / [远景修改后](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-clarity/after/south_depth.png)
- [半圆底部修改前](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-clarity/before/dome_ground_transition.png) / [半圆底部修改后](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-clarity/after/dome_ground_transition.png)
- [人物修改前](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-clarity/before/charlie_lit_front.png) / [人物修改后](D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-clarity/after/charlie_lit_front.png)

## 文件

- [earthquake.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/earthquake.gd)
- [enclosure.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/enclosure.gd)
- [geometric_stone.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/geometric_stone.gdshader)
- [horizon_haze.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/horizon_haze.gdshader)
- [landscape.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/landscape.gd)
- [scene.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/scene.gd)
- [character_finish.gd](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/character_finish.gd)
- [charlie_clean_finish.gdshader](D:/ChatGPT/献给阿尔吉侬的花束/godot/modules/maze03_final/charlie_clean_finish.gdshader)

新增：character_finish.gd、charlie_clean_finish.gdshader 及配套 Godot UID；其余列出的六个源文件为修改。没有删除模型或贴图。检查记录位于 D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze03-clarity-*.log。
