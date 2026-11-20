extends SceneTree
const Flow := preload("res://scripts/story/continuation_flow.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var flow := Flow.new()
	flow.enter_scene(1)
	while flow.phase == "reading": flow.advance()
	check(flow.phase == "ink_observation","实验指令后自动进入墨迹交互")
	check(flow.active_item == "ink","自动入口与手动入口复用同一状态")
	flow.end_ink_observation({"viewed":["I","IV"]})
	while flow.phase == "reading": flow.advance()
	check(flow.phase == "explore","测试后恢复原探索，不重复自动打开")
	check(flow.ink_observed,"墨迹测试结果保存")
	flow.enter_scene(2)
	check(flow.scene().items.is_empty(),"实验室移除角落尼姆及所有旧物件入口")
	flow.enter_scene(4)
	check(flow.scene().items.is_empty(),"删除动机记录纸页面")
	flow.enter_scene(13)
	flow.advance()
	flow.advance()
	check(flow.index == 2,"先阅读跳舞引导旁白")
	flow.advance()
	check(flow.phase == "video","跳舞旁白后进入视频")
	var history := flow.history.size()
	flow.end_video()
	check(flow.phase == "reading" and flow.index == 3,"视频结束接回乔的下一句对白")
	flow.end_video()
	check(flow.index == 3 and flow.history.size() == history+1,"重复结束事件不能跳过第二句")
	for number in range(flow.data.scenes.size()):
		if flow.data.scenes[number].id == "p4-ink": flow.enter_scene(number); break
	while flow.phase == "reading": flow.advance()
	check(flow.phase == "explore","第二次测试先保留误会与说明剧情")
	flow.start_item("nemur")
	while flow.phase == "reading": flow.advance()
	check(flow.phase == "ink_observation","听完教授说明后自动继续第二次墨迹测试")
	print("STORY FLOW V1 CHECK: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
