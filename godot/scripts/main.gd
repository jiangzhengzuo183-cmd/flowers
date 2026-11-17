extends Control

const STORY_SCENE := preload("res://scenes/story.tscn")
const MAZE_SCENE := preload("res://scenes/maze.tscn")
var active_scene: Control
var active_id := ""

func _ready() -> void:
	%StoryButton.pressed.connect(show_scene.bind("story"))
	%MazeButton.pressed.connect(show_scene.bind("maze"))
	show_scene("story")

func show_scene(id: String) -> void:
	if id == active_id:
		%StoryButton.set_pressed_no_signal(id == "story")
		%MazeButton.set_pressed_no_signal(id == "maze")
		return
	if is_instance_valid(active_scene):
		%SceneHost.remove_child(active_scene)
		active_scene.queue_free()
	active_id = id
	_apply_layout(id)
	active_scene = STORY_SCENE.instantiate() if id == "story" else MAZE_SCENE.instantiate()
	%SceneHost.add_child(active_scene)
	active_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if id == "story":
		active_scene.enter_maze.connect(show_scene.bind("maze"))
	%StoryButton.set_pressed_no_signal(id == "story")
	%MazeButton.set_pressed_no_signal(id == "maze")

func _apply_layout(id: String) -> void:
	# 剧情使用完整 16:9 画面，迷宫保留原有工具栏。
	var story_mode := id == "story"
	var margin := get_node("Margin") as MarginContainer
	var values := {"margin_left": 44, "margin_top": 24, "margin_right": 44, "margin_bottom": 20}
	for key: String in values:
		margin.add_theme_constant_override(key, 0 if story_mode else values[key])
	var layout := get_node("Margin/Layout") as VBoxContainer
	layout.add_theme_constant_override("separation", 0 if story_mode else 18)
	for child_name: String in ["Header", "Separator", "FooterSeparator", "Footer"]:
		(get_node("Margin/Layout/" + child_name) as Control).visible = not story_mode
