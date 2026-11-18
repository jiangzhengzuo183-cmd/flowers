extends HBoxContainer
## One scene-local, three-item inventory. Every copy occupies one physical slot.
signal use_requested(id: StringName)
signal changed
signal notice_requested(text: String)
signal item_flashed(id: StringName)
const CAPACITY := 3
var _slots: Dictionary = {}
var _contents: Array[StringName] = [&"", &"", &""]
var _selected_slot := 0
var _full_notice_at := -2000
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
	_use.pressed.connect(request_selected_use)
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
	if _slots.has(id): return
	var button := Button.new()
	button.name = String(id)
	button.icon = icon
	button.add_theme_constant_override("icon_max_width", 24)
	if active_use:
		button.toggle_mode = true
		button.pressed.connect(select_item.bind(id))
	else:
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(button)
	move_child(button, _use.get_index())
	_slots[id] = {"button":button, "label":label, "active_use":active_use}
	_refresh()

func quantity(id: StringName) -> int:
	return 0 if id == &"" else _contents.count(id)

func item_count() -> int:
	return CAPACITY - _contents.count(&"")

func can_accept_pickup() -> bool:
	if item_count() < CAPACITY: return true
	var now := Time.get_ticks_msec()
	if now - _full_notice_at >= 2000:
		_full_notice_at = now
		show_notice("道具栏已满 · 请先使用一件道具")
	return false

func grant(id: StringName) -> bool:
	if not _slots.has(id) or not can_accept_pickup(): return false
	var index := _contents.find(&"")
	_contents[index] = id
	if _slots[id].active_use: _selected_slot = index
	show_notice("获得 %s ×1" % _slots[id].label)
	_refresh()
	return true

func consume(id: StringName) -> bool:
	if quantity(id) == 0: return false
	var index := _selected_slot if selected_item() == id else _contents.find(id)
	_contents[index] = &""
	_refresh()
	return true

func clear_items() -> void:
	_contents.assign([&"", &"", &""])
	_selected_slot = 0
	_full_notice_at = -2000
	_notice.stop()
	_message.text = ""
	_refresh()

func show_notice(text: String) -> void:
	notice_requested.emit(text)
	_message.text = text
	_notice.start(4.0)

func flash_item(id: StringName) -> void:
	item_flashed.emit(id)
	var button: Button = _slots[id].button
	button.modulate = Color("ffdb89")
	create_tween().tween_property(button, "modulate", Color.WHITE, 0.50)

func _refresh() -> void:
	for id: StringName in _slots:
		var slot: Dictionary = _slots[id]
		slot.button.text = "%s ×%d" % [slot.label, quantity(id)]
		if slot.active_use: slot.button.set_pressed_no_signal(id == selected_item())
	var current := selected_item()
	_use.disabled = current == &"" or not _slots[current].active_use
	changed.emit()

func snapshot() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for i in CAPACITY:
		var id := _contents[i]
		items.append({"id":id, "slot":i, "label":_slots[id].label if id != &"" else "空道具槽", "quantity":0 if id == &"" else 1, "active_use":id != &"" and _slots[id].active_use})
	return items

func selected_item() -> StringName:
	return _contents[_selected_slot]

func selected_slot() -> int:
	return _selected_slot

func select_slot(index: int) -> void:
	if index < 0 or index >= CAPACITY: return
	_selected_slot = index
	_refresh()

func select_item(id: StringName) -> void:
	var index := _contents.find(id)
	if index >= 0: select_slot(index)

func request_selected_use() -> void:
	var id := selected_item()
	if id == &"": return
	if _slots[id].active_use: use_requested.emit(id)
	else: show_notice("靠近对应机关门按 E 解锁")
