extends SceneTree
## Exercises the real third-maze route, including its existing 3D implementation.
const Chapter := preload("res://scripts/story/continuation_chapter.gd")
var failures := 0
var requested_context: Dictionary = {}
var elapsed := 0.0
func _initialize() -> void:
	call_deferred("run")
func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 20:
		push_error("Third-maze check timed out")
		quit(1)
	return false
func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		push_error(why)
func frames() -> void:
	await process_frame
	await process_frame
func run() -> void:
	root.size = Vector2i(1600,900)
	var chapter := Chapter.new()
	var number := -1
	for at in range(chapter.narrative.data.scenes.size()):
		if chapter.narrative.data.scenes[at].id == "p4-maze": number = at
	check(number > 0,"第三次迷宫必须存在于完整主线")
	if number < 0:
		chapter.free()
		quit(1)
		return
	chapter.narrative.enter_scene(number)
	chapter.maze_requested.connect(func(round_number: int, context: Dictionary) -> void:
		check(round_number == 3,"主线请求正确的第三轮")
		requested_context = context)
	root.add_child(chapter)
	chapter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await frames()
	check(chapter.narrative.data.scenes[number-1].id == "p3-volume","入口位于调低教学机器音量之后")
	while chapter.narrative.phase == "reading": chapter.advance()
	check(chapter.continue_button.visible and "迷宫" in chapter.continue_button.text,"引导对话后出现迷宫入口按钮")
	check(not chapter.narrative.start_item("mouse"),"赛后笼子对话不在比赛前提前解锁")
	chapter.continue_main()
	await create_timer(1.8).timeout
	check(chapter.narrative.phase == "maze" and is_instance_valid(chapter.race),"实际主线进入迷宫网关")
	check(requested_context.get("slot_id") == "maze_03" and requested_context.get("story_scene") == "p4-maze","独立第三关接收到正确槽位和剧情上下文")
	if not is_instance_valid(chapter.race):
		chapter.queue_free()
		quit(1)
		return
	var game: Control = chapter.race.active_game
	check(game.round_number == 3 and game.maze.loaded_ok,"现有3D迷宫以第三次测试模式成功加载")
	check(not game.finish_button.disabled or not game.player_done,"比赛不会在进入时自动完成")
	# The existing development callback is explicitly unscored; no real progress is saved.
	chapter.race.development_finish()
	await frames()
	check(chapter.narrative.maze_results.has("3"),"第三轮完成结果回到剧情模型")
	check(chapter.narrative.maze_results.get("3",{}).get("score_valid",true) == false,"开发验收不伪造有效成绩")
	check(chapter.narrative.phase == "reading" and "查理获胜" in chapter.narrative.current_line().text,"完成后进入既定赛后剧情")
	while chapter.narrative.phase == "reading": chapter.advance()
	check(chapter.narrative.start_item("mouse"),"比赛完成后解锁阿尔吉侬笼子对话")
	while chapter.narrative.phase == "reading": chapter.advance()
	chapter.continue_main()
	await create_timer(1.8).timeout
	check(chapter.narrative.last_report == "report9" and "report9" in chapter.narrative.unlocked_reports,"第三轮后正确解锁进步报告9")
	check(is_instance_valid(chapter.report_book) or is_instance_valid(chapter.designed_page),"Godot原生版打开报告电子书或保留的报告页")
	if is_instance_valid(chapter.report_book):
		check(chapter.report_book.request.currentReport == "report9","原生电子书对应报告9")
		# Headless route check invokes the same completion callback without rendering page turns.
		chapter.report_book._returned("completed")
	elif is_instance_valid(chapter.designed_page): chapter.designed_page.request_continue()
	await frames()
	check(chapter.narrative.scene().id == "p4-school","读完报告接回夜校文字学习剧情")
	chapter.queue_free()
	await frames()
	print("THIRD MAZE STORY ROUTE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
