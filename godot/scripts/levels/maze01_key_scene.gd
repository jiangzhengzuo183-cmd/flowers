extends "res://scripts/levels/greybox_scene.gd"
## The normal Maze 01 entrance uses keys. Other scene instances keep their own rules.

const Keys := preload("res://modules/maze_keys/maze01_gate_keys.gd")
const KeyItems := preload("res://modules/maze_keys/maze01_key_items.gd")
const GateFinish := preload("res://art/maze01/dream_gate_finish.gd")
const FullscreenLayout := preload("res://scripts/levels/maze01_fullscreen_layout.gd")
const Perks := preload("res://modules/maze_pickups/maze01_perks.gd")
const INTERACT_REACH := 1.65
@export var use_gate_keys := false
@export var use_marked_pickups := false
@export_range(1.0, 2.0, 0.05) var cake_speed_multiplier := 1.3
@export_range(0.5, 20.0, 0.5) var cake_seconds := 8.0
@export_range(0.5, 15.0, 0.5) var flour_seconds := 3.0
var _key_items: KeyItems
var _perks: Perks
var _web_window: Window
var _previous_aspect: Window.ContentScaleAspect
var _fullscreen_layout: FullscreenLayout

func _ready() -> void:
	if use_gate_keys and dream_art_enabled:
		%GeneratedMaze.replaced_switches = Keys.GATES
	super()
	if not is_instance_valid(_key_items):
		return
	if OS.has_feature("web"):
		_web_window = get_window()
		_previous_aspect = _web_window.content_scale_aspect
		_web_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_key_items.setup_keys(required_exit_gates())
	if use_marked_pickups:
		_perks = Perks.new()
		_perks.name = "MazePickupEffects"
		_perks.boost_multiplier = cake_speed_multiplier
		_perks.boost_seconds = cake_seconds
		_perks.flour_seconds = flour_seconds
		add_child(_perks)
		_perks.install(%Player, %ViewportContainer, _key_items.inventory, sound.play_item_pickup)
	_fullscreen_layout = FullscreenLayout.new()
	_fullscreen_layout.install(self, _key_items.inventory)
	for id: String in Keys.GATES:
		var gate: Node3D = %GeneratedMaze.gates[id]
		var entry: Dictionary = Keys.GATES[id]
		gate.opening_lead_time = entry.charge
		gate.descent_duration = entry.descent
		(gate.get_node("DreamGateFinish") as GateFinish).contact_dust_only = true
	inspection_picker.set_item_text(1, "Door 01 · 入口")
	inspection_picker.set_item_text(2, "Door 04 · 可选捷径")
	inspection_picker.set_item_text(4, "桥洞下幸运钱币" if use_marked_pickups else "桥侧幸运钱币")
	inspection_picker.set_item_text(16, "东侧幸运马蹄铁")
	_refresh_hud()

func _exit_tree() -> void:
	if is_instance_valid(_web_window):
		_web_window.content_scale_aspect = _previous_aspect

func _make_items() -> MazeItems:
	if not use_gate_keys:
		return super()
	_key_items = KeyItems.new()
	if use_marked_pickups:
		_key_items.extra_rabbit_positions = [Vector3(20.4, 0, 3.6), Vector3(1.2, 0, 25.2)]
		_key_items.key_positions = {"D1": Vector3(1.2, 0, 40.8), "D3": Vector3(39.6, 0, 15.9),
			"D4": Vector3(44.4, 0, 25.2)}
	return _key_items

func reset_level() -> void:
	super()
	if is_instance_valid(_perks):
		_perks.reset()

func inspect_location(index: int) -> void:
	if use_marked_pickups and index == 4:
		super(23)
		return
	super(index)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_instance_valid(_key_items):
		super(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_E or event.keycode == KEY_E):
		var id := _nearest_key_gate()
		if not id.is_empty():
			try_activate_gate(id)
			get_viewport().set_input_as_handled()

func try_activate_gate(id: String) -> bool:
	if not is_instance_valid(_key_items):
		return super(id)
	if completed or not Keys.GATES.has(id) or id != _nearest_key_gate():
		return false
	var gate: Node3D = %GeneratedMaze.gates[id]
	var item: StringName = Keys.GATES[id].item
	var inventory := _key_items.inventory
	if gate.is_open or inventory.quantity(item) == 0:
		inventory.show_notice(_gate_hint(id))
		return false
	gate.open_gate()
	if not gate.is_open:
		return false
	inventory.consume(item)
	_key_items.play_key_transfer(gate, item)
	return true

func _nearest_key_gate() -> String:
	if not walk_mode or not %Player.controls_enabled:
		return ""
	var closest := ""
	var best := INTERACT_REACH * INTERACT_REACH
	var feet: Vector3 = %Player.global_position
	var eye := feet + Vector3.UP * 0.9
	var space: PhysicsDirectSpaceState3D = %Player.get_world_3d().direct_space_state
	for id: String in Keys.GATES:
		var gate: Node3D = %GeneratedMaze.gates[id]
		var local := gate.to_local(feet)
		var distance := local.length_squared()
		if distance >= best or absf(local.y) > 0.76 or absf(local.x) > 1.10:
			continue
		var side := 1.0 if local.z >= 0.0 else -1.0
		var face := gate.to_global(Vector3(0, 1.05, 0.145 * side))
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, face, 1)).is_empty():
			closest = id
			best = distance
	return closest

func _gate_hint(id: String) -> String:
	var gate: Node3D = %GeneratedMaze.gates[id]
	var entry: Dictionary = Keys.GATES[id]
	if gate.is_open:
		return "通道已解锁" if gate.leaf.get_node("GateCollision").disabled else "机关正在开启…"
	var label: String = Keys.ITEMS[entry.item].label
	if _key_items.inventory.quantity(entry.item) > 0:
		return "E · 使用%s解锁" % label
	return "需要%s%s" % ["一枚" if entry.item == Keys.COIN else "一件", label]

func _refresh_hud() -> void:
	if not is_instance_valid(_key_items):
		super()
		return
	if walk_mode:
		%Legend.text = "WASD 移动 / Shift 跑步 / 空格跳跃 / E 解锁 / 鼠标拖动视角 / 滚轮缩放"
	var hint := "沿路拾取幸运道具，靠近机关门按 E。"
	var context := ""
	var id := _nearest_key_gate()
	if completed:
		hint = "已到出口！可重置关卡再次探索。"
		context = "已到出口！"
	elif not id.is_empty():
		hint = Keys.GATES[id].title + " · " + _gate_hint(id)
		context = hint
	elif walk_mode:
		var pickup := _key_items.nearby_pickup_label()
		if not pickup.is_empty():
			hint = "靠近拾取 · " + pickup
			context = hint
	if is_instance_valid(_fullscreen_layout):
		_fullscreen_layout.refresh(context)
	var parts: Array[String] = []
	for gate_id: String in Keys.GATES:
		parts.append(Keys.GATES[gate_id].title + (" 已开" if %GeneratedMaze.gates[gate_id].is_open else " 关闭"))
	%Status.text = " / ".join(parts) + "  ·  " + hint
