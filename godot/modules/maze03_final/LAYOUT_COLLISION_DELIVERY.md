# Maze03：碰撞、人物与中远景调整记录（2026-11-17）

正式工程：D:/ChatGPT/献给阿尔吉侬的花束/godot/project.godot。
本轮保留原有六组主体巨构，不新增巨构造型，不调整天空基础配色。

## 当前交付状态

- 隐形碰撞：墙端可见网格经过裁剪后，部分旧碰撞盒仍保留较长尺寸。现按最终可见网格边界同步碰撞盒。北池边 V_4_11 只保留原有 2.25 米可见部分对应的碰撞，删除多余的约 2.49 米隐形阻挡；没有用可见墙重新封口。
- 中远景：重新编排原有 8 组中层、9 组远层建筑群的方向、距离、高低和尺度，修正偏离模型视觉中心的锚点。让过渡建筑分布在主体巨构的间隙中，保留主体孔洞和主要轮廓。
- 人物：撤销被否定的网格顶点重涂方案；保留原始网格、法线、UV、骨骼、蒙皮和原贴图颜色。为 Maze03 实例使用同一原图的独立无块压缩副本和柔和表面材质，不修改共用人物资源。
- 跑步闪烁：逐帧截图确认入口 G1/ArchStone6 在镜头前约 5 厘米处形成大面积半透明暖色面。Maze03 局部遮挡处理增加镜头近处的平滑淡出及稳定判定，未更改镜头控制或实体碰撞。固定入口跑步测试最大相邻帧头部亮度跳变从约 0.343 降到 0.049。
- 彗星：遵循最后确认，撤掉火花、摩擦尾焰和生成素材的游戏引用，恢复简洁光核与淡青白长尾。尺寸恢复 148×11 米的远景光带；保留不加紫色的要求。弃用素材保存在 backups/maze03-rejected-comet-friction-20261117，不参与游戏场景。
- 大震：彗星完全划过、淡出后 2 秒触发，每局最多两次。小震设置保留。重开清除彗星和待触发大震状态。

## 文件

修改：
- wall_joints.gd：裁剪后碰撞同步。
- check_pool_revision.gd：删除与“保留开口、移除空气墙”最新要求冲突的一条旧封路断言。
- landscape.gd：使用独立中远景布局配置。
- character_finish.gd、charlie_clean_finish.gdshader：原模型的实例材质处理。
- occlusion.gd、wall_fade.gdshader：仅 Maze03 的镜头近处遮挡稳定处理。
- atmosphere.gd、scene.gd、earthquake.gd：彗星与原有震动事件接入。

新增：
- scenery_layout.gd（及 UID）：17 组既有建筑群的布局配置。
- sky_comet.gd、sky_comet.gdshader（及 UID）：远景彗星及渐隐。
- charlie_surface_color.jpg、其 import 文件：原人物颜色图的逐字节副本；独立无块压缩、带 mipmap 导入。

没有删除原有工程文件。Maze01、Maze02、共用人物、建筑、美术及控制资源共 260 个受保护文件，最终 SHA-256 对比全部一致。

## 实际验证

- 全地图水平碰撞/可见表面排查：8692 条射线、53798 个可见三角形，疑似无可见模型阻挡体 0；实际角色通过原北池边隐藏延长部分。
- 墙体碰撞边界：272 个普通墙体与最终可见边界匹配，池边已核对，没有恢复已裁剪的可见墙段。
- 完整 A/B 主路线、捷径、步石、屏障加速、脚印及水中反馈：check_final.gd --routes，PASS failures=0，retained_walls=272/336。
- 池边圆角、开口、步石、入口和室内回归：check_pool_revision.gd，PASS failures=0。
- 巨构运动、屏障、残影、震动与环境回归：check_contact_atmosphere.gd，原生 Compatibility 实机 PASS failures=0。
- 人物原网格/UV/骨骼对比、无块压缩纹理、入口跑步/跳跃截图、恢复后的彗星移动和淡出：check_maze03_visual_finish.gd，原生实机 PASS failures=0。
- 彗星→大震时序：两次实测延迟均为 2.0 秒，第三次彗星不增加大震，重开正确重置；PASS failures=0。

截图位于项目 .verification/maze03-layout-collision/after 和 .verification/maze03-visual-finish。
原生验证设备：RTX 4060 Laptop / OpenGL Compatibility。未在本轮重新导出或发布 Web，也没有提交、推送 Git。独立无块压缩人物贴图会增加显存占用，网页端性能需在下一次真实 Web 导出中单独核验。少数较早 headless 审计曾有进程结束时资源释放提示，最终人物与彗星原生运行日志无脚本错误。

恢复点：backups/maze03-before-layout-collision-20261117；本轮被否定的尾焰素材及代码另存备份，不继续应用。
