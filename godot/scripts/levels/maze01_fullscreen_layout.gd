extends CanvasLayer
## Play-only views reuse the existing viewport, input and inventory in both mazes.

const Items := preload("res://modules/maze_items/maze_item_controller.gd")
const Keys := preload("res://modules/maze_keys/maze01_gate_keys.gd")
const Inventory := preload("res://modules/maze_items/maze_inventory.gd")
const MARGINS := [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]

enum PlayView { STANDARD, WINDOW, FULLSCREEN }

var active := false
var play_view := PlayView.STANDARD
var _maze: Control
var _inventory: Inventory
var _inventory_index: int
var _route := "none"
var _frame: MarginContainer
var _host: Control
var _shell: VBoxContainer
var _window: Window
var _window_mode: Window.Mode
var _saved_margins: Dictionary = {}
var _hidden: Array[Control] = []
var _card: PanelContainer
var _content: VBoxContainer
var _hint: Label
var _document: JavaScriptObject
var _callback: JavaScriptObject

func install(maze: Control, inventory: Inventory) -> void:
	_maze = maze
	_inventory = inventory
	_inventory_index = inventory.get_index()
	_host = maze.get_parent() as Control
	var layout := _host.get_parent() as VBoxContainer if is_instance_valid(_host) else null
	if layout != null:
		if layout.get_node_or_null("SceneHost") == _host:
			_frame = layout.get_parent() as MarginContainer
			_shell = layout
		elif layout.get_node_or_null("LevelHost") == _host:
			_shell = layout
	maze.add_child(self)
	_window = maze.get_window()
	if not OS.has_feature("web"):
		_add_play_button("PlayOnlyButton", "纯画面 F10", PlayView.WINDOW)
		_add_play_button("FullscreenButton", "全屏 F11", PlayView.FULLSCREEN)
		return
	_build_overlay()
	_document = JavaScriptBridge.get_interface("document")
	if _document != null:
		_callback = JavaScriptBridge.create_callback(_on_browser_fullscreen)
		_document.addEventListener("fullscreenchange", _callback)
		_on_browser_fullscreen([])

func _add_play_button(id: String, text: String, mode: PlayView) -> void:
	var button := Button.new()
	button.name = id
	button.text = text
	button.tooltip_text = "只显示游戏画面。Q 使用选中的主动道具，Esc 返回。"
	button.pressed.connect(_toggle_play_view.bind(mode))
	_maze.get_node("Toolbar").add_child(button)

func _input(event: InputEvent) -> void:
	if OS.has_feature("web") or not _maze.is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match code:
		KEY_F10:
			_toggle_play_view(PlayView.WINDOW)
		KEY_F11:
			_toggle_play_view(PlayView.FULLSCREEN)
		KEY_ESCAPE:
			if play_view == PlayView.STANDARD:
				return
			_set_play_view(PlayView.STANDARD)
		KEY_Q:
			var use_item := _inventory.get_node("UseItem") as Button
			if play_view == PlayView.STANDARD or use_item.disabled or not use_item.visible:
				return
			use_item.pressed.emit()
		_:
			return
	get_viewport().set_input_as_handled()

func _toggle_play_view(mode: PlayView) -> void:
	_set_play_view(PlayView.STANDARD if play_view == mode else mode)

func _set_play_view(mode: PlayView) -> void:
	if mode == play_view:
		return
	if play_view == PlayView.STANDARD:
		_window_mode = _window.mode
		_route = _maze.get("selected_route")
		_maze.call("select_route", "none")
		if not _maze.get("walk_mode"):
			_maze.call("set_walk_mode", true)
		_hide_host_chrome()
		_hide_chrome(_maze, _maze.get_node("%ViewportContainer"))
	elif mode == PlayView.STANDARD:
		_restore_chrome()
		_maze.call("select_route", _route)
	if mode == PlayView.FULLSCREEN:
		_window.mode = Window.MODE_FULLSCREEN
	elif play_view == PlayView.FULLSCREEN:
		_window.mode = _window_mode
	play_view = mode
	get_viewport().gui_release_focus()

func _build_overlay() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_card.offset_left = 18
	_card.offset_top = -18
	_card.offset_bottom = -18
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.theme = _maze.theme
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("f5f0e3ed")
	surface.set_corner_radius_all(6)
	surface.content_margin_left = 10
	surface.content_margin_right = 10
	surface.content_margin_top = 7
	surface.content_margin_bottom = 7
	_card.add_theme_stylebox_override("panel", surface)
	_content = VBoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_content)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 15)
	_content.add_child(_hint)
	_card.hide()

func _on_browser_fullscreen(_args: Array) -> void:
	var target = _document.fullscreenElement
	# Apply the Godot layout on its next frame, after the browser's event callback.
	_set_fullscreen.call_deferred(target != null and target.id == "playtest")

func _set_fullscreen(enabled: bool) -> void:
	if enabled == active:
		return
	active = enabled
	if enabled:
		_route = _maze.get("selected_route")
		_maze.call("select_route", "none")
		_hide_host_chrome()
		_inventory.reparent(_content, false)
		_inventory.get_node("InventoryHeading").hide()
		_inventory.get_node("ItemNotice").hide()
		_hide_chrome(_maze, _maze.get_node("%ViewportContainer"))
	else:
		_restore_chrome()
		_inventory.reparent(_maze, false)
		_maze.move_child(_inventory, _inventory_index)
		_inventory.show()
		for id: StringName in [Items.RABBIT, Keys.COIN, Keys.HORSESHOE, &"UseItem", &"InventoryHeading", &"ItemNotice"]:
			_inventory.get_node(String(id)).show()
		_card.hide()
		_maze.call("select_route", _route)

func _hide_host_chrome() -> void:
	if is_instance_valid(_frame):
		for key: StringName in MARGINS:
			_saved_margins[key] = _frame.get_theme_constant(key)
			_frame.add_theme_constant_override(key, 0)
	if is_instance_valid(_shell):
		_hide_chrome(_shell, _host)

func _hide_chrome(parent: Node, keep: Control) -> void:
	for child in parent.get_children():
		if child is Control and child != keep and child.visible:
			_hidden.append(child)
			child.hide()

func _restore_chrome() -> void:
	for node: Control in _hidden:
		if is_instance_valid(node):
			node.show()
	_hidden.clear()
	if is_instance_valid(_frame):
		for key: StringName in _saved_margins:
			_frame.add_theme_constant_override(key, _saved_margins[key])
	_saved_margins.clear()

func refresh(context: String) -> void:
	if not active:
		return
	var has_items := false
	for id: StringName in [Items.RABBIT, Keys.COIN, Keys.HORSESHOE]:
		var held: bool = _inventory.quantity(id) > 0
		_inventory.get_node(String(id)).visible = held
		has_items = has_items or held
	_inventory.get_node("UseItem").visible = _inventory.quantity(Items.RABBIT) > 0
	var notice: String = _inventory.get_node("ItemNotice").text
	_hint.text = context if not context.is_empty() else notice
	_hint.visible = not _hint.text.is_empty()
	_inventory.visible = has_items
	_card.visible = has_items or _hint.visible

func _exit_tree() -> void:
	if play_view == PlayView.FULLSCREEN and is_instance_valid(_window):
		_window.mode = _window_mode
	if _document != null and _callback != null:
		_document.removeEventListener("fullscreenchange", _callback)
	_restore_chrome()
