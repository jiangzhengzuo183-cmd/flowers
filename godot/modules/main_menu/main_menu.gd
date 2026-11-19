extends Control
## This scene owns menu presentation only. The exported entry keeps chapter routing separate.
signal start_requested
const Title := preload("res://modules/main_menu/title_animation.gd")
const Companion := preload("res://modules/main_menu/mouse_companion.gd")
const Paper := preload("res://modules/main_menu/paper_interaction.gd")
const Credits := preload("res://modules/main_menu/credits_panel.gd")
const Cursor := preload("res://modules/game_hud/hand_cursor.gd")
const PaperTransition := preload("res://modules/main_menu/paper_transition.gd")
const ASSETS := "res://modules/main_menu/assets/"
@export_file("*.tscn") var game_entry := "res://modules/visual_novel/VisualNovel.tscn"
var metadata: Dictionary
var background: TextureRect
var extension: ColorRect
var title: Control
var menus: Control
var buttons: Array[Button] = []
var icons: Array[TextureRect] = []
var companion: Node2D
var paper: Node2D
var credits: Control
var fade: ColorRect
var paper_transition: CanvasLayer
var paper_rect := Rect2()
var ink_rects: Array[Rect2] = []
var menu_rects: Array[Rect2] = []
var title_complete := false
var credits_open := false
var transitioning := false
var _menu_tween: Tween
var _previous_scale := Vector2i.ZERO
var _previous_aspect := Window.CONTENT_SCALE_ASPECT_KEEP
var _previous_mode := Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

func _ready() -> void:
	var window := get_window()
	_previous_scale = window.content_scale_size
	_previous_aspect = window.content_scale_aspect
	_previous_mode = window.content_scale_mode
	# Main menu is a single 16:9 composition; non-16:9 screens keep its proportions.
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Cursor.install(window)
	metadata = preload("res://modules/main_menu/assets/layout_handdrawn.gd").DATA
	_build()
	resized.connect(_layout)
	_layout()
	call_deferred("_layout")

func _build() -> void:
	extension = ColorRect.new()
	extension.color = Color("eee9df")
	extension.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(extension)
	background = TextureRect.new()
	background.texture = load(ASSETS + "background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	paper = Paper.new()
	add_child(paper)
	title = Title.new()
	add_child(title)
	title.build(metadata)
	title.finished.connect(_on_title_finished)
	menus = Control.new()
	menus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menus.modulate.a = 0.0
	add_child(menus)
	for i in 3:
		var button := Button.new()
		button.name = ["StartGame", "Credits", "Desktop"][i]
		button.disabled = true
		button.accessibility_name = str(metadata.menus[i].label)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_mode = Control.FOCUS_ALL
		for style in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		menus.add_child(button)
		buttons.append(button)
		var image := TextureRect.new()
		image.texture = load(ASSETS + str(metadata.menus[i].file))
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)
		icons.append(image)
		button.mouse_entered.connect(_hover.bind(i, true))
		button.mouse_exited.connect(_hover.bind(i, false))
		button.focus_entered.connect(_hover.bind(i, true))
		button.focus_exited.connect(_hover.bind(i, false))
		button.pressed.connect(_activate.bind(i))
	companion = Companion.new()
	add_child(companion)
	companion.gnaw_started.connect(paper.begin_gnaw)
	companion.gnaw_bite.connect(paper.bite)
	companion.gnaw_stopped.connect(paper.stop_gnaw)
	credits = Credits.new()
	add_child(credits)
	credits.back_requested.connect(close_credits)
	fade = ColorRect.new()
	fade.color = Color("fff6e9")
	fade.modulate.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

