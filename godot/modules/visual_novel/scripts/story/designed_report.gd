extends "res://modules/visual_novel/scripts/story/report1_page.gd"
## Exact approved preview artwork with live Godot text, not an iframe or screenshot of text.
var report_id := "report2-0304"
var artwork_path := ""
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	frame=Control.new();frame.size=DESIGN_SIZE;frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(frame)
	if not artwork_path.is_empty():
		var image := TextureRect.new()
		image.name = "FinalReportArtwork"
		image.texture = load(artwork_path)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.size = DESIGN_SIZE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(image)
		_build_continue()
		continue_button.position = Vector2(1585,1010)
		continue_button.size = Vector2(250,48)
		continue_button.add_theme_font_size_override("font_size",22)
		resized.connect(_fit)
		_fit()
		return
	var variant: String = {"report2-0304":"march4","report2-0306-maze":"march6","report2-0306-decision":"march6","report2-0308":"march8"}.get(report_id,"march4")
	var artwork:=TextureRect.new()
	artwork.texture=load("res://modules/visual_novel/assets/report/report-"+variant+"-paper.png")
	artwork.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;artwork.size=DESIGN_SIZE;artwork.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(artwork)
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://modules/visual_novel/data/report-"+variant+"-layout.json"))
	for section: Dictionary in layout.sections:
		# The right paragraph is the later decision event; never reveal it at maze completion.
		if report_id=="report2-0306-maze" and section.id=="right":continue
		for line:Dictionary in section.lines:
			var label:=Label.new();label.text=line.text
			label.add_theme_font_override("font",HAND);label.add_theme_font_size_override("font_size",int(section.font_size))
			label.add_theme_color_override("font_color",Color("493f30"))
			label.position=Vector2(line.x,line.baseline-HAND.get_ascent(int(section.font_size)))
			label.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(label)
	_build_continue()
	continue_button.position=Vector2(1580,990);continue_button.size=Vector2(250,56)
	resized.connect(_fit);_fit()
func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_RIGHT:
		request_continue();get_viewport().set_input_as_handled()
