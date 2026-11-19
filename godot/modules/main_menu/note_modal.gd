extends Control
signal closed
const Type := preload("res://modules/main_menu/menu_typography.gd")
const HUDStyle := preload("res://modules/game_hud/game_hud.gd")
var dim: ColorRect
var note: PanelContainer
var corner: Node2D
var content: VBoxContainer
var confirm_button: Button
var cancel_button: Button
var dimensions := Vector2(980,840)
var creamy := true
var active := false
var opening := false
var closing := false
var tween: Tween
var _rest := Vector2.ZERO
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim = ColorRect.new()
	dim.color = Color(0.15,0.12,0.08,0.36)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: peel())
	note = PanelContainer.new()
	note.mouse_filter = Control.MOUSE_FILTER_STOP
	# Autowrapped labels can report a tall minimum before the first container layout.
	# Resize back to the intended note once the measured text width settles.
	note.minimum_size_changed.connect(func():note.size=dimensions)
	add_child(note)
	var helper := HUDStyle.new()
	var surface := helper.paper(40.0 if creamy else 32.0)
	helper.free()
	surface.bg_color = Color("fff0b4") if creamy else Color("fff5dffb")
	surface.border_color = Color("fff4c8") if creamy else Color.WHITE
	surface.shadow_color = Color(0.21,0.16,0.10,0.10)
	surface.shadow_size = 5
	surface.shadow_offset = Vector2(0,3)
	surface.content_margin_top = 34.0 if creamy else 44.0
	surface.content_margin_bottom = 30.0 if creamy else 36.0
	note.add_theme_stylebox_override("panel",surface)
	note.add_child(preload("res://modules/game_hud/note_decor.gd").new())
	content = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation",14 if creamy else 20)
	note.add_child(content)
	if creamy:
		var fold:=ShaderMaterial.new()
		fold.shader=preload("res://modules/main_menu/paper_fold.gdshader")
		note.material=fold
		note.resized.connect(func():fold.set_shader_parameter("paper_size",note.size))
		corner=preload("res://modules/main_menu/sticky_corner.gd").new()
		note.add_child(corner)
	visible = false
func place(_paper: Rect2) -> void:
	var view := get_viewport_rect().size
	_rest = (view-dimensions)*0.5
	if not active or (not opening and not closing): note.position = _rest
	note.size = dimensions
	note.pivot_offset = dimensions*0.5
func label(text: String,font_size: int) -> Label:
	var text_label := Label.new()
	text_label.text = text
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Type.apply(text_label,font_size,float(content.get_child_count()))
	content.add_child(text_label)
	return text_label
func action(parent: Node,text: String,callback: Callable,gold := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(176,56)
	Type.apply(button,24,13.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f5ce63") if gold else Color("fff7df")
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal",style)
	button.add_theme_stylebox_override("pressed",style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = Color("ffdb79") if gold else Color("fffbed")
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
func open() -> void:
	if active: return
	active = true
	opening = true
	closing = false
	show()
	place(Rect2())
	dim.modulate.a = 0.0
	note.modulate.a = 0.0
	var paper_style: StyleBoxFlat = note.get_theme_stylebox("panel")
	paper_style.shadow_size = 5
	paper_style.shadow_offset = Vector2(0,3)
	note.position = _rest+Vector2(0,-28)
	note.scale = Vector2(1.035,1.035)
	note.rotation_degrees = -2.0
	tween = create_tween().set_parallel(true)
	tween.tween_property(dim,"modulate:a",1.0,0.22)
	tween.tween_property(note,"modulate:a",1.0,0.15)
	tween.tween_property(note,"position",_rest,0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(note,"scale",Vector2.ONE,0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(note,"rotation_degrees",-0.55,0.34)
	tween.finished.connect(func():
		opening = false
		if is_instance_valid(cancel_button): cancel_button.grab_focus()
	)
func peel() -> void:
	if not active or closing: return
	closing = true
	opening = false
	var previous_origin := note.get_transform().origin
	note.pivot_offset = Vector2(dimensions.x*0.5,12)
	note.position += previous_origin-note.get_transform().origin
	if tween and tween.is_valid(): tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(dim,"modulate:a",0.0,0.28)
	var lifted: StyleBoxFlat = note.get_theme_stylebox("panel")
	tween.tween_property(lifted,"shadow_size",13,0.30)
	tween.tween_property(lifted,"shadow_offset",Vector2(3,10),0.30)
	tween.tween_property(note,"rotation_degrees",-7.5,0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(note,"position",_rest+Vector2(34,-84),0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(note,"scale",Vector2(0.97,0.84),0.30)
	tween.tween_property(note,"modulate:a",0.0,0.25).set_delay(0.05)
	await tween.finished
	active = false
	closing = false
	hide()
	closed.emit()
func _exit_tree() -> void:
	if tween and tween.is_valid(): tween.kill()
