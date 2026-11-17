extends RefCounted
## 后续章节的独立数据流程；不改动 DAY01 状态。
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/continuation.json"))
var scene_index := 0
var phase := "reading"
var queue: Array = []
var index := 0
var after := "explore"
var active_item := ""
var completed: Dictionary = {}
var history: Array = []
var maze_results: Dictionary = {}
var notes: Array[String] = []
var volume := 1.0
var volume_adjusted := false
var unlocked_reports: Array[String] = []
var ink_observed := false
var ink_result: Dictionary = {}
var report_cursor := 0
var ink_observations: Dictionary = {}
var last_report := ""

func _init() -> void:
	# Append the supplied chapter without rewriting the confirmed earlier parts.
	var chapter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter4.json"))
	data.scenes.append_array(chapter.scenes)
	data.reports.merge(chapter.reports)
	data.assets.backgrounds.merge(chapter.assets.backgrounds)
	enter_scene(0)

func scene() -> Dictionary:
	var current: Dictionary = data.scenes[scene_index]
	if current.has("reports"):
		current=current.duplicate()
		current.report=current.reports[report_cursor]
	return current

func begin(lines: Array, next_phase: String) -> void:
	queue = lines
	index = 0
	after = next_phase
	phase = "reading" if not queue.is_empty() else next_phase
	if phase == "reading": _remember()

func enter_scene(number: int) -> void:
	scene_index = number
	report_cursor = 0
	active_item = ""
	if number >= data.scenes.size():
		phase = "complete"
		return
	begin(scene().intro,"explore")

func current_line() -> Dictionary:
	if phase != "reading": return {"speaker":"","text":""}
	return {"speaker":queue[index][0],"text":queue[index][1]}

func advance() -> void:
	if phase != "reading": return
	if index+1 < queue.size():
		index += 1
		_remember()
	else:
		phase = after
		if after == "explore" and not active_item.is_empty():
			completed[str(scene_index)+":"+active_item] = true
			active_item = ""
		if after == "finish_scene": finish_scene()

func start_item(id: String) -> bool:
	if phase != "explore": return false
	for item: Dictionary in scene().items:
		if item.id == id:
			if item.get("available_after_maze",false) and not maze_results.has(str(int(scene().maze))): return false
			active_item = id
			if (scene().id == "d2-ink" and id == "ink") or item.get("kind","") == "ink":
				phase = "ink_observation"
				return true
			if item.get("kind","") in ["note","volume","words","archive"]:
				phase = item.kind
			else:
				begin(item.lines,"explore")
			return true
	return false

func end_ink_observation(result: Dictionary) -> bool:
	if phase != "ink_observation": return false
	ink_result = result.duplicate(true)
	completed[str(scene_index)+":ink"] = true
	var observation_id: String = scene().id
	var first_observation := not ink_observations.has(observation_id)
	ink_observations[observation_id] = result.duplicate(true)
	if first_observation:
		ink_observed = true
		# Existing script only: Charlie still sees ink; repeat entries don't replay it.
		for item: Dictionary in scene().items:
			if item.id == "ink": begin(item.lines,"explore")
	else:
		active_item = ""
		phase = "explore"
	return true

func cancel_ink_observation() -> void:
	if phase == "ink_observation":
		active_item = ""
		phase = "explore"

func close_item() -> void:
	if phase in ["note","volume","words","archive"] or (phase == "explore" and not active_item.is_empty()):
		completed[str(scene_index)+":"+active_item] = true
		active_item = ""
		phase = "explore"

func set_volume(value: float) -> void:
	volume = clampf(value,0,1)
	if volume <= 0.3: volume_adjusted = true

func continue_scene() -> bool:
	if phase != "explore" or (scene().get("requires_volume",false) and not volume_adjusted): return false
	active_item = ""
	if scene().has("maze") and not maze_results.has(str(int(scene().maze))):
		phase = "maze"
	else:
		begin(scene().outro,"finish_scene")
		if phase == "finish_scene": finish_scene()
	return true

func complete_maze(result: Dictionary) -> bool:
	if phase != "maze": return false
	maze_results[str(int(scene().maze))] = result.duplicate()
	if scene().has("after_maze"):
		# Authored story results are separate from measured player scores.
		begin(scene().after_maze,"explore")
		return true
	begin(scene().outro,"finish_scene")
	if phase == "finish_scene": finish_scene()
	return true

func finish_scene() -> void:
	if scene().has("report"):
		last_report = scene().report
		if scene().report not in unlocked_reports: unlocked_reports.append(scene().report)
		phase = "chapter_end"
	else:
		enter_scene(scene_index+1)

func continue_chapter() -> void:
	if phase != "chapter_end": return
	if scene().has("reports") and report_cursor+1<scene().reports.size():
		report_cursor+=1
		last_report = scene().report
		if scene().report not in unlocked_reports:unlocked_reports.append(scene().report)
	else:enter_scene(scene_index+1)

func _remember() -> void:
	var entry: Dictionary = current_line().duplicate()
	entry["scene"] = scene().id
	history.append(entry)
