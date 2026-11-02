extends Control

const STORY_SCENE := preload("res://scenes/story.tscn")
const MAZE_SCENE := preload("res://scenes/maze.tscn")
var active_scene: Control
var active_id := ""

func _ready() -> void:
	%StoryButton.pressed.connect(show_scene.bind("story"))
	%MazeButton.pressed.connect(show_scene.bind("maze"))
	show_scene("maze")

func show_scene(id: String) -> void:
	if id == active_id:
		%StoryButton.set_pressed_no_signal(id == "story")
		%MazeButton.set_pressed_no_signal(id == "maze")
		return
	if is_instance_valid(active_scene):
		%SceneHost.remove_child(active_scene)
		active_scene.queue_free()
	active_id = id
	active_scene = STORY_SCENE.instantiate() if id == "story" else MAZE_SCENE.instantiate()
	%SceneHost.add_child(active_scene)
	active_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if id == "story":
		active_scene.enter_maze.connect(show_scene.bind("maze"))
	%StoryButton.set_pressed_no_signal(id == "story")
	%MazeButton.set_pressed_no_signal(id == "maze")
