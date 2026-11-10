extends HBoxContainer

signal use_requested(id: StringName)

var _slots: Dictionary = {}
var _counts: Dictionary = {}
var _selected: StringName = &""
var _use: Button
var _message: Label
var _notice: Timer

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var heading := Label.new()
	heading.name = "InventoryHeading"
	heading.text = "道具栏"
	heading.add_theme_font_size_override("font_size", 15)
	add_child(heading)
	_use = Button.new()
	_use.name = "UseItem"
	_use.text = "使用"
	_use.pressed.connect(func(): use_requested.emit(_selected))
	add_child(_use)
	_message = Label.new()
	_message.name = "ItemNotice"
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size", 14)
	add_child(_message)
	_notice = Timer.new()
	_notice.one_shot = true
	_notice.timeout.connect(func(): _message.text = "")
	add_child(_notice)
	_refresh()

func register_item(id: StringName, label: String, icon: Texture2D, active_use: bool = true) -> void:
	if _slots.has(id):
		return
	var button := Button.new()
	button.name = String(id)
	button.icon = icon
	button.add_theme_constant_override("icon_max_width", 24)
	if active_use:
		button.toggle_mode = true
		button.pressed.connect(_select.bind(id))
	else:
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(button)
	move_child(button, _use.get_index())
	_slots[id] = {"button":button, "label":label, "active_use":active_use}
	_refresh()

func quantity(id: StringName) -> int:
	return int(_counts.get(id, 0))

func grant(id: StringName) -> void:
	_counts[id] = quantity(id) + 1
	if _slots[id].active_use:
		_selected = id
	show_notice("获得 %s ×1" % _slots[id].label)
	_refresh()

func consume(id: StringName) -> bool:
	if quantity(id) == 0:
		return false
	_counts[id] = quantity(id) - 1
	_refresh()
	return true

func clear_items() -> void:
	_counts.clear()
	_selected = &""
	_notice.stop()
	_message.text = ""
	_refresh()

func show_notice(text: String) -> void:
	_message.text = text
	_notice.start(4.0)

func flash_item(id: StringName) -> void:
	var button: Button = _slots[id].button
	button.modulate = Color("ffdb89")
	create_tween().tween_property(button, "modulate", Color.WHITE, 0.50)

func _select(id: StringName) -> void:
	_selected = id
	_refresh()

func _refresh() -> void:
	for id: StringName in _slots:
		var slot: Dictionary = _slots[id]
		slot.button.text = "%s ×%d" % [slot.label, quantity(id)]
		if slot.active_use:
			slot.button.set_pressed_no_signal(id == _selected)
	_use.disabled = quantity(_selected) == 0
