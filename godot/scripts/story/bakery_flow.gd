extends RefCounted
## DAY 01 六段流程状态机；界面通过阅读、人物及物件操作推进。
const PEOPLE_PATH := "res://data/bakery.json"
const FLOW_PATH := "res://data/bakery_flow.json"
const EXTENSION_PATH := "res://data/day01_extension.json"

var data: Dictionary = {}
var people: Array = []
var section := "opening"
var phase := "reading"
var index := 0
var queue: Array = []
var return_phase := ""
var active_person := ""
var active_object := ""
var completed_people: Array[String] = []
var completed_objects: Array[String] = []
var history: Array[Dictionary] = []
var notebook_text := ""
var notebook_followup_done := false
var alice_done := false
var report_opened := false
var report_completed := false
var error := ""

func _init(people_path: String = PEOPLE_PATH, flow_path: String = FLOW_PATH, extension_path: String = EXTENSION_PATH) -> void:
	if not FileAccess.file_exists(people_path) or not FileAccess.file_exists(flow_path) or not FileAccess.file_exists(extension_path):
		error = "面包店剧情资料缺失。"
		return
	var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(people_path))
	var f: Variant = JSON.parse_string(FileAccess.get_file_as_string(flow_path))
	var extension: Variant = JSON.parse_string(FileAccess.get_file_as_string(extension_path))
	if not p is Dictionary or not f is Dictionary or not _valid_data(p, f) or not extension is Dictionary or not _valid_extension(extension):
		error = "面包店剧情读取失败，请检查 data/bakery.json 与 data/bakery_flow.json。"
		return
	data = f
	data.merge(extension)
	people = p.characters
	data.intro = p.intro
	_begin(data.opening)

func _valid_extension(value: Dictionary) -> bool:
	var school: Variant = value.get("school")
	return school is Dictionary and _valid_lines(school.get("intro")) and _valid_lines(school.get("alice")) and school.get("lesson") is String and _valid_lines(value.get("home")) and value.get("report") is String and value.get("report_title") is String and value.get("report_date") is String

func _valid_lines(value: Variant) -> bool:
	if not value is Array or value.is_empty():
		return false
	for line: Variant in value:
		if line is Dictionary:
			if not line.get("speaker") is String or not line.get("text") is String:
				return false
		elif not line is Array or line.size() != 2 or not line[0] is String or not line[1] is String:
			return false
	return true

func _valid_data(p: Dictionary, f: Dictionary) -> bool:
	if not _valid_lines(p.get("intro")) or not p.get("characters") is Array or p.characters.size() != 3:
		return false
	var ids: Array[String] = []
	for entry: Variant in p.characters:
		if not entry is Dictionary or not entry.get("id") is String or not entry.get("name") is String or not entry.get("portrait") is String or not _valid_lines(entry.get("lines")):
			return false
		if entry.id.is_empty() or entry.id in ids:
			return false
		ids.append(entry.id)
	for id: String in ["opening", "exterior", "notebook_followup", "closing", "leaving"]:
		if not _valid_lines(f.get(id)):
			return false
	if not f.get("objects") is Dictionary:
		return false
	for id: String in ["bread", "orders", "notebook"]:
		var item: Variant = f.objects.get(id)
		if not item is Dictionary or not item.get("name") is String or not _valid_lines(item.get("lines")):
			return false
	return true

func _begin(lines: Array, after: String = "") -> void:
	queue = lines
	index = 0
	phase = "reading"
	return_phase = after
	_record()

func person(id: String) -> Dictionary:
	for entry: Dictionary in people:
		if entry.id == id:
			return entry
	return {}

func departed(id: String) -> bool:
	return id in completed_people and bool(person(id).get("leaves_after", false))

