extends CanvasLayer
## One paper cutout, updated at 10 fps. Source PNGs are never modified.
const ART := [preload("res://modules/loading/assets/charlie_bouquet.png"), preload("res://modules/loading/assets/charlie_thinking.png"), preload("res://modules/loading/assets/charlie_reading.png")]
const HAND := preload("res://modules/visual_novel/assets/fonts/YeLiHangJiuLinKaTong.ttf")
const DOTS := ["", ".", "..", "...", "..", "."]
signal pose_changed(index: int, hold_seconds: float)
signal revealed
@export_range(2.0, 4.0, 0.1) var minimum_display_seconds := 3.0
var _revealed := false
var character: TextureRect
var caption: Label
var paper: Control
var pose_index := 0
var hold_seconds := 1.5
var phase := "enter"
var _rng := RandomNumberGenerator.new()
var _textures: Array[AtlasTexture] = []
var _started := 0
var _last_frame := -1
var _phase_frame := 0
var _hold_frames := 0
var _tilt := 0.0
var _offset := Vector2.ZERO
var _center := Vector2.ZERO
var _caption_center := Vector2.ZERO
var _unit := 1.0
var _closing := false
var _restore_aspect: Window.ContentScaleAspect
var _last_presented := 0
var _drawing := false

func _ready() -> void:
	layer = 200
	name = "PaperLoadingScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_restore_aspect = get_window().content_scale_aspect
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	paper = Control.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	var white := ColorRect.new()
	white.color = Color.WHITE
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.add_child(white)
	for texture: Texture2D in ART:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = texture.get_image().get_used_rect()
		atlas.filter_clip = true
		_textures.append(atlas)
	character = TextureRect.new()
	character.name = "SingleCharacter"
	character.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	paper.add_child(character)
	caption = Label.new()
	caption.name = "LoadingCaption"
	caption.add_theme_font_override("font", HAND)
	caption.add_theme_color_override("font_color", Color("705039"))
	caption.add_theme_constant_override("outline_size", 0)
	caption.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(caption)
	get_viewport().size_changed.connect(_layout)
	_started = Time.get_ticks_msec()
	_last_frame = 0
	caption.text = "loading"
	_new_pose()
	_layout()
	_step()
	_last_presented = Time.get_ticks_msec()
	get_tree().node_added.connect(_during_scene_setup)
	paper.modulate.a = 0.0
	var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	reveal.tween_property(paper, "modulate:a", 1.0, 0.18)
	reveal.tween_callback(func():
		_revealed = true
		revealed.emit())

func _during_scene_setup(_node: Node) -> void:
	# Existing procedural levels create many nodes synchronously in _ready().
	# Keep the independent paper animation drawing between those additions,
	# without changing the level builders or advancing gameplay timers.
	if _closing or _drawing or Time.get_ticks_msec() - _last_presented < 100: return
	if DisplayServer.get_name() == "headless": return
	_drawing = true
	_process(0.0)
	# Queueing Control redraws normally waits for the next idle frame. Submit
	# the same artwork/text now so synchronous level setup cannot stall them.
	RenderingServer.canvas_item_clear(character.get_canvas_item())
	character.texture.draw_rect(character.get_canvas_item(), Rect2(Vector2.ZERO, character.size), false)
	RenderingServer.canvas_item_clear(caption.get_canvas_item())
	var font_size := caption.get_theme_font_size("font_size")
	var font := caption.get_theme_font("font")
	var baseline := (caption.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	font.draw_string(caption.get_canvas_item(), Vector2(0, baseline), caption.text, HORIZONTAL_ALIGNMENT_CENTER, caption.size.x, font_size, Color("705039"))
	RenderingServer.force_draw(true)
	_last_presented = Time.get_ticks_msec()
	_drawing = false

func _layout() -> void:
	if not is_instance_valid(character): return
	var viewport_size := get_viewport().get_visible_rect().size
	_unit = minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	_center = viewport_size * Vector2(0.5, 0.45)
	_caption_center = Vector2(viewport_size.x * 0.5, _center.y + viewport_size.y * 0.21 + 66.0 * _unit)
	var texture_size := character.texture.get_size()
	character.size = texture_size * (viewport_size.y * 0.42 / texture_size.y)
	character.pivot_offset = character.size * 0.5
	caption.add_theme_font_size_override("font_size", maxi(18, roundi(42.0 * _unit)))
	caption.size = Vector2(340.0, 76.0) * _unit
	caption.pivot_offset = caption.size * 0.5
	caption.position = _caption_center - caption.pivot_offset
	_place(1.0, Vector2.ZERO)

func _new_pose() -> void:
	character.texture = _textures[pose_index]
	_tilt = deg_to_rad(_rng.randf_range(-6.0, 6.0))
	_offset = Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-3.0, 3.0))
	hold_seconds = _rng.randf_range(1.2, 1.8)
	_hold_frames = roundi(hold_seconds * 10.0) - 2
	phase = "enter"
	_phase_frame = 0
	_layout()
	pose_changed.emit(pose_index, hold_seconds)

func _place(factor: float, shift: Vector2) -> void:
	character.scale = Vector2.ONE * factor
	character.rotation = _tilt
	character.position = _center - character.pivot_offset + (_offset + shift) * _unit

func _process(_delta: float) -> void:
	# Destinations may restore their own letterboxing during _ready().
	if get_window().content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
		_restore_aspect = get_window().content_scale_aspect
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var elapsed := Time.get_ticks_msec() - _started
	var frame := int(elapsed / 100)
	if frame == _last_frame: return
	# Do not replay accumulated jitter after a slow frame.
	_last_frame = frame
	_step()
	caption.text = "loading" + DOTS[int(elapsed / 250) % DOTS.size()]
	caption.position = _caption_center - caption.pivot_offset + Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6)) * _unit
	caption.rotation = deg_to_rad(_rng.randf_range(-0.8, 0.8)) if frame % 5 == 0 else 0.0

func _step() -> void:
	match phase:
		"enter":
			_place(1.035 if _phase_frame == 0 else 1.0, Vector2(0, -5 if _phase_frame == 0 else 0))
			_phase_frame += 1
			if _phase_frame >= 2:
				phase = "hold"
				_phase_frame = 0
		"hold":
			if _phase_frame % 4 == 0:
				_place(1.0, Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.8, 1.8)))
				character.rotation += deg_to_rad(_rng.randf_range(-0.6, 0.6))
			_phase_frame += 1
			if _phase_frame >= _hold_frames:
				phase = "exit"
				_place(0.88, Vector2(3, 6))
		"exit":
			# Replace the only texture atomically; never crossfade two people.
			pose_index = (pose_index + 1) % ART.size()
			_new_pose()
			_step()

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func wait_for_display_time() -> void:
	var remaining := minimum_display_seconds - float(Time.get_ticks_msec() - _started) / 1000.0
	if remaining > 0.0:
		await get_tree().create_timer(remaining, true, false, true).timeout

func finish() -> void:
	if _closing: return
	_closing = true
	if get_tree().node_added.is_connected(_during_scene_setup):
		get_tree().node_added.disconnect(_during_scene_setup)
	await wait_for_display_time()
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	fade.tween_property(paper, "modulate:a", 0.0, 0.24)
	await fade.finished
	queue_free()

func _exit_tree() -> void:
	get_window().content_scale_aspect = _restore_aspect
	var tree := get_tree()
	if tree.has_meta(&"paper_loading_screen") and tree.get_meta(&"paper_loading_screen") == self:
		tree.remove_meta(&"paper_loading_screen")
