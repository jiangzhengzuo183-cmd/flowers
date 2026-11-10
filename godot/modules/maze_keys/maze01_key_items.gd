extends "res://modules/maze_items/maze_item_controller.gd"
## Maze 01's passive key slots share the existing inventory and pickup sound.

const Keys := preload("res://modules/maze_keys/maze01_gate_keys.gd")
const KeyPickup := preload("res://modules/maze_keys/gate_key_pickup.gd")
const Glow := preload("res://modules/maze_items/item_glow.gd")
var key_pickups: Dictionary = {}
var key_positions: Dictionary = {}
var extra_rabbit_positions: Array[Vector3] = []
var _extra_rabbits: Array = []
var _required_gates: Array = []

func setup_keys(required_gates: Array) -> void:
	_required_gates = required_gates
	for id: StringName in Keys.ITEMS:
		var item: Dictionary = Keys.ITEMS[id]
		inventory.register_item(id, item.label, item.icon, false)
	_spawn_keys()

func reset_items() -> void:
	for rabbit in _extra_rabbits:
		if is_instance_valid(rabbit):
			rabbit.queue_free()
	_extra_rabbits.clear()
	for pickup in key_pickups.values():
		if is_instance_valid(pickup):
			pickup.queue_free()
	key_pickups.clear()
	for id: String in Keys.GATES:
		var transfer: Node = _gates[id].get_node_or_null("KeyTransfer")
		if is_instance_valid(transfer):
			transfer.queue_free()
	super()
	_spawn_keys()

func _spawn_pickup() -> void:
	super()
	for point in extra_rabbit_positions:
		_extra_rabbits.append(_spawn_rabbit(point))

func _spawn_keys() -> void:
	for id: String in Keys.GATES:
		var entry: Dictionary = Keys.GATES[id]
		var pickup := KeyPickup.new()
		pickup.name = String(entry.item) + "_" + id
		pickup.definition = Keys.ITEMS[entry.item]
		pickup.actor = _actor
		pickup.position = key_positions.get(id, entry.pickup)
		pickup.collected.connect(_collect_key.bind(entry.item))
		key_pickups[id] = pickup
		_world.add_child(pickup, true)

func _collect_key(id: StringName) -> void:
	inventory.grant(id)
	_sound.call(Chime)

func nearby_pickup_label() -> String:
	for pickup in key_pickups.values():
		if is_instance_valid(pickup) and not pickup.claimed and pickup._near > 0.38:
			return pickup.definition.label
	return ""

func _activate() -> void:
	# Keep the rabbit's short-path guide useful after the old switches are removed.
	if _routes.ready and _actor.controls_enabled and not is_instance_valid(_guide):
		_switch_stops.clear()
		for id: String in _required_gates:
			var gate: Node3D = _gates[id]
			if gate.is_open:
				continue
			var item: StringName = Keys.GATES[id].item
			var points := PackedVector3Array()
			if inventory.quantity(item) > 0:
				for side: float in [-1.0, 1.0]:
					points.append(gate.to_global(Vector3(0, 0, side * 1.10)))
			else:
				for key_gate: String in key_pickups:
					var pickup = key_pickups[key_gate]
					if Keys.GATES[key_gate].item == item and is_instance_valid(pickup) and not pickup.claimed:
						points.append(pickup.global_position)
			var path := _routes.path_to_nearest(_actor.global_position, points)
			if path.size() > 1:
				_switch_stops[id] = path[-1]
	super()

func play_key_transfer(gate: Node3D, id: StringName) -> void:
	inventory.flash_item(id)
	var transfer := Node3D.new()
	transfer.name = "KeyTransfer"
	gate.add_child(transfer)
	var start := _actor.global_position + Vector3.UP * 1.05
	var side := signf(gate.to_local(_actor.global_position).z)
	var target := gate.to_global(Vector3(0, 1.32, 0.13 * side))
	var flight := transfer.create_tween().set_parallel()
	for i in 6:
		var tint := Color("fff0bc") if i % 2 == 0 else Color("baffff")
		var mote := Glow.sprite(transfer, 0.09 + 0.014 * (i % 3), tint)
		var offset := gate.global_basis.x * (i - 2.5) * 0.10
		mote.global_position = start + offset * 0.28
		flight.tween_method(_move_mote.bind(mote, mote.global_position, target, offset), 0.0, 1.0, 0.29).set_delay(i * 0.027)
	flight.finished.connect(transfer.queue_free)

func _move_mote(t: float, mote: MeshInstance3D, start: Vector3, target: Vector3, offset: Vector3) -> void:
	mote.global_position = start.lerp(target, t) + sin(PI * t) * (Vector3.UP * 0.20 + offset)
	(mote.material_override as StandardMaterial3D).albedo_color.a = smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.72, 1.0, t))
