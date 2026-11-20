extends Control
## Shared boundary for three independently authored maze scenes.
signal requested(round_number: int, context: Dictionary)
signal finished(result: Dictionary)
signal cancelled
const LEGACY := preload("res://scripts/story/story_race.gd")
const SLOTS := "res://data/maze_slots.json"
var round_number := 1
var story_scene := ""
var scene_override: PackedScene
var active_game: Control
var resolved := false
var paused := false:
	set(value):
		paused = value
		if is_instance_valid(active_game) and "paused" in active_game: active_game.set("paused",value)

static func slots() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SLOTS))

func _ready() -> void:
	var entry: Dictionary = slots().get(str(round_number),{})
	assert(not entry.is_empty(),"Maze slot must be 1, 2 or 3")
	var context := {"round_number":round_number,"slot_id":entry.id,"story_scene":story_scene}
	requested.emit(round_number,context)
	var resource: PackedScene = scene_override
	if resource == null and not entry.scene_path.is_empty(): resource = load(entry.scene_path) as PackedScene
	if resource != null:
		active_game = resource.instantiate() as Control
		assert(active_game != null and active_game.has_signal("finished"),"Maze root must be Control with finished(result: Dictionary)")
	else:
		active_game = LEGACY.new()
		active_game.round_number = round_number
	if active_game.has_method("configure"): active_game.call("configure",context)
	active_game.finished.connect(complete)
	if active_game.has_signal("cancelled"): active_game.connect("cancelled",cancel)
	add_child(active_game)
	active_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func complete(result: Dictionary) -> void:
	if resolved: return
	if result.get("withdrawn",false) and round_number != 2: return
	resolved = true
	var payload := result.duplicate(true)
	payload["round_number"] = round_number
	payload["slot_id"] = slots()[str(round_number)].id
	# Missing scores are not silently treated as measured scores.
	payload["score_valid"] = result.get("score_valid",false)
	finished.emit(payload)
	queue_free()

func cancel() -> void:
	if resolved: return
	resolved = true
	cancelled.emit()
	queue_free()

func development_finish() -> void:
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/experience.json"))
	if settings.get("development",false) and is_instance_valid(active_game) and active_game.has_method("development_finish"):
		active_game.call("development_finish")