func current_line() -> Dictionary:
	if not error.is_empty():
		return {"speaker": "提示", "text": error}
	if phase == "people":
		return {"speaker": "查理（内心独白）", "text": "我得开始收拾了。今天还有很多事情要做。" if completed_people.size() == 3 else "先和大家说说话吧。"}
	if phase == "objects":
		return {"speaker": "查理（内心独白）", "text": "面包架需要整理，今天的订单也要核对。我的笔记本就放在工作台上。"}
	if phase == "notebook":
		return {"speaker": "查理的笔记本", "text": "我把每天需要做的事情都写在这里。"}
	if phase == "school":
		return {"speaker": "夜校", "text": "点击爱丽丝老师，开始今晚的学习。"}
	if phase == "lesson":
		return {"speaker": "旁白", "text": data.school.lesson}
	if phase == "complete":
		return {"speaker": "CHAPTER 01 · DAY 01", "text": "面包店的灯\n一个新的机会，正在等待着他。\nEND OF DAY 01"}
	if phase in ["report","next_chapter"]:
		return {"speaker":data.report_title,"text":data.report}
	var line: Variant = queue[index]
	return line if line is Dictionary else {"speaker": line[0], "text": line[1]}

func advance() -> void:
	if phase != "reading" or not error.is_empty():
		return
	if index < queue.size() - 1:
		index += 1
		_record()
		return
	if return_phase == "people":
		if active_person not in completed_people:
			completed_people.append(active_person)
		active_person = ""
		phase = "people"
	elif return_phase == "objects":
		if active_object not in completed_objects:
			completed_objects.append(active_object)
		if active_object == "notebook":
			notebook_followup_done = true
		active_object = ""
		phase = "objects"
	elif return_phase == "notebook":
		# 保留查看本子和续剧情，取消填写、保存的中间环节。
		if notebook_followup_done:
			active_object = ""
			phase = "objects"
		else:
			_begin(data.notebook_followup,"objects")
	elif return_phase == "home":
		alice_done = true
		active_person = ""
		section = "home"
		_begin(data.home)
	else:
		match section:
			"opening":
				section = "exterior"
				_begin(data.exterior)
			"exterior":
				section = "intro"
				_begin(data.intro)
			"intro":
				section = "people"
				phase = "people"
			"closing":
				section = "leaving"
				_begin(data.leaving)
			"leaving":
				section = "classroom"
				_begin(data.school.intro)
			"classroom":
				phase = "school"
				start_alice()
			"home":
				section = "complete"
				phase = "complete"

func start_alice() -> bool:
	if phase != "school":
		return false
	section = "alice"
	active_person = "alice"
	_begin(data.school.alice, "home")
	return true

func start_report() -> bool:
	if phase != "complete" or report_completed: return false
	phase = "report"
	if not report_opened:
		report_opened = true
		_record()
	return true

func finish_report() -> bool:
	if phase != "report" or report_completed: return false
	report_completed = true
	phase = "next_chapter"
	return true

func finish_lesson() -> bool:
	if phase != "lesson":
		return false
	section = "home"
	_begin(data.home)
	return true

func start_talk(id: String) -> bool:
	if phase != "people" or person(id).is_empty() or departed(id):
		return false
	active_person = id
	_begin(person(id).lines, "people")
	return true

func start_object(id: String) -> bool:
	if phase != "objects" or not data.objects.has(id):
		return false
	active_object = id
	_begin(data.objects[id].lines, "notebook" if id == "notebook" else "objects")
	return true

func close_notebook() -> bool:
	if phase != "notebook":
		return false
	if notebook_followup_done:
		active_object = ""
		phase = "objects"
	else:
		_begin(data.notebook_followup, "objects")
	return true

func continue_main() -> bool:
	if phase == "people":
		section = "objects"
		phase = "objects"
		return true
	if phase == "objects":
		section = "closing"
		_begin(data.closing)
		return true
	return false

func _record() -> void:
	var entry: Dictionary = current_line().duplicate()
	entry["scene"] = section
	history.append(entry)