func _layout() -> void:
	if background == null or not is_inside_tree() or not credits.is_inside_tree(): return
	var viewport := get_viewport_rect().size
	var width := minf(viewport.x, viewport.y * 16.0 / 9.0)
	var height := width * 9.0 / 16.0
	paper_rect = Rect2((viewport - Vector2(width, height)) * 0.5, Vector2(width, height))
	background.position = paper_rect.position
	background.size = paper_rect.size
	var source_scale := width / 8000.0
	var unit := width / 1920.0
	extension.size = viewport
	var tall := 0.0
	var title_origin := paper_rect.position + Vector2(metadata.title_reference_origin[0], metadata.title_reference_origin[1]) * source_scale
	var art_scale := source_scale * float(metadata.title_reference_scale)
	title.place(title_origin, art_scale, unit)
	var ink: Array = metadata.title_ink_rect
	ink_rects = [Rect2(title_origin + Vector2(ink[0], ink[1]) * art_scale, Vector2(ink[2], ink[3]) * art_scale)]
	menu_rects.clear()
	for i in 3:
		var rect: Array = metadata.menus[i].rect
		var image_size := Vector2(rect[2], rect[3]) * source_scale
		var center := paper_rect.position + (Vector2(rect[0], rect[1]) + Vector2(rect[2], rect[3]) * 0.5) * source_scale
		buttons[i].size = Vector2(275, 72) * unit
		buttons[i].position = center - buttons[i].size * 0.5
		buttons[i].pivot_offset = buttons[i].size * 0.5
		icons[i].size = image_size
		icons[i].position = (buttons[i].size - image_size) * 0.5
		var protected := Rect2(center - image_size * 0.5, image_size)
		menu_rects.append(protected)
		ink_rects.append(protected)
	companion.configure(paper_rect, ink_rects, menu_rects, unit, tall)
	paper.place(paper_rect)
	credits.place(paper_rect)
	fade.size = viewport

func _on_title_finished() -> void:
	title_complete = true
	_menu_tween = create_tween()
	_menu_tween.tween_property(menus, "modulate:a", 1.0, 0.35)
	_menu_tween.tween_callback(func():
		for button in buttons: button.disabled = false
		companion.set_enabled(true)
	)

func _hover(index: int, hovered: bool) -> void:
	if not title_complete or transitioning: return
	var button := buttons[index]
	var tween: Tween = button.get_meta("hover_tween") if button.has_meta("hover_tween") else null
	if tween and tween.is_valid(): tween.kill()
	tween = create_tween()
	button.set_meta("hover_tween", tween)
	tween.tween_property(button, "scale", Vector2.ONE * (1.025 if hovered else 1.0), 0.16).set_trans(Tween.TRANS_SINE)

func _turn() -> CanvasLayer:
	if not is_instance_valid(paper_transition):
		paper_transition = PaperTransition.new()
		paper_transition.name = "MenuPaperTransition"
		get_window().add_child(paper_transition)
	return paper_transition

func _activate(index: int) -> void:
	if transitioning or not title_complete: return
	if index == 1:
		open_credits()
		return
	transitioning = true
	companion.set_enabled(false)
	for button in buttons: button.disabled = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if index == 2:
		var tween := create_tween()
		tween.tween_property(fade, "modulate:a", 1.0, 0.3)
		tween.tween_callback(func(): get_tree().quit())
		return
	var turn := _turn()
	turn.completed.connect(turn.queue_free, CONNECT_ONE_SHOT)
	turn.play(func():
		if start_requested.get_connections().is_empty():
			var error := get_tree().change_scene_to_file(game_entry)
			if error != OK: _entry_failed(error)
		else:
			start_requested.emit()
	)

func _entry_failed(error: Error) -> void:
	push_error("Main menu entry could not open %s (%s)" % [game_entry, error])
	transitioning = false
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 0.25)
	for button in buttons: button.disabled = false
	companion.set_enabled(true)

func open_credits() -> void:
	if transitioning or credits_open: return
	transitioning = true
	companion.set_enabled(false)
	for button in buttons: button.disabled = true
	var turn := _turn()
	turn.play(func():
		credits_open = true
		menus.hide()
		title.hide()
		paper.hide()
		credits.modulate.a = 1.0
		credits.show()
	)
	await turn.completed
	transitioning = false
	credits.back.grab_focus()

func close_credits() -> void:
	if transitioning or not credits_open: return
	transitioning = true
	var turn := _turn()
	turn.play(func():
		credits.hide()
		credits_open = false
		paper.show()
		menus.show()
		title.show()
	, true)
	await turn.completed
	transitioning = false
	for button in buttons: button.disabled = false
	companion.set_enabled(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		companion.click_reaction()
	if event.is_action_pressed("ui_cancel") and credits_open:
		close_credits()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if resized.is_connected(_layout): resized.disconnect(_layout)
	if is_instance_valid(paper_transition) and not paper_transition.active: paper_transition.queue_free()
	var window := get_window()
	if is_instance_valid(window):
		window.content_scale_size = _previous_scale
		window.content_scale_aspect = _previous_aspect
		window.content_scale_mode = _previous_mode
