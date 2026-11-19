extends Control
## Presentation only. Scene/goal/progress come from the existing story model.
const INK := Color("584938")
const Layout := preload("res://scripts/story/ui_layout.gd")
var paper: AtlasTexture
var paper_accent: AtlasTexture
var reading_mode := false
var place: Label
var status: Label
var objective: Label
var button: Button
var collapsed := false
var done := false
var goal_id := ""
var progress := 0
var motion: Tween
var color_motion: Tween
var completion_until := 0

func _ready() -> void:
	position = Vector2.ONE * Layout.SAFE
	scale = Vector2.ONE * 1.12
	# Ignore transparent export padding, retaining the original artwork.
	paper = AtlasTexture.new()
	paper.atlas = preload("res://assets/ui-v1/task-paper.png")
	paper.region = Rect2(25,160,2010,475)
	paper_accent = AtlasTexture.new()
	paper_accent.atlas = paper.atlas
	paper_accent.region = Rect2(1830,40,215,145)
	size = Vector2(300,75)
	mouse_filter = Control.MOUSE_FILTER_STOP
	button = Button.new()
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: collapsed = not collapsed; _layout())
	button.tooltip_text = "展开 / 收起当前任务"
	add_child(button)
	button.position = Vector2.ZERO
	for state: String in ["normal","hover","pressed"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("c3a16a")
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(4)
	button.add_theme_stylebox_override("focus",focus)
	place = _label(14)
	place.position = Vector2(32,9)
	place.size = Vector2(170,22)
	place.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status = _label(12)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.position = Vector2(199,8)
	status.size = Vector2(85,22)
	status.add_theme_color_override("font_color",Color("8a785e"))
	objective = _label(16)
	objective.position = Vector2(32,40)
	objective.size = Vector2(252,28)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_theme_constant_override("outline_size",1)
	objective.add_theme_color_override("font_outline_color",INK)
	_layout()

func _label(points: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font",preload("res://assets/fonts/SourceHanSansSC-Regular.otf"))
	label.add_theme_font_size_override("font_size",points)
	label.add_theme_color_override("font_color",INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func sync(location: String, id: String, text: String, marker: String, count: int, finished: bool) -> void:
	place.text = location
	status.text = marker
	if id != goal_id:
		goal_id = id
		progress = count
		collapsed = false
		completion_until = 0
		if motion: motion.kill()
		modulate.a = 0.0
		position.y = Layout.SAFE - 5
		motion = create_tween().set_parallel(true)
		motion.tween_property(self,"modulate:a",1.0,0.28)
		motion.tween_property(self,"position:y",Layout.SAFE,0.28)
	elif count > progress:
		progress = count
		completion_until = Time.get_ticks_msec() + 320
		collapsed = false
	var next_done := finished or Time.get_ticks_msec() < completion_until
	if next_done != done:
		if color_motion: color_motion.kill()
		color_motion = create_tween()
		var from_color: Color = objective.get_theme_color("font_color")
		var to_color := Color("948775") if next_done else INK
		color_motion.tween_method(func(value: Color) -> void:
			objective.add_theme_color_override("font_color",value)
			objective.add_theme_color_override("font_outline_color",value),from_color,to_color,0.24)
	done = next_done
	objective.text = text
	_layout()

func _layout() -> void:
	var compact := collapsed or reading_mode
	objective.visible = not compact
	# Expand for long translated goals without clipping or single-character columns.
	var rows := maxi(1,ceili(objective.get_theme_font("font").get_string_size(objective.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x / 252.0))
	size.x = 266.6667 if compact else 300.0
	size.y = 40 if compact else maxf(75,49+rows*23)
	status.visible = not reading_mode
	place.size.x = 215 if reading_mode else (size.x-130)
	status.position.x = size.x-101
	objective.size.y = maxf(28,rows*21)
	button.size = size
	button.accessibility_name = place.text + "，" + status.text + "，" + objective.text
	queue_redraw()

func _draw() -> void:
	if paper: draw_texture_rect(paper,Rect2(Vector2.ZERO,size),false)
	if paper_accent: draw_texture_rect(paper_accent,Rect2(size.x-26,-9,25,17),false)
	# Small location pin and a restrained divider, drawn in design coordinates.
	draw_arc(Vector2(18,17),4.2,PI,TAU,16,INK,1.2,true)
	draw_polyline(PackedVector2Array([Vector2(13.8,17),Vector2(18,25),Vector2(22.2,17)]),INK,1.2,true)
	draw_circle(Vector2(18,17),1.3,INK,true)
	if not collapsed and not reading_mode:
		draw_line(Vector2(15,35),Vector2(285,35),Color("ddd1b9"),0.8,true)
		if done:
			draw_polyline(PackedVector2Array([Vector2(14,51),Vector2(17,54),Vector2(23,47)]),Color("91866e"),1.8,true)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(18,46),Vector2(23,51),Vector2(18,56),Vector2(13,51)]),Color("d5ae55"))
		# Nearly invisible paper fibers; no stains or heavy decoration.
		for x in range(20,280,17):
			draw_line(Vector2(x,size.y-5),Vector2(x+5,size.y-5),Color(0.6,0.48,0.30,0.035),0.5)

func _paper() -> StyleBoxFlat:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("faf3e3")
	paper.border_color = Color("d6c8ac")
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(4)
	paper.shadow_color = Color(0.18,0.13,0.07,0.12)
	paper.shadow_offset = Vector2(0,2)
	paper.shadow_size = 3
	return paper
