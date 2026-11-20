extends Control
## Scoped modal: layout, focus and controls do not touch the narrative model.
signal closed
const Preferences := preload("res://scripts/story/story_preferences.gd")
const INK := Color("604b38")
const MUTED := Color("78878a")
var preferences: RefCounted = Preferences.shared()
var panel: PanelContainer
var controls: Dictionary = {}
var percentages: Dictionary = {}
var status: Label
var reset_actions: HBoxContainer
var reset_button: Button
var previous_focus: Control

func _ready() -> void:
	name = "PaperSettings"
	z_index = 130
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.12,0.16,0.16,0.23)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.name = "SettingsPaper"
	panel.custom_minimum_size = Vector2(700,0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("fcf1d9")
	paper.border_color = Color("a37e50")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(18)
	paper.shadow_color = Color(0.13,0.10,0.06,0.22)
	paper.shadow_size = 14
	paper.shadow_offset = Vector2(0,6)
	panel.add_theme_stylebox_override("panel",paper)
	add_child(panel)
	var grain := TextureRect.new()
	grain.texture = preload("res://assets/ui-v1/monologue-paper.png")
	grain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grain.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	grain.modulate.a = 0.32
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(grain)
	var margins := MarginContainer.new()
	for side: String in ["left","right"]: margins.add_theme_constant_override("margin_"+side,34)
	for side: String in ["top","bottom"]: margins.add_theme_constant_override("margin_"+side,24)
	panel.add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margins.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",12)
	column.add_child(header)
	var title := label("设置",28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := button("×",close_panel)
	close.name = "CloseSettings"
	close.accessibility_name = "关闭设置"
	close.custom_minimum_size = Vector2(40,40)
	close.add_theme_font_size_override("font_size",28)
	header.add_child(close)
	var audio_heading := section(column,"音频")
	var mute := button("静音",func() -> void: pass)
	mute.toggle_mode = true
	mute.toggled.connect(func(active: bool) -> void: preferences.set_value("mute",active))
	controls.mute = mute
	audio_heading.add_child(mute)
	for entry: Array in [["master","主音量"],["music","背景音乐"],["effects","音效音量"]]: _audio_row(column,entry[0],entry[1])
	section(column,"画面")
	_choice(column,"fullscreen","窗口模式",["窗口化","全屏"])
	_choice(column,"aspect","画面比例",["自动适配","16:9","16:10"])
	var hint := label("画面等比显示，额外区域留白。",14)
	hint.add_theme_color_override("font_color",MUTED)
	column.add_child(hint)
	section(column,"对话")
	_choice(column,"text_speed","文字显示速度",["慢","标准","快"])
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	column.add_child(footer)
	reset_button = button("恢复默认设置",func() -> void: reset_button.hide(); reset_actions.show(); _fit.call_deferred())
	reset_button.name = "ResetDefaults"
	footer.add_child(reset_button)
	reset_actions = HBoxContainer.new()
	reset_actions.add_theme_constant_override("separation",10)
	footer.add_child(reset_actions)
	reset_actions.add_child(label("恢复全部设置？",16))
	reset_actions.add_child(button("恢复",func() -> void:
		preferences.reset()
		preferences.apply_window_mode()
		_cancel_reset()
		_sync()))
	reset_actions.add_child(button("取消",_cancel_reset))
	reset_actions.hide()
	status = label("",14)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_color_override("font_color",MUTED)
	footer.add_child(status)
	var done := button("完成",close_panel)
	done.name = "DoneSettings"
	footer.add_child(done)
	preferences.changed.connect(_preference_changed)
	resized.connect(_fit)
	panel.minimum_size_changed.connect(func() -> void: _fit.call_deferred())
	hide()

func label(text: String, points := 18) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_color_override("font_color",INK)
	item.add_theme_font_size_override("font_size",points)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

func button(text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_font_size_override("font_size",16)
	for state: String in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("edcf89") if state == "pressed" else Color("f7e2ad") if state == "hover" else Color("f9edd3")
		style.border_color = Color("9d7d54")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		item.add_theme_stylebox_override(state,style)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: item.add_theme_color_override(state,INK)
	item.pressed.connect(action)
	return item

func section(column: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	row.add_child(label(text,19))
	var line := HSeparator.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stroke := StyleBoxLine.new()
	stroke.color = Color("d5c4a4")
	stroke.thickness = 1
	line.add_theme_stylebox_override("separator",stroke)
	row.add_child(line)
	column.add_child(row)
	return row

func _row(column: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 36
	row.add_theme_constant_override("separation",18)
	var name_label := label(text)
	name_label.custom_minimum_size.x = 144
	row.add_child(name_label)
	column.add_child(row)
	return row

func _audio_row(column: VBoxContainer, key: String, text: String) -> void:
	var row := _row(column,text)
	var slider := HSlider.new()
	slider.name = key.to_pascal_case()+"Volume"
	slider.accessibility_name = text
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(280,36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state: String in ["slider","grabber_area","grabber_area_highlight"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("d4c4a4") if state == "slider" else Color("d5ad57")
		track.set_corner_radius_all(4)
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		slider.add_theme_stylebox_override(state,track)
	var dot := GradientTexture2D.new()
	dot.width = 18
	dot.height = 18
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5,0.5)
	dot.fill_to = Vector2(1,0.5)
	dot.gradient = Gradient.new()
	dot.gradient.offsets = PackedFloat32Array([0,0.72,0.8,0.96,1])
	dot.gradient.colors = PackedColorArray([Color("f8dfa0"),Color("f8dfa0"),Color("94744e"),Color("94744e"),Color.TRANSPARENT])
	slider.add_theme_icon_override("grabber",dot)
	slider.add_theme_icon_override("grabber_highlight",dot)
	row.add_child(slider)
	var value_label := label("",16)
	value_label.custom_minimum_size.x = 46
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	controls[key] = slider
	percentages[key] = value_label
	slider.value_changed.connect(func(value: float) -> void: preferences.set_value(key,value))

func _choice(column: VBoxContainer, key: String, text: String, items: Array) -> void:
	var row := _row(column,text)
	var option := preload("res://scripts/story/paper_choice.gd").new()
	option.name = key.to_pascal_case()
	option.items = items
	option.accessibility_name = text
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(option)
	controls[key] = option
	option.item_selected.connect(func(index: int) -> void:
		preferences.set_value(key,bool(index) if key == "fullscreen" else index)
		if key == "fullscreen":
			preferences.apply_window_mode()
			_sync.call_deferred())

func _preference_changed(_key: String, _value: Variant) -> void:
	_sync()

func _sync() -> void:
	for key: String in ["master","music","effects"]:
		controls[key].set_value_no_signal(preferences.values[key])
		percentages[key].text = "%d%%" % roundi(float(preferences.values[key])*100)
	controls.fullscreen.select(1 if preferences.is_fullscreen() else 0)
	controls.mute.set_pressed_no_signal(preferences.values.mute)
	controls.aspect.select(preferences.values.aspect)
	controls.text_speed.select(preferences.values.text_speed)
	status.text = "已保存" if preferences.save_error == OK else "保存失败"
	if OS.has_feature("web") and preferences.values.fullscreen and not preferences.is_fullscreen(): status.text = "全屏需点击进入"

func _cancel_reset() -> void:
	reset_actions.hide()
	reset_button.show()
	_fit.call_deferred()

func _fit() -> void:
	if not is_instance_valid(panel): return
	panel.reset_size()
	var factor := minf(1.0,minf((size.x-48)/panel.size.x,(size.y-48)/panel.size.y))
	panel.scale = Vector2.ONE*maxf(factor,0.1)
	panel.position = (size-panel.size*panel.scale)/2

func open() -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	_sync()
	_cancel_reset()
	show()
	_fit.call_deferred()
	controls.master.grab_focus()

func close_panel() -> void:
	hide()
	closed.emit()
	if is_instance_valid(previous_focus): previous_focus.grab_focus.call_deferred()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		close_panel()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_SPACE,KEY_ENTER,KEY_RIGHT,KEY_LEFT]:
			# Focused sliders/buttons still receive GUI input; the story stays paused.
			pass

func _exit_tree() -> void:
	if preferences.changed.is_connected(_preference_changed): preferences.changed.disconnect(_preference_changed)
