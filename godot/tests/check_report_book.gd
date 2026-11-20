extends SceneTree

func _initialize() -> void:
	var catalog: Array = preload("res://scripts/story/report_book_catalog.gd").entries()
	var by_id: Dictionary = {}
	for entry: Dictionary in catalog:
		assert(not by_id.has(entry.id),"Duplicate report event")
		by_id[entry.id] = entry
	var flow = load("res://scripts/story/continuation_flow.gd").new()
	var seen: Array[String] = []
	for scene: Dictionary in flow.data.scenes:
		var ids: Array = scene.get("reports",[scene.report] if scene.has("report") else [])
		for id: String in ids:
			assert(by_id.has(id),"Missing report "+id)
			assert(by_id[id].scene == scene.id,"Wrong story node "+id)
			assert(by_id[id].date == flow.data.reports[id].date,"Wrong date "+id)
			seen.append(id)
	assert(catalog.size() == seen.size()+1)
	assert(seen.find("report8-0331") < seen.find("report9"),"Chronological dates must not fabricate unlock order")
	flow.enter_scene(8)
	flow.finish_scene()
	assert(flow.unlocked_reports == ["report3"])
	assert("report4" not in flow.unlocked_reports)
	flow.continue_chapter()
	assert(flow.scene().id == "p3-maze")
	flow.finish_scene()
	assert(flow.unlocked_reports == ["report3","report4"])
	var source := FileAccess.get_file_as_string("res://scripts/story/report_book.gd")
	assert(source.contains("previous_paused") and not source.contains("JavaScriptBridge"))
	print("PASS report book: all 21 authored events mapped by node and date; shared spreads unlock separately")
	quit()
