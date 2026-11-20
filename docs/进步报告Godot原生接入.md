# 进步报告：Godot 原生接入

当前使用 Godot 原生 Control、SubViewport 和纸页网格绘制，运行不依赖浏览器、iframe 或 JavaScriptBridge。指定字体直接绘制正文，原照片、纸片与文字随所属纸页运动。

书本宽度为16:9画面的88%，桌面使用用户提供的木纹原图。没有网页工具栏、日期下拉、放大阅读或减少动态选项。剧情中只显示右下角“继续”；回看支持点击左右页翻阅、方向键及“合上笔记本”。

主线21个报告事件对应15组正式跨页；完整对应表见 report-book-map.md。3月29日至4月28日的报告9—14全部纳入，并保留4月6日、8日的分阶段解锁。解锁依据剧情实际事件，不按最大日期推断；未解锁文字和关联插画不进入当前页面。打开期间暂停底层剧情，合书完成后只推进一次。回看关闭不推进剧情。

入口：正常运行 godot/project.godot（F5）；右上角书本为已解锁回看。根目录“预览报告书.cmd”是独立美术预览，明确开放全书，不代表主游戏的解锁进度。

新增核心文件：report_book.gd（原生暂停/恢复）、report_book_frame.gd（原生开合、曲面翻页与简化控件）、report_leaf.gd（可编辑文字绘制）、report_book_catalog.gd（解锁）、data/report_book_pages.json（日期、文字和坐标）、assets/report-book（原图与分阶段素材）。主线连接在 bakery_chapter.gd、day01_scene_view.gd、continuation_chapter.gd、experience_runtime.gd。

素材再构建：先执行 node scripts/build-report-native.cjs，再用 Godot 执行 res://tests/build_report_book_assets.gd；这两步不需要浏览器。修改文字、字号或坐标可编辑 report_book_pages.json；不要把含文字的整张跨页截图作为一张纸页。

本轮按用户最新要求收尾到进步报告9，后续已有报告保持原状，不纳入本轮核对。

阴影在 report_book_frame.gd 中绘制：静止时使用原书本透明轮廓生成的接触阴影与柔和外投影；开合时根据封壳角度改变投影范围、位置和柔软程度，并衔接静止阴影。六张 shadow-*.png 由 tests/build_report_shadows.gd 生成，不改动原始书本美术。

本轮验证入口：tests/check_native_report_book.gd、tests/check_report9_flow.gd。前者检查原生开合、左右翻页、快速点击、窗口缩放、分阶段解锁与暂停恢复；后者实际实例化主线报告入口，逐个核对到报告9的剧情节点、合书完成后推进，以及重复“继续”不会重复推进。该流程核对通过直接进入剧情节点进行，不代表完整试玩全部对话和迷宫。原生截图和日志位于 .verification/native-report-book 和 .verification。保留已有原始美术，不覆盖源图。

当前主项目尚无完整的跨会话剧情存档；解锁随当前剧情会话和现有状态恢复，不另存一份可能超前的浏览器解锁记录。原网页预览保留作素材参考，已从正式报告入口解绑。
