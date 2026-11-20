# 完整视觉小说更新接入

已将 feature/chapter1-interaction 的 80fed5e 导入 godot/modules/visual_novel，替换原 b00e20c 导入版。新版纸面工具栏、设置及原生进步报告书和报告素材已接入。主菜单仍使用本项目 MainMenu.tscn，开始游戏经保留的 modules/loading 进入 VisualNovel.tscn。

保留成品迷宫三 scenes/levels/Maze03.tscn → modules/maze03_final/scene.gd，以及真实竞速控制器、HUD、入场镜头和321GO。story_race 使用本项目桥接器，不用来源分支的旧迷宫实现；完成后回传原结果字段及 outcome、charlie_time、mouse_time、round_number。保留已有剧情与迷宫音频隔离，以及加载界面。

实际运行 check_new_story_smoke.gd：主菜单经加载进入新版剧情、新纸面UI、原生报告书打开、再经加载进入成品Maze03和Race模式，共7项通过。实际截图在 docs/screenshots/main_menu/new-story-ui.png、new-report-book.png、new-story-maze03.png。尚未把完整剧情逐句通关、视频播放及所有报告页翻阅记为已验证；综合场景退出仍有既有ObjectDB资源提示。

运行：停止旧窗口F8，F5，从主菜单开始游戏。源文件替换不会热更新已经在运行的旧游戏。当前代码与资源更新已在本工程中生效，不需要改为打开朋友独立工程。
