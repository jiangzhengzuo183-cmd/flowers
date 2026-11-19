extends Control
## Adapter only: the original three maze scenes own movement, clocks, boosts and results.
signal finished(result: Dictionary)
const LEVELS := ["res://scenes/levels/maze_01_greybox.tscn", "res://scenes/levels/Maze02.tscn", "res://scenes/levels/Maze03.tscn"]
var round_number := 1
var paused := false
var finished_once := false
var maze: Control
var runtime: Node
var _previous_size: Vector2i
var _previous_aspect: Window.ContentScaleAspect
var _previous_mouse := Input.MOUSE_MODE_VISIBLE
var _return_button: Button
func _ready() -> void:
	_previous_size = get_window().content_scale_size
	_previous_aspect = get_window().content_scale_aspect
	_previous_mouse = Input.mouse_mode
	name = "StoryMazeBridge"
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("restart_active_maze")
func restart_active_maze() -> void:
	if is_instance_valid(maze):
		remove_child(maze)
		maze.queue_free()
	maze = load(LEVELS[clampi(round_number-1,0,2)]).instantiate()
	add_child(maze)
	maze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bind.call_deferred()
func _bind() -> void:
	runtime = maze.game_hud
	if not is_instance_valid(runtime):
		_bind.call_deferred()
		return
	var column: VBoxContainer = runtime.play_flow.result_panel.get_child(0)
	_return_button = column.get_child(column.get_child_count()-1).get_child(1)
	for connection in _return_button.pressed.get_connections():
		_return_button.pressed.disconnect(connection.callable)
	_return_button.text = "继续剧情"
	_return_button.pressed.connect(_finish)
func show_scene(_id: String) -> void:
	# Cancelling an unfinished trial returns to the menu without fabricating a chapter result.
	get_tree().change_scene_to_file("res://modules/main_menu/MainMenu.tscn")
func _process(_delta: float) -> void:
	if not is_instance_valid(runtime): return
	if is_instance_valid(_return_button) and _return_button.visible:
		_return_button.disabled = not runtime.play_flow.result_panel.visible
func _finish() -> void:
	if finished_once or not is_instance_valid(runtime) or not runtime.play_flow.result_panel.visible: return
	var race: Node = runtime.race
	var in_race: bool = is_instance_valid(race) and race.current_mode == "Race"
	var seconds: float = race.charlie_time if in_race else runtime.clock.elapsed
	_complete({"seconds":seconds,"mouse_finished":in_race and race.mouse_time>=0.0,"player_finished":true,"withdrawn":false,"development_skip":false,"score_valid":true})
func _complete(result: Dictionary) -> void:
	finished_once = true
	if is_instance_valid(runtime): runtime.actor.controls_enabled = false
	_restore()
	finished.emit(result)
	queue_free()
func development_finish() -> void:
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://modules/visual_novel/data/experience.json"))
	if not settings.development or finished_once: return
	_complete({"seconds":null,"mouse_finished":false,"player_finished":false,"withdrawn":false,"development_skip":true,"score_valid":false})
func _restore() -> void:
	get_window().content_scale_size = _previous_size
	get_window().content_scale_aspect = _previous_aspect
	Input.mouse_mode = _previous_mouse
func _exit_tree() -> void:
	_restore()
