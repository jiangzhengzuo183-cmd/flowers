extends RefCounted
static var _font: Font
static func font() -> Font:
	if _font == null:
		_font = preload("res://modules/visual_novel/assets/fonts/YeLiHangJiuLinKaTong.ttf").duplicate()
		_font.fallbacks = [preload("res://assets/fonts/SourceHanSansSC-Regular.otf")]
	return _font
static func apply(control: Control,size: int,seed := 0.0,wiggle := true) -> void:
	control.add_theme_font_override("font",font())
	control.add_theme_font_size_override("font_size",size)
	for key in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		control.add_theme_color_override(key,Color("705039"))
	if wiggle:
		var ink := ShaderMaterial.new()
		ink.shader = preload("res://modules/main_menu/hand_wobble.gdshader")
		ink.set_shader_parameter("seed",seed)
		ink.set_shader_parameter("strength",0.75 if size>=36 else 0.52)
		control.material = ink
