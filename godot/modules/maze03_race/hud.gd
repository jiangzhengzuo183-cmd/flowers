extends Control
## Temporary race readout, contained in the game viewport; no replacement of the existing HUD.
var external_result := false
var timer: Label
var headline: Label
var message: Label
var result_panel: PanelContainer
var result_label: Label
func _ready() -> void:
 name = "RaceReadout"
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 timer = _label(24)
 timer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 timer.offset_left = -210
 timer.offset_top = 16
 timer.offset_right = -20
 timer.offset_bottom = 52
 timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 headline = _label(66)
 headline.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 headline.offset_left = -220
 headline.offset_top = -82
 headline.offset_right = 220
 headline.offset_bottom = 8
 headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 message = _label(16)
 message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 message.offset_left = -230
 message.offset_top = 58
 message.offset_right = 230
 message.offset_bottom = 94
 message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 result_panel = PanelContainer.new()
 result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(result_panel)
 result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 result_panel.offset_left = -230
 result_panel.offset_top = -85
 result_panel.offset_right = 230
 result_panel.offset_bottom = 85
 result_panel.custom_minimum_size = Vector2(460,160)
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.96,0.97,0.95,0.94)
 style.set_corner_radius_all(12)
 style.content_margin_left = 24
 style.content_margin_right = 24
 style.content_margin_top = 22
 style.content_margin_bottom = 22
 result_panel.add_theme_stylebox_override("panel",style)
 result_label = Label.new()
 result_label.add_theme_color_override("font_color",Color("374b55"))
 result_label.add_theme_font_size_override("font_size",20)
 result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 result_panel.add_child(result_label)
 result_panel.hide()

func _label(font_size: int) -> Label:
 var label := Label.new()
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",Color("f6fcff"))
 label.add_theme_color_override("font_shadow_color",Color(0.14,0.22,0.27,0.8))
 label.add_theme_constant_override("shadow_offset_x",1)
 label.add_theme_constant_override("shadow_offset_y",2)
 add_child(label)
 return label

func update_race(state: String, elapsed: float, count: String, mouse_finished: bool) -> void:
 timer.text = "比赛  %02d:%02d" % [floori(elapsed/60.0),floori(fmod(elapsed,60.0))]
 headline.text = count
 headline.visible = not count.is_empty()
 message.text = "阿尔吉侬已到达，继续完成你的路线。" if mouse_finished and state=="RACING" else ""

func show_result(result: Dictionary) -> void:
 if external_result:return
 headline.hide()
 result_label.text = "%s\n查理  %.2f 秒\n阿尔吉侬  %s\n重开可再次挑战" % [result.title,result.charlie_time,"%.2f 秒" % result.mouse_time if result.mouse_time>=0 else "尚未抵达"]
 result_panel.show()
