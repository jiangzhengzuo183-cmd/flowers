extends VBoxContainer
## Standalone scene picker or menu hosted by the web game entry.

signal maze_chosen(index: int)

const MAZES := [
	"res://scenes/levels/maze_01_greybox.tscn",
	"res://scenes/levels/Maze02.tscn",
	"res://scenes/levels/Maze03.tscn",
]
var open_in_host := false
var active_level: Control

func _ready() -> void:
	%Maze01.pressed.connect(open_maze.bind(0))
	%Maze02.pressed.connect(open_maze.bind(1))
	%Maze03.pressed.connect(open_maze.bind(2))
	%Back.pressed.connect(show_selection)
	if open_in_host:
		$Picker/Choices/Description.text = "选择一座迷宫开始试玩"
	show_selection()

func open_maze(index: int) -> void:
	if index < 0 or index >= MAZES.size():
		return
	if open_in_host:
		maze_chosen.emit(index)
		return
	_release_level()
	active_level = (load(MAZES[index]) as PackedScene).instantiate()
	%Picker.hide()
	%Back.show()
	%LevelHost.show()
	%LevelHost.add_child(active_level)
	active_level.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func show_selection() -> void:
	_release_level()
	%LevelHost.hide()
	%Back.hide()
	%Picker.show()
	%Maze01.grab_focus()
	get_window().title = "迷宫选择 · 献给阿尔吉侬的花束" if open_in_host else "迷宫选择 · Godot 测试"

func _release_level() -> void:
	if is_instance_valid(active_level):
		%LevelHost.remove_child(active_level)
		active_level.queue_free()
		active_level = null
