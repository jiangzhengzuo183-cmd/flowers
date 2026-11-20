extends SceneTree
const Gateway := preload("res://scripts/story/maze_gateway.gd")
const Report := preload("res://scripts/story/designed_report.gd")
var failures := 0
var result_count := 0
var received: Dictionary

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/report_artwork.json"))
	var unique: Dictionary = {}
	for id: String in map:
		unique[map[id]] = true
		check(ResourceLoader.exists("res://assets/report-final/"+map[id]),"报告图片必须存在："+id)
	check(unique.size() == 13,"13张成品图片全部映射")
	for file: String in unique:
		var page := Report.new()
		page.artwork_path = "res://assets/report-final/"+file
		root.add_child(page)
		page.size = Vector2(1600,900)
		await process_frame
		check(page.frame.get_node("FinalReportArtwork").texture.get_width() >= 1600,"报告必须使用原成品图")
		check(Rect2(Vector2.ZERO,page.DESIGN_SIZE).encloses(page.continue_button.get_rect()),"继续按钮不可越界")
		page.queue_free()
		await process_frame
	var fixture := Control.new()
	fixture.set_script(preload("res://tests/maze_interface_fixture.gd"))
	var packed := PackedScene.new()
	check(packed.pack(fixture) == OK,"构造独立迷宫接口测试场景")
	fixture.free()
	for number in [1,2,3]:
		var gate := Gateway.new()
		gate.round_number = number
		gate.story_scene = Gateway.slots()[str(number)].story_scene
		gate.scene_override = packed
		gate.finished.connect(func(value: Dictionary) -> void: result_count+=1;received=value)
		root.add_child(gate)
		check(gate.active_game.context.round_number == number,"独立迷宫接收到正确轮次")
		gate.paused = true
		check(gate.active_game.paused,"弹窗暂停传递给迷宫")
		gate.active_game.finished.emit({"seconds":12.5,"score_valid":true})
		gate.complete({"seconds":99.0})
		check(received.round_number == number and received.seconds == 12.5,"完成数据与轮次精确回传")
		await process_frame
	check(result_count == 3,"每个迷宫只完成一次")
	var chapter := preload("res://scripts/story/continuation_chapter.gd").new()
	root.add_child(chapter)
	await process_frame
	chapter.narrative.enter_scene(8)
	chapter.loaded_scene = -1
	chapter.narrative.finish_scene()
	chapter._refresh()
	await process_frame
	check(is_instance_valid(chapter.designed_page),"报告节点直接打开报告图片")
	check(not chapter.end_screen.visible and chapter.end_screen.get_child_count() == 0,"无深色报告菜单")
	chapter.designed_page.request_continue()
	check(chapter.narrative.scene().id == "p3-maze","读完报告直接进入后续剧情")
	chapter.queue_free()
	await process_frame
	print("REPORT AND MAZE CHECK: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
