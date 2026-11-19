extends CanvasLayer
## Same play-only controls as the finished Maze 01, without an inventory dependency.
var maze: Control
var mode := 0
var saved_mode: Window.Mode
var hidden: Array[Control] = []
var margins: Dictionary = {}
var frame: MarginContainer
var document: JavaScriptObject
var callback: JavaScriptObject
var selected_route := "none"

func install(level: Control) -> void:
	maze = level
	level.add_child(self)
	if OS.has_feature("web"):
		document = JavaScriptBridge.get_interface("document")
		if document != null:
			callback = JavaScriptBridge.create_callback(_browser_changed)
			document.addEventListener("fullscreenchange", callback)
			_browser_changed([])
	else:
		for spec in [["纯画面 F10", 1], ["全屏 F11", 2]]:
			var button := Button.new()
			button.text = spec[0]
			button.pressed.connect(toggle.bind(spec[1]))
			maze.get_node("Toolbar").add_child(button)

func _input(event: InputEvent) -> void:
	if OS.has_feature("web") or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F10: toggle(1)
		KEY_F11: toggle(2)
		KEY_ESCAPE:
			if mode == 0:
				return
			set_mode(0)
		_: return
	get_viewport().set_input_as_handled()

func toggle(next: int) -> void:
	set_mode(0 if mode == next else next)

func _browser_changed(_args: Array) -> void:
	var target = document.fullscreenElement
	set_mode.call_deferred(1 if target != null and target.id == "playtest" else 0)

func set_mode(next: int) -> void:
	if next == mode:
		return
	if mode == 0:
		saved_mode = maze.get_window().mode
		selected_route = maze.selected_route
		maze.select_route("none")
		maze.set_walk_mode(true)
		for child in maze.get_children():
			if child is Control and child != maze.get_node("%ViewportContainer") and child.visible:
				hidden.append(child)
				child.hide()
		var host := maze.get_parent()
		var shell := host.get_parent()
		if shell is VBoxContainer:
			for child in shell.get_children():
				if child is Control and child != host and child.visible:
					hidden.append(child)
					child.hide()
			if shell.get_parent() is MarginContainer:
				frame = shell.get_parent()
				for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
					margins[key] = frame.get_theme_constant(key)
					frame.add_theme_constant_override(key, 0)
	if next == 0:
		restore()
		maze.select_route(selected_route)
	if not OS.has_feature("web"):
		if next == 2:
			maze.get_window().mode = Window.MODE_FULLSCREEN
		elif mode == 2:
			maze.get_window().mode = saved_mode
	mode = next
	get_viewport().gui_release_focus()

func restore() -> void:
	for child in hidden:
		if is_instance_valid(child):
			child.show()
	hidden.clear()
	if is_instance_valid(frame):
		for key in margins:
			frame.add_theme_constant_override(key, margins[key])
	margins.clear()

func _exit_tree() -> void:
	if mode == 2:
		maze.get_window().mode = saved_mode
	if document != null and callback != null:
		document.removeEventListener("fullscreenchange", callback)
	restore()
