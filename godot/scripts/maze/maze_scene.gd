extends VBoxContainer

const MazeLoader := preload("res://scripts/maze/maze_loader.gd")
var loaded_ok := false
var selected_route := "none"
var walk_mode := false
var maze_data: Dictionary

func _ready() -> void:
	var loaded := MazeLoader.load_map()
	if not loaded.ok:
		%Status.text = str(loaded.error)
		%Status.modulate = Color("b94141")
		for button: Button in [%HideRoute, %RouteA, %RouteB, %ResetCamera, %PaletteButton]:
			button.disabled = true
		return
	var maze: Dictionary = loaded.data
	maze_data = maze
	%GeneratedMaze.build(maze)
	%CameraRig.configure(int(maze.grid.cols) * float(maze.grid.cellSizeWorld), int(maze.grid.rows) * float(maze.grid.cellSizeWorld))
	%Player.configure(maze.openings.entry.cell, float(maze.grid.cellSizeWorld), int(maze.grid.cols) * float(maze.grid.cellSizeWorld), int(maze.grid.rows) * float(maze.grid.cellSizeWorld))
	%FollowRig.configure(%Player)
	%Player.movement_camera = %FollowRig.camera
	%ViewportContainer.gui_input.connect(_handle_camera_input)
	%HideRoute.pressed.connect(select_route.bind("none"))
	%RouteA.pressed.connect(select_route.bind("A"))
	%RouteB.pressed.connect(select_route.bind("B"))
	%ResetCamera.pressed.connect(_reset_camera)
	%WalkButton.pressed.connect(func(): set_walk_mode(not walk_mode))
	%RestartWalk.pressed.connect(reset_walk)
	%TopView.pressed.connect(show_top_view)
	%PaletteButton.toggled.connect(set_soft_palette)
	%RouteA.text = "路线 A · %d 步" % int(maze.routes.A.moveCount)
	%RouteB.text = "路线 B · %d 步" % int(maze.routes.B.moveCount)
	loaded_ok = true
	select_route("none")
	set_walk_mode(true)

func _handle_camera_input(event: InputEvent) -> void:
	if walk_mode:
		%FollowRig.handle_input(event)
	else:
		%CameraRig.handle_input(event)
	if event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus()

func _reset_camera() -> void:
	if walk_mode:
		%FollowRig.reset_view()
	else:
		%CameraRig.reset_view()

func reset_walk() -> void:
	%Player.reset_player()
	%FollowRig.reset_view()
	get_viewport().gui_release_focus()

func show_top_view() -> void:
	set_walk_mode(false)
	%CameraRig.show_top_view()
	%Legend.text = "俯视全貌 · 鼠标拖动平移 · 滚轮自由缩放 · 点击“亲自走迷宫”返回行走"

func set_walk_mode(enabled: bool) -> void:
	walk_mode = enabled
	if enabled:
		%FollowRig.reset_view()
	%Player.controls_enabled = enabled
	%Player.visible = enabled
	%FollowRig.enabled = enabled
	%FollowRig.camera.current = enabled
	%CameraRig.camera.current = not enabled
	%GeneratedMaze.set_walk_cutaway(enabled)
	%WalkButton.text = "全图查看" if enabled else "亲自走迷宫"
	%RestartWalk.visible = enabled
	%Legend.text = "WASD / 方向键走路 · 按住 Shift 跑步 · 拖动观察 · 滚轮缩放 · 俯视全貌" if enabled else "左键旋转，松开对齐 · 滚轮缩放 · 右键平移"
	%Status.text = "查理已进入迷宫：待机 / 走路 / 跑步动画随实际移动切换；暂不支持跳跃。" if enabled else "全图查看模式；点击“亲自走迷宫”进入步行体验。"
	get_viewport().gui_release_focus()

func select_route(id: String) -> void:
	selected_route = id
	%GeneratedMaze.set_route(id)
	%HideRoute.set_pressed_no_signal(id == "none")
	%RouteA.set_pressed_no_signal(id == "A")
	%RouteB.set_pressed_no_signal(id == "B")

func set_soft_palette(enabled: bool) -> void:
	%GeneratedMaze.set_soft_palette(enabled)
	# Duplicate the environment so palette changes do not leak across scene instances.
	var environment: Environment = %WorldEnvironment.environment.duplicate()
	environment.background_color = Color("a9a6ca") if enabled else Color("e4e6e3")
	%WorldEnvironment.environment = environment
	%PaletteButton.text = "返回灰盒" if enabled else "柔和配色"
