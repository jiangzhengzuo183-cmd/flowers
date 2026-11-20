extends Button
## Animates the artwork only; the hit target and container geometry stay still.
var artwork: Texture2D
var artwork_size := Vector2(96,88)
var hover_angle := 2.5
var glyph: TextureRect
var motion: Tween
var clicking := false

func _ready() -> void:
	custom_minimum_size = Vector2(104,112)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal","hover","pressed","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("b38a52")
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(12)
	add_theme_stylebox_override("focus",focus)
	glyph = TextureRect.new()
	glyph.name = "PaperArtwork"
	glyph.texture = artwork
	var edge_cleanup := ShaderMaterial.new()
	edge_cleanup.shader = preload("res://scripts/story/paper_icon_edge.gdshader")
	glyph.material = edge_cleanup
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glyph)
	glyph.set_anchors_preset(Control.PRESET_CENTER)
	glyph.size = artwork_size
	glyph.position = (size-artwork_size)/2
	glyph.pivot_offset = artwork_size/2
	resized.connect(func() -> void: glyph.position = (size-artwork_size)/2)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	focus_entered.connect(_hover.bind(true))
	focus_exited.connect(_hover.bind(false))
	pressed.connect(_click)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			if motion: motion.kill()
			clicking = false
			glyph.scale = Vector2.ONE
			glyph.rotation = 0)

func _hover(active: bool) -> void:
	if clicking: return
	if motion: motion.kill()
	motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	motion.tween_property(glyph,"scale",Vector2.ONE*(1.08 if active else 1.0),0.15)
	motion.tween_property(glyph,"rotation_degrees",hover_angle if active else 0.0,0.15)

func _click() -> void:
	if motion: motion.kill()
	clicking = true
	motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(glyph,"scale",Vector2.ONE*0.92,0.05)
	motion.tween_property(glyph,"scale",Vector2.ONE*1.04,0.08)
	motion.tween_property(glyph,"scale",Vector2.ONE,0.11)
	motion.parallel().tween_property(glyph,"rotation_degrees",0.0,0.11)
	motion.tween_callback(func() -> void: clicking = false)
