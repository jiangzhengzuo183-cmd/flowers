extends Control
## This scene owns menu presentation only. The exported entry keeps chapter routing separate.
signal start_requested
const Title := preload("res://modules/main_menu/title_animation.gd")
const Companion := preload("res://modules/main_menu/mouse_companion.gd")
const Paper := preload("res://modules/main_menu/paper_interaction.gd")
const Credits := preload("res://modules/main_menu/credits_panel.gd")
const Cursor := preload("res://modules/game_hud/hand_cursor.gd")
const Note := preload("res://modules/main_menu/note_modal.gd")
const Type := preload("res://modules/main_menu/menu_typography.gd")
const Foley := preload("res://modules/main_menu/paper_foley.gd")
const ASSETS := "res://modules/main_menu/assets/"
@export_file("*.tscn") var game_entry := "res://modules/visual_novel/VisualNovel.tscn"
var menu_cursor: CanvasLayer
var metadata: Dictionary
var background: TextureRect
var paper_stack: Control
var extension: ColorRect
var title: Control
var menus: Control
var buttons: Array[Button] = []
var icons: Array[Label] = []
var pencil: Node2D
var companion: Node2D
var paper: Node2D
var credits: Control
var fade: ColorRect
var exit_note: Control
var exit_open := false
var flowers: Control
var foley: Node
var paper_rect := Rect2()
var ink_rects: Array[Rect2] = []
var menu_rects: Array[Rect2] = []
var title_complete := false
var credits_open := false
var transitioning := false
var _last_paw:=Vector2.INF
var _last_paw_enabled:=false
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
	_initialize_menu.call_deferred()

func _initialize_menu() -> void:
	# The initial scene readies while the root Window is still setting up children.
	Cursor.install(get_window())
	metadata = preload("res://modules/main_menu/assets/layout_handdrawn.gd").DATA
	_build()
	menu_cursor=preload("res://modules/main_menu/menu_cursor.gd").new()
	add_child(menu_cursor)
	resized.connect(_layout)
	_layout()
	call_deferred("_layout")

func _build() -> void:
	extension = ColorRect.new()
	extension.color = Color("eee9df")
	extension.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(extension)
	background = TextureRect.new()
	background.texture = preload("res://modules/main_menu/assets/wood_desk.png")
	background.modulate=Color(0.64,0.45,0.29)
	background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	paper_stack=preload("res://modules/main_menu/paper_stack.gd").new()
	add_child(paper_stack)
	flowers=preload("res://modules/main_menu/flower_doodles.gd").new()
	add_child(flowers)
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
		var image := Label.new()
		image.text = str(metadata.menus[i].label)
		image.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		image.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Type.apply(image,48,float(i)*3.0)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)
		icons.append(image)
		button.mouse_entered.connect(_hover.bind(i, true))
		button.mouse_exited.connect(_hover.bind(i, false))
		button.focus_entered.connect(_hover.bind(i, true))
		button.focus_exited.connect(_hover.bind(i, false))
		button.pressed.connect(_activate.bind(i))
	pencil=preload("res://modules/main_menu/pencil_prop.gd").new()
	pencil.name="PencilProp"
	add_child(pencil)
	companion = Companion.new()
	add_child(companion)
	companion.pencil=pencil
	companion.gnaw_started.connect(paper.begin_gnaw)
	companion.gnaw_bite.connect(paper.bite)
	companion.gnaw_stopped.connect(paper.stop_gnaw)
	foley = Foley.new()
	add_child(foley)
	foley.install(companion)
	credits = Credits.new()
	add_child(credits)
	credits.back_requested.connect(close_credits)
	credits.closed.connect(_credits_closed)
	_build_exit_note()
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
	paper_stack.place(paper_rect)
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
		var center := paper_rect.position + (Vector2(rect[0], rect[1]) + Vector2(rect[2], rect[3]) * 0.5) * source_scale
		buttons[i].size = Vector2(275, 72) * unit
		buttons[i].position = center - buttons[i].size * 0.5
		buttons[i].pivot_offset = buttons[i].size * 0.5
		icons[i].size = buttons[i].size
		icons[i].position = Vector2.ZERO
		var text_ink := Vector2(230,55)*unit
		var protected := Rect2(center-text_ink*0.5,text_ink)
		menu_rects.append(protected)
		ink_rects.append(protected)
	pencil.place(paper_rect)
	companion.configure(paper_rect, ink_rects, menu_rects, unit, tall)
	paper.place(paper_rect)
	credits.place(paper_rect)
	exit_note.place(paper_rect)
	flowers.place(paper_rect)
	_bind_tear_mask()
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
	if not title_complete or transitioning or credits_open or exit_open: return
	var button := buttons[index]
	var tween: Tween = button.get_meta("hover_tween") if button.has_meta("hover_tween") else null
	if tween and tween.is_valid(): tween.kill()
	tween = create_tween()
	button.set_meta("hover_tween", tween)
	tween.tween_property(button, "scale", Vector2.ONE * (1.025 if hovered else 1.0), 0.16).set_trans(Tween.TRANS_SINE)

