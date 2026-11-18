extends Control

const STORY_SCENE := preload("res://scenes/story.tscn")
const MAZE_SCENE := preload("res://scenes/levels/maze_01_greybox.tscn")
const MazeSelector := preload("res://scripts/levels/maze_select.gd")
const MAZE_MENU_PATH := "res://scenes/levels/MazeSelect.tscn"
var active_scene: Control
var active_id := ""
var _maze_entry := "maze_select"

func _ready() -> void:
	if OS.has_feature("web"):
		_maze_entry = "maze_select"
	%StoryButton.pressed.connect(show_scene.bind("story"))
	%MazeButton.pressed.connect(_navigate_maze)
	show_scene(_maze_entry)

func show_scene(id: String) -> void:
	if id == active_id:
		_sync_navigation()
		return
	if is_instance_valid(active_scene):
		%SceneHost.remove_child(active_scene)
		active_scene.queue_free()
	active_id = id
	match id:
		"story":
			active_scene = STORY_SCENE.instantiate()
		"maze_select":
			var selector := (load(MAZE_MENU_PATH) as PackedScene).instantiate() as MazeSelector
			selector.open_in_host = true
			selector.maze_chosen.connect(_open_selected_maze)
			active_scene = selector
		"maze03":
			active_scene = (load(MazeSelector.MAZES[2]) as PackedScene).instantiate()
		"maze02":
			active_scene = (load(MazeSelector.MAZES[1]) as PackedScene).instantiate()
		_:
			active_scene = MAZE_SCENE.instantiate()
	%SceneHost.add_child(active_scene)
	active_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if id == "story":
		active_scene.enter_maze.connect(show_scene.bind("maze"))
	_sync_navigation()

func _open_selected_maze(index: int) -> void:
	show_scene(["maze", "maze02", "maze03"][index])

func _sync_navigation() -> void:
	var playing := active_id in ["maze", "maze02", "maze03"]
	for child in $Margin/Layout.get_children():
		if child is Control and child != %SceneHost: child.visible = not playing
	for side: String in ["left","right","top","bottom"]:
		var original: int = {"left":44,"right":44,"top":24,"bottom":20}[side]
		$Margin.add_theme_constant_override("margin_"+side,0 if playing else original)
	%StoryButton.set_pressed_no_signal(active_id == "story")
	%MazeButton.set_pressed_no_signal(active_id == _maze_entry)
	if active_id in ["maze","maze02","maze03","maze_select"]:
		%MazeButton.text = "返回迷宫选择" if active_id in ["maze", "maze02", "maze03"] else "迷宫试玩"

func _navigate_maze() -> void:
	# Keep native startup unchanged, but make the existing picker reachable.
	show_scene("maze_select")


func restart_active_maze() -> void:
	if active_id not in ["maze","maze02","maze03"]: return
	var id := active_id
	active_id = ""
	show_scene(id)
