extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var hud := preload("res://scripts/story/task_hud.gd").new()
	root.add_child(hud)
	hud.sync("面包店室内 · 日","people","与面包店内的人物交谈","01 / 探索",0,false)
	check(hud.size == Vector2(300,75),"1920画布应对应360×90任务卡")
	hud.button.pressed.emit()
	check(hud.collapsed and is_equal_approx(hud.size.y,40),"收起后只保留地点横条")
	hud.sync("实验室","lab","观察桌上的罗夏墨迹卡片，与实验室里的研究人员交谈","02 / 探索",0,false)
	check(not hud.collapsed,"新目标必须自动展开")
	await process_frame
	check(hud.objective.get_line_count() >= 2,"长任务应正常换行")
	check(hud.objective.position.y+hud.objective.size.y <= hud.size.y,"任务文字不可越过纸张下边缘")
	hud.sync("实验室","lab","观察墨迹卡片","02 / 探索",1,false)
	check(hud.done,"已有流程的完成计数增加应显示勾选")
	var until := Time.get_ticks_msec() + 400
	while Time.get_ticks_msec() < until: await process_frame
	hud.sync("实验室","lab","与研究人员交谈","02 / 探索",1,false)
	check(not hud.done,"完成提示后应恢复现有下一任务")
	hud.reading_mode = true
	hud.sync("实验室","lab","与研究人员交谈","02 / 探索",1,false)
	check(not hud.objective.visible and is_equal_approx(hud.size.y,40),"阅读模式只显示地点横条")
	hud.queue_free()
	var chapter := preload("res://scripts/story/continuation_chapter.gd").new()
	root.add_child(chapter)
	await process_frame
	var cast: RefCounted = chapter.day01_view.dialogue_cast
	var source := "查理想学会阅读，也想听懂朋友们说的话。".repeat(40)
	var pages: Array[String] = chapter.runtime.paginate(source)
	check(pages.size()>1,"长对白应分页")
	check("".join(pages).replace("\n","") == source,"分页不应丢字、重复或改写对白")
	for page: String in pages:
		check(page.split("\n").size() <= 3,"每页最多三行")
		for line: String in page.split("\n"):
			check(line.length()>1,"不能留下单字行")
			check(chapter.dialogue_text.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x <= 917,"正文不得超出规范宽度")
	var solo: Array[String] = ["charlie_right"]
	cast.refresh_for(solo,"查理（内心独白）")
	var actor: TextureRect = cast.portraits.charlie_right
	check(is_equal_approx(actor.position.x+actor.size.x/2,800),"独白的查理必须居中")
	var pair: Array[String] = ["bert","charlie_right"]
	cast.refresh_for(pair,"伯特")
	check(is_equal_approx(actor.position.x+actor.size.x/2,1185),"双人对话应恢复查理右侧位置")
	check(actor.flip_h,"实验室右侧查理必须朝左看向对话者")
	chapter.queue_free()
	await process_frame
	print("STORY UI CHECK: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
