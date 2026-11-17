extends Control
## Native report scene. Artwork/geometry are extracted from the approved HTML;
## every glyph is rendered by Godot from the original report data and font.
signal continued
const DESIGN_SIZE := Vector2(1920,1080)
const HAND := preload("res://assets/fonts/YeLiHangJiuLinKaTong.ttf")
const SANS := preload("res://assets/fonts/SourceHanSansSC-Regular.otf")
const PAPER := preload("res://assets/report/report1-paper.png")
const LAYOUT_PATH := "res://data/report1_layout.json"
var frame: Control
var continue_button: Button
var text_groups: Dictionary = {}
var body_parts: PackedStringArray
var layout_data: Dictionary
var _continuing := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	frame = Control.new()
	frame.name = "Design1920x1080"
	frame.size = DESIGN_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var background := TextureRect.new()
	background.name = "ApprovedPaperArtwork"
	background.texture = PAPER
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.size = DESIGN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(background)
	layout_data = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/day01_extension.json"))
	body_parts = str(report.report).split("\n\n")
	var text := {"title":report.report_title,"date":report.report_date,"opening":body_parts[0],"work":body_parts[1],"school":body_parts[2],"signature":body_parts[3],"photo-label":"面包店","word-strip":"rain smile","page-number":"1"}
	for section: Dictionary in layout_data.sections:
		_build_text(section,text[section.id])
	_build_continue()
	resized.connect(_fit)
	_fit()

func _build_text(section: Dictionary, text: String) -> void:
	var r: Array = section.rect
	var group := Control.new()
	group.name = str(section.id).to_pascal_case()
	group.position = Vector2(r[0],r[1])
	group.size = Vector2(r[2],r[3])
	group.pivot_offset = group.size/2
	group.rotation_degrees = section.angle
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(group)
	text_groups[section.id] = group
	var font: Font = HAND
	if section.letter_spacing > 0:
		var spaced := FontVariation.new()
		spaced.base_font = HAND
		spaced.spacing_glyph = int(section.letter_spacing)
		font = spaced
	var lines := PackedStringArray()
	var start := 0
	if section.line_lengths.is_empty():
		lines.append(text)
	else:
		for length: int in section.line_lengths:
			lines.append(text.substr(start,length))
			start += length
		assert(start == text.length(),"Report source changed; rebuild the approved layout before exporting.")
	var font_size: int = section.font_size
	var padding := 28.0 if section.id == "photo-label" else 0.0
	for index in range(lines.size()):
		var line := Label.new()
		line.name = "Line"+str(index+1)
		line.text = lines[index]
		line.add_theme_font_override("font",font)
		line.add_theme_font_size_override("font_size",font_size)
		line.add_theme_color_override("font_color",Color("493f30"))
		line.add_theme_constant_override("outline_size",0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.position = Vector2(padding,section.baseline-font.get_ascent(font_size)+index*48)
		line.size = Vector2(group.size.x-padding*2,font.get_height(font_size))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if section.center else HORIZONTAL_ALIGNMENT_LEFT
		group.add_child(line)

func _build_continue() -> void:
	continue_button = Button.new()
	continue_button.name = "Continue"
	continue_button.text = "继续  ≫"
	continue_button.position = Vector2(1535,916)
	continue_button.size = Vector2(260,60)
	continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	continue_button.add_theme_font_override("font",SANS)
	continue_button.add_theme_font_size_override("font_size",26)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("f7d487")
	normal.border_color = Color("927452")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0,3)
	normal.shadow_color = Color(0.14,0.12,0.08,0.18)
	continue_button.add_theme_stylebox_override("normal",normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("ffe9b1")
	continue_button.add_theme_stylebox_override("hover",hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("c3a16b")
	continue_button.add_theme_stylebox_override("pressed",pressed)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		continue_button.add_theme_color_override(state,Color("34464b"))
	frame.add_child(continue_button)
	continue_button.pressed.connect(request_continue)

func _fit() -> void:
	if not is_instance_valid(frame): return
	var ratio := minf(size.x/DESIGN_SIZE.x,size.y/DESIGN_SIZE.y)
	frame.scale = Vector2.ONE*ratio
	frame.position = (size-DESIGN_SIZE*ratio)/2

func open() -> void:
	_continuing = false
	continue_button.disabled = false
	show()
	continue_button.grab_focus()

func request_continue() -> void:
	if _continuing or not is_visible_in_tree(): return
	_continuing = true
	continue_button.disabled = true
	continued.emit()

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_RIGHT:
		request_continue();get_viewport().set_input_as_handled()

func original_body() -> String:
	var paragraphs := PackedStringArray()
	for id: String in ["opening","work","school","signature"]:
		var paragraph := ""
		for line: Label in text_groups[id].get_children(): paragraph += line.text
		paragraphs.append(paragraph)
	return "\n\n".join(paragraphs)
