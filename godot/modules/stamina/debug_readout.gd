extends PanelContainer
## Temporary functional bar. Detailed developer diagnostics are opt-in in the Remote Inspector.
@export var show_details := false
var actor: CharacterBody3D
var bar: ProgressBar
var number: Label
var details: Label
var fill: StyleBoxFlat
var clock := 0.0
func _ready() -> void:
	name = "StaminaDebugReadout"
	mouse_filter = Control.MOUSE_FILTER_PASS
	position = Vector2(12, 12)
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.98, 0.97, 0.93, 0.86)
	card.set_corner_radius_all(8)
	card.content_margin_left = 10
	card.content_margin_right = 10
	card.content_margin_top = 7
	card.content_margin_bottom = 7
	add_theme_stylebox_override("panel", card)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	add_child(stack)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	stack.add_child(row)
	var caption := Label.new()
	caption.text = "体力"
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("566a68"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	bar = ProgressBar.new()
	bar.name = "StaminaBar"
	bar.custom_minimum_size = Vector2(166, 9)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color("d8ded8")
	track.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", track)
	fill = StyleBoxFlat.new()
	fill.bg_color = Color("78a7a5")
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	number = Label.new()
	number.custom_minimum_size.x = 58
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.add_theme_font_size_override("font_size", 11)
	number.add_theme_color_override("font_color", Color("667570"))
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(number)
	details = Label.new()
	details.visible = show_details
	details.add_theme_font_size_override("font_size", 11)
	details.add_theme_color_override("font_color", Color("607572"))
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(details)
	bar.max_value = maxf(1.0, actor.stamina.settings.maximum)
	bar.value = actor.stamina.current
	_update_text()
func _process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	var s = actor.stamina
	bar.max_value = maxf(1.0, s.settings.maximum)
	bar.value = move_toward(bar.value, s.current, delta * bar.max_value * 4.0)
	var tone := Color("d09a7e") if s.percentage()<0.20 else Color("78a7a5")
	if s.is_recovering:
		tone = Color("8ab49b")
	fill.bg_color = fill.bg_color.lerp(tone, minf(delta * 6.0, 1.0))
	clock += delta
	if clock >= 0.1:
		clock = 0.0
		_update_text()
func _update_text() -> void:
	if not is_instance_valid(actor):
		return
	var s = actor.stamina
	number.text = "%.0f / %.0f" % [s.current, s.settings.maximum]
	var zone := "普通通道"
	if not s.zones.is_empty():
		zone = "快速恢复区 · " + ("教堂" if &"chapel" in s.zones.values() else "雕像院子")
	var feedback := "屏障恢复：未触发"
	if s.restore_feedback_seconds > 0.0:
		var source: String = {"cake":"蛋糕", "barrier":"蓝色屏障"}.get(String(s.last_restore_source), String(s.last_restore_source))
		feedback = "最近恢复：%s +%.1f" % [source, s.last_restore_amount]
	elif int(s.restore_counts.get(&"barrier", 0)) > 0:
		feedback = "屏障恢复：已触发 %d 次" % s.restore_counts[&"barrier"]
	tooltip_text = "冲刺：%s　恢复：%s　耗尽：%s\n%s\n%s" % [
		"是" if s.is_sprinting else "否", "是" if s.is_recovering else "否", "是" if s.is_exhausted else "否", zone, feedback]
	if details.visible != show_details:
		details.visible = show_details
		reset_size.call_deferred()
	details.text = tooltip_text
