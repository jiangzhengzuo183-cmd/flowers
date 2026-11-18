extends "res://modules/maze_keys/maze01_key_items.gd"

const Marks := preload("res://modules/maze02_items/placements.gd")

func _init() -> void:
	key_positions = Marks.KEYS.duplicate()

func _spawn_pickup() -> void:
	_pickup = _spawn_rabbit(Marks.RABBIT)
	_pickup.ground_display = true

func _spawn_keys() -> void:
	super()
	for pickup in key_pickups.values():
		pickup.ground_display = true

func nearby_pickup_label() -> String:
	var label := super()
	if label.is_empty() and is_instance_valid(_pickup) and not _pickup.claimed and _pickup._near > 0.38:
		return "幸运兔脚"
	return label

func vision_route() -> PackedVector3Array:
	if not _routes.ready:
		return PackedVector3Array()
	var origin := _actor.global_position
	var route := _routes.path_to_nearest(origin, _destinations)
	if route.size() > 1:
		return route
	var targets := PackedVector3Array()
	for id: String in _required_gates:
		var gate: Node3D = _gates[id]
		if gate.is_open:
			continue
		var item: StringName = Keys.GATES[id].item
		if inventory.quantity(item) > 0:
			targets.append(gate.to_global(Vector3(0.0, 0.0, -1.1)))
			targets.append(gate.to_global(Vector3(0.0, 0.0, 1.1)))
		else:
			for pickup_id: String in key_pickups:
				var pickup = key_pickups[pickup_id]
				if Keys.GATES[pickup_id].item == item and is_instance_valid(pickup) and not pickup.claimed:
					targets.append(pickup.global_position)
	return _routes.path_to_nearest(origin, targets)

## Read-only access to the existing collision-derived graph for Maze02 NPC guidance.
func guidance_routes() -> RefCounted:
	return _routes
