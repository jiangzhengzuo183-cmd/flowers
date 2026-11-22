extends CanvasLayer
## Offline equivalent of the existing browser video overlay; no external player or network.
signal completed
const FILM := preload("res://modules/visual_novel/assets/charlie-dance.ogv")
const FONT := preload("res://modules/visual_novel/assets/fonts/SourceHanSansSC-Regular.otf")
var player: VideoStreamPlayer
var finished := false
var skip: Button

func play(data: Dictionary, audio_options: Dictionary) -> void:
	name = "NativeStoryVideo"
	layer = 70
	var surface := Control.new()
	surface.name = "VideoSurface"
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("17201e")
	surface.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var film := AspectRatioContainer.new()
	film.ratio = 16.0 / 9.0
	film.stretch_mode = AspectRatioContainer.STRETCH_FIT
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(film)
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player = VideoStreamPlayer.new()
	player.name = "Film"
	player.expand = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.stream = FILM
	var volume: float = 0.0 if audio_options.get("mute", false) else clampf(float(audio_options.get("master", 0.7)), 0.0, 1.0)
	player.volume_db = linear_to_db(volume) if volume > 0.0 else -80.0
	film.add_child(player)
	player.finished.connect(_finish)
	var title := Label.new()
	title.text = str(data.get("title", ""))
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("fff6e8"))
	title.position = Vector2(48, 32)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(title)
	skip = Button.new()
	skip.name = "SkipVideo"
	skip.text = "跳过视频 · 继续剧情"
	skip.add_theme_font_override("font", FONT)
	skip.add_theme_font_size_override("font_size", 22)
	skip.add_theme_color_override("font_color", Color("384441"))
	skip.add_theme_color_override("font_hover_color", Color("384441"))
	skip.add_theme_color_override("font_focus_color", Color("384441"))
	skip.add_theme_color_override("font_pressed_color", Color("384441"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f1cf7e")
	style.set_corner_radius_all(8)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	skip.add_theme_stylebox_override("normal", style)
	skip.add_theme_stylebox_override("hover", style)
	surface.add_child(skip)
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skip.offset_right = -40.0
	skip.offset_bottom = -32.0
	skip.offset_left = -340.0
	skip.offset_top = -92.0
	skip.pressed.connect(_finish)
	skip.grab_focus()
	player.play()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if finished: return
	finished = true
	if is_instance_valid(player): player.stop()
	completed.emit()

func _exit_tree() -> void:
	if is_instance_valid(player): player.stop()
