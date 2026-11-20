extends Control
## Presents the imported chapter at its original design size; no chapter logic lives here.
var story: Control
var _previous_size: Vector2i
var _previous_aspect: Window.ContentScaleAspect
func _ready() -> void:
	_previous_size = get_window().content_scale_size
	_previous_aspect = get_window().content_scale_aspect
	get_window().content_scale_size = Vector2i(1600,900)
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	preload("res://modules/game_hud/hand_cursor.gd").install(get_window())
	story = preload("res://modules/visual_novel/scenes/story.tscn").instantiate()
	story.theme = preload("res://modules/visual_novel/ui/chapter1_theme.tres")
	add_child(story)
	story.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story.enter_maze.connect(_open_maze)
func _open_maze() -> void:
	var bridge: Control = preload("res://modules/visual_novel/scripts/story/story_race.gd").new()
	bridge.round_number = 1
	add_child(bridge)
	bridge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story.hide()
	bridge.finished.connect(func(_result: Dictionary): story.show())
func _exit_tree() -> void:
	get_window().content_scale_size = _previous_size
	get_window().content_scale_aspect = _previous_aspect
