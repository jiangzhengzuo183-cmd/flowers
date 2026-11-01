extends VBoxContainer

const MazeLoader := preload("res://scripts/maze/maze_loader.gd")
var loaded_ok := false
var selected_route := "none"

func _ready() -> void:
	var loaded := MazeLoader.load_map()
	if not loaded.ok:
		%Status.text = str(loaded.error)
		%Status.modulate = Color("b94141")
		for button: Button in [%HideRoute, %RouteA, %RouteB, %ResetCamera, %PaletteButton]:
			button.disabled = true
		return
	var maze: Dictionary = loaded.data
	%GeneratedMaze.build(maze)
	%CameraRig.configure(int(maze.grid.cols) * float(maze.grid.cellSizeWorld), int(maze.grid.rows) * float(maze.grid.cellSizeWorld))
	%ViewportContainer.gui_input.connect(%CameraRig.handle_input)
	%HideRoute.pressed.connect(select_route.bind("none"))
	%RouteA.pressed.connect(select_route.bind("A"))
	%RouteB.pressed.connect(select_route.bind("B"))
	%ResetCamera.pressed.connect(%CameraRig.reset_view)
	%PaletteButton.toggled.connect(set_soft_palette)
	%RouteA.text = "路线 A · %d 步" % int(maze.routes.A.moveCount)
	%RouteB.text = "路线 B · %d 步" % int(maze.routes.B.moveCount)
	loaded_ok = true
	select_route("none")

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
