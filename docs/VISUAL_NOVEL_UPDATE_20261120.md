# 完整视觉小说更新接入

已将 feature/chapter1-interaction 的 80fed5e 导入 godot/modules/visual_novel，替换原 b00e20c 导入版。新版纸面工具栏、设置及原生进步报告书和报告素材已接入。主菜单仍使用本项目 MainMenu.tscn，开始游戏经保留的 modules/loading 进入 VisualNovel.tscn。

保留成品迷宫三 scenes/levels/Maze03.tscn → modules/maze03_final/scene.gd，以及真实竞速控制器、HUD、入场镜头和321GO。story_race 使用本项目桥接器，不用来源分支的旧迷宫实现；完成后回传原结果字段及 outcome、charlie_time、mouse_time、round_number。保留已有剧情与迷宫音频隔离，以及加载界面。

实际运行 check_new_story_smoke.gd：主菜单经加载进入新版剧情、新纸面UI、原生报告书打开、再经加载进入成品Maze03和Race模式，共7项通过。实际截图在 docs/screenshots/main_menu/new-story-ui.png、new-report-book.png、new-story-maze03.png。尚未把完整剧情逐句通关、视频播放及所有报告页翻阅记为已验证；综合场景退出仍有既有ObjectDB资源提示。

运行：停止旧窗口F8，F5，从主菜单开始游戏。源文件替换不会热更新已经在运行的旧游戏。当前代码与资源更新已在本工程中生效，不需要改为打开朋友独立工程。

## 纸面独白结束时的遗留按钮修复

复现到第一天“我想试一试。”结束时，bakery_chapter.advance 仍访问已经取消的 day01_view.report_button.grab_focus()，产生空对象调用。现在仅对有效且可见的旧按钮设置焦点；新版报告书仍按原流程自动打开，不修改剧情和报告内容。另外补回新版UI运行时对剧情音频宿主的登记，保持迷宫音频隔离。

实际原生回归：check_paper_transition.gd 逐句播放四条纸面独白，等待真实报告展开与合上动画，再进入 continuation_chapter；check_day01_complete.gd 从第一天开篇，遍历三个人物、三个物件、夜校与爱丽丝对话、纸面独白和报告，进入 d2-outside。修复前日志含空对象 grab_focus 错误，修复后两条路径没有 SCRIPT ERROR 或 ERROR。新增 check_paper_transition.ps1 检查引擎日志，防止游戏退出码为0时漏掉脚本报错。