func _build_exit_note() -> void:
	exit_note = Note.new()
	exit_note.dimensions = Vector2(580,340)
	exit_note.creamy = false
	add_child(exit_note)
	exit_note.label("是否确认退出游戏？",32)
	exit_note.label("将关闭游戏并回到桌面。",24)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",24)
	exit_note.content.add_child(row)
	exit_note.cancel_button = exit_note.action(row,"取消",exit_note.peel)
	exit_note.confirm_button = exit_note.action(row,"确认退出",_confirm_desktop,true)
	exit_note.closed.connect(_exit_closed)

func _lock_menu(locked: bool) -> void:
	for button in buttons: button.disabled = locked
	companion.set_enabled(not locked)
	if locked: companion.visible = true

func _activate(index: int) -> void:
	if transitioning or not title_complete or credits_open or exit_open: return
	if index == 1:
		open_credits()
	elif index == 2:
		exit_open = true
		_lock_menu(true)
		exit_note.open()
	else:
		transitioning = true
		_lock_menu(true)
		fade.mouse_filter = Control.MOUSE_FILTER_STOP
		var tween := create_tween()
		tween.tween_property(fade,"modulate:a",1.0,0.30)
		tween.tween_callback(func():
			if start_requested.get_connections().is_empty():
				var error := get_tree().change_scene_to_file(game_entry)
				if error != OK: _entry_failed(error)
			else: start_requested.emit()
		)

func _entry_failed(error: Error) -> void:
	push_error("Main menu entry could not open %s (%s)" % [game_entry,error])
	transitioning = false
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	create_tween().tween_property(fade,"modulate:a",0.0,0.25)
	_lock_menu(false)

func open_credits() -> void:
	if transitioning or credits_open or exit_open: return
	credits_open = true
	_lock_menu(true)
	credits.open()

func close_credits() -> void:
	if credits_open: credits.peel()

func _credits_closed() -> void:
	credits_open = false
	_lock_menu(false)

func _exit_closed() -> void:
	exit_open = false
	_lock_menu(false)

func _confirm_desktop() -> void:
	if not exit_open or transitioning: return
	transitioning = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(fade,"modulate:a",1.0,0.18)
	tween.tween_callback(func():get_tree().quit())

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		companion.click_reaction()
	if event.is_action_pressed("ui_cancel"):
		if credits_open: close_credits()
		elif exit_open: exit_note.peel()
		else: return
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if resized.is_connected(_layout): resized.disconnect(_layout)
	var window := get_window()
	if is_instance_valid(window):
		window.content_scale_size = _previous_scale
		window.content_scale_aspect = _previous_aspect
		window.content_scale_mode = _previous_mode

func _process(_delta: float) -> void:
	if not is_instance_valid(companion) or not title_complete: return
	var active: bool=companion.enabled and companion.jump_height<1.0*companion.unit
	var at: Vector2=companion._display_world
	if active==_last_paw_enabled and at.distance_squared_to(_last_paw)<0.06: return
	_last_paw=at
	_last_paw_enabled=active
	var artwork: Array=[]
	artwork.append_array(title.letters)
	artwork.append_array(icons)
	for item: Control in artwork:
		var local:=item.get_global_transform().affine_inverse()*at
		item.material.set_shader_parameter("paw_position",local)
		item.material.set_shader_parameter("paw_strength",1.0 if active else 0.0)

func _bind_tear_mask() -> void:
	var artwork: Array=[]
	artwork.append_array(title.letters)
	artwork.append_array(icons)
	artwork.append_array(flowers.blooms)
	for item: Control in artwork:
		item.material.set_shader_parameter("tear_mask",paper.mask_viewport.get_texture())
		item.material.set_shader_parameter("tear_enabled",true)
		item.material.set_shader_parameter("paper_origin",paper_rect.position)
		item.material.set_shader_parameter("paper_size",paper_rect.size)
