extends HBoxContainer
## Small native paper tabs; no popup window or third-party control.
signal item_selected(index: int)
var items: Array = []
var buttons: Array[Button] = []
var selected := 0
func _ready() -> void:
	add_theme_constant_override("separation",8)
	var group := ButtonGroup.new()
	for index in range(items.size()):
		var button := Button.new()
		button.text = items[index]
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 36
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size",16)
		for state: String in ["normal","hover","pressed","focus"]:
			var paper := StyleBoxFlat.new()
			paper.bg_color = Color("efd28f") if state == "pressed" else Color("f9e5b7") if state == "hover" else Color("fcf0d6")
			paper.border_color = Color("9d7d54")
			paper.set_border_width_all(2 if state == "focus" else 1)
			paper.set_corner_radius_all(7)
			paper.content_margin_left = 9
			paper.content_margin_right = 9
			button.add_theme_stylebox_override(state,paper)
		for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: button.add_theme_color_override(state,Color("604b38"))
		button.pressed.connect(func() -> void: select(index); item_selected.emit(index))
		add_child(button)
		buttons.append(button)
	select(selected)
func select(index: int) -> void:
	selected = clampi(index,0,maxi(0,items.size()-1))
	for at in range(buttons.size()): buttons[at].set_pressed_no_signal(at == selected)
