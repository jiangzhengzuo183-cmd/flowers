extends PanelContainer
## 叙事内嵌原迷宫：不改动迷宫模块，真实到达出口后才完成第一轮。
signal finished(result: Dictionary)
const MAZE := preload("res://scenes/maze.tscn")
var maze: Control
var clock := 0.0
var round_number := 1
var mouse: Sprite3D
var status: Label
var finish_button: Button
var mouse_done := false
var player_done := false
var route: Array
var cell_size := 2.4
var player: CharacterBody3D
var paused := false
var finished_once := false
var development_result := false

func _ready() -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f8efdc")
	paper.content_margin_left = 24
	paper.content_margin_right = 24
	paper.content_margin_top = 16
	paper.content_margin_bottom = 16
	add_theme_stylebox_override("panel",paper)
	var box := VBoxContainer.new()
	add_child(box)
	status = Label.new()
	status.add_theme_font_size_override("font_size",20)
	box.add_child(status)
	maze = MAZE.instantiate()
	maze.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(maze)
	maze.get_node("Heading").hide()
	maze.get_node("Summary").hide()
	maze.get_node("%Status").hide()
	player = maze.get_node("%Player")
	route = maze.maze_data.routes.A.cellPath
	cell_size = float(maze.maze_data.grid.cellSizeWorld)
	mouse = Sprite3D.new()
	mouse.texture = preload("res://assets/continuation/mouse.png")
	mouse.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mouse.pixel_size = 0.0015
	mouse.no_depth_test = false
	player.get_parent().add_child(mouse)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	finish_button = Button.new()
	finish_button.text = "到达出口后回到实验室"
	finish_button.disabled = true
	finish_button.custom_minimum_size = Vector2(300,48)
	finish_button.pressed.connect(_finish)
	actions.add_child(finish_button)
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/experience.json"))
	if settings.development:
		var skip := Button.new()
		skip.text = "开发演示 · 直接到终点"
		skip.pressed.connect(development_finish)
		actions.add_child(skip)
	if round_number == 2:
		var stop := Button.new()
		stop.text = "我不想再比了 · 结束这次测试"
		stop.pressed.connect(func() -> void: _finish(true))
		actions.add_child(stop)

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	player.controls_enabled = visible and not paused
	if paused or not visible: return
	clock += delta
	# 老鼠按真实有效路径跑到终点；不改变玩家速度、地图和碰撞。
	var progress := minf(clock*8.0,route.size()-1.0)
	var at := mini(int(progress),route.size()-1)
	var next := mini(at+1,route.size()-1)
	var first: Vector3 = _cell(route[at])
	mouse.position = first.lerp(_cell(route[next]),progress-at)
	mouse_done = at == route.size()-1
	var goal: Vector3 = _cell(maze.maze_data.openings.exit.cell)
	player_done = Vector2(player.position.x-goal.x,player.position.z-goal.z).length() < cell_size*0.48
	finish_button.disabled = not player_done
	finish_button.text = "回到实验室" if player_done else "到达出口后回到实验室"
	status.text = "第%d次迷宫测试  ·  %.1f 秒  ·  %s" % [round_number,clock,"阿尔吉侬已到终点" if mouse_done else "阿尔吉侬正在前面找路"]

func _cell(cell: Array) -> Vector3:
	return Vector3((cell[1]+0.5)*cell_size,0.85,(cell[0]+0.5)*cell_size)

func _finish(withdrawn: bool = false) -> void:
	if finished_once: return
	if not player_done and not (round_number == 2 and withdrawn): return
	finished_once = true
	player.controls_enabled = false
	finished.emit({"seconds":null if development_result else clock,"mouse_finished":mouse_done,"player_finished":player_done,"withdrawn":withdrawn,"development_skip":development_result,"score_valid":not development_result})
	queue_free()

func development_finish() -> void:
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/experience.json"))
	if not settings.development or finished_once: return
	development_result = true
	player.position = _cell(maze.maze_data.openings.exit.cell)
	player_done = true
	_finish()
