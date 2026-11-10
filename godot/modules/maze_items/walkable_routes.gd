extends RefCounted
## A distance-weighted graph of the level's actual walking surfaces.
## Each XZ sample can have several heights, e.g. both sides of the H2 crossing.

const SPACING := 0.60
const FLOOR_PAD := 0.16
const NEIGHBORS := [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]

var ready := false
var _graph := AStar3D.new()
var _columns: Dictionary = {}
var _points := PackedVector3Array()
var _floor_ids: Dictionary = {}
var _gate_ids: Array[RID] = []
var _gate_shapes: Array[CollisionShape3D] = []
var _gate_points: Array[PackedInt32Array] = []
var _gate_mask := -1
var _actor: CharacterBody3D
var _ray := PhysicsRayQueryParameters3D.new()
var _sweep := PhysicsShapeQueryParameters3D.new()
var _capsule: CapsuleShape3D
var _size: Vector2i
var _sample_index := 0
var _link_index := 0

func configure(actor: CharacterBody3D, architecture: Node3D, gates: Dictionary) -> void:
	_actor = actor
	_size = Vector2i((actor.map_size / SPACING).round())
	_capsule = actor.find_children("*", "CollisionShape3D", false, false)[0].shape as CapsuleShape3D
	_ray.collision_mask = actor.collision_mask
	_sweep.collision_mask = actor.collision_mask
	_sweep.shape = _capsule
	_floor_ids[architecture.get_node("RaisedSurfaceCollision").get_rid()] = true
	for mesh: MeshInstance3D in architecture.find_children("*", "MeshInstance3D", true, false):
		if mesh.get_meta("greybox_part", "") == "GroundSlab":
			_floor_ids[mesh.get_parent().get_rid()] = true
	for gate: Node3D in gates.values():
		_gate_ids.append(gate.leaf.get_rid())
		_gate_shapes.append(gate.leaf.get_node("GateCollision"))
		_gate_points.append(PackedInt32Array())
	_ray.exclude = _gate_ids
	_sweep.exclude = _gate_ids

func build_batch() -> void:
	if ready:
		return
	var total := _size.x * _size.y
	if _sample_index < total:
		var stop := mini(_sample_index + 256, total)
		for i in range(_sample_index, stop):
			var cell := Vector2i(i % _size.x, floori(float(i) / _size.x))
			_sample_column(cell)
		_sample_index = stop
		return
	var stop := mini(_link_index + 240, _points.size())
	for id in range(_link_index, stop):
		var point := _points[id]
		var cell := _column(point)
		for direction: Vector2i in NEIGHBORS:
			for neighbor: int in _columns.get(cell + direction, []):
				if _can_walk(point, _points[neighbor]):
					_graph.connect_points(id, neighbor)
	_link_index = stop
	if stop == _points.size():
		ready = true
		_refresh_gates()

func _sample_column(cell: Vector2i) -> void:
	var xz := (Vector2(cell) + Vector2.ONE * 0.5) * SPACING
	var space := _actor.get_world_3d().direct_space_state
	var top := 4.1
	while top > -0.96:
		var hit := _floor_ray(Vector3(xz.x, top, xz.y), -1.0)
		if hit.is_empty():
			break
		var point: Vector3 = hit.position
		top = point.y - 0.04
		if not _is_walkable_hit(hit):
			continue
		_sweep.transform = _shape_transform(point)
		_sweep.motion = Vector3.ZERO
		if not space.intersect_shape(_sweep, 1).is_empty():
			continue
		var id := _points.size()
		_points.append(point)
		_graph.add_point(id, point)
		if not _columns.has(cell):
			_columns[cell] = []
		_columns[cell].append(id)
		for index in _gate_shapes.size():
			var gate := _gate_shapes[index]
			var size := (gate.shape as BoxShape3D).size * 0.5
			var local := gate.to_local(point)
			var within_frame := absf(local.x) < size.x + _capsule.radius and absf(local.z) < size.z + _capsule.radius
			if within_frame and local.y < size.y and local.y + _capsule.height > -size.y:
				_gate_points[index].append(id)

func _column(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / SPACING), floori(point.z / SPACING))

func _shape_transform(point: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, point + Vector3.UP * (_capsule.height * 0.5 + FLOOR_PAD))

func _floor_ray(point: Vector3, bottom: float) -> Dictionary:
	_ray.from = point
	_ray.to = Vector3(point.x, bottom, point.z)
	return _actor.get_world_3d().direct_space_state.intersect_ray(_ray)

func _is_walkable_hit(hit: Dictionary) -> bool:
	return not hit.is_empty() and _floor_ids.has(hit.rid) and hit.normal.y >= cos(_actor.floor_max_angle) - 0.02

func _can_walk(from: Vector3, to: Vector3) -> bool:
	var motion := to - from
	var horizontal := Vector2(motion.x, motion.z).length()
	if absf(motion.y) > 0.09 + horizontal * tan(_actor.floor_max_angle):
		return false
	if motion.length_squared() < 0.00001:
		return true
	var middle := (from + to) * 0.5
	var support := _floor_ray(middle + Vector3.UP * 0.19, middle.y - 0.23)
	if not _is_walkable_hit(support):
		return false
	_sweep.transform = _shape_transform(from)
	_sweep.motion = motion
	var result := _actor.get_world_3d().direct_space_state.cast_motion(_sweep)
	return result.size() == 2 and result[0] >= 0.999

func _refresh_gates() -> void:
	var mask := 0
	for i in _gate_shapes.size():
		if not _gate_shapes[i].disabled:
			mask |= 1 << i
	if mask == _gate_mask:
		return
	_gate_mask = mask
	for i in _gate_shapes.size():
		for id in _gate_points[i]:
			_graph.set_point_disabled(id, (mask & (1 << i)) != 0)

func _anchor(point: Vector3) -> int:
	var id := _graph.get_available_point_id()
	_graph.add_point(id, point)
	var origin := _column(point)
	for x in range(-2, 3):
		for z in range(-2, 3):
			for other: int in _columns.get(origin + Vector2i(x,z), []):
				if _graph.is_point_disabled(other):
					continue
				var candidate := _points[other]
				if point.distance_squared_to(candidate) <= 1.18 and _can_walk(point, candidate):
					_graph.connect_points(id, other)
	return id

func path_to_nearest(origin: Vector3, destinations: PackedVector3Array) -> PackedVector3Array:
	if not ready or destinations.is_empty():
		return PackedVector3Array()
	_refresh_gates()
	var start := _floor_ray(origin + Vector3.UP * 0.16, origin.y - 0.75)
	if not _is_walkable_hit(start):
		return PackedVector3Array()
	var best := PackedVector3Array()
	var best_length := INF
	# Anchors and their connectors must obey the live gate collision, too.
	_sweep.exclude = []
	var origin_id := _anchor(start.position)
	for destination in destinations:
		var landing := _floor_ray(destination + Vector3.UP * 0.18, destination.y - 0.90)
		if not _is_walkable_hit(landing):
			continue
		var target_id := _anchor(landing.position)
		if start.position.distance_squared_to(landing.position) <= 1.18 and _can_walk(start.position, landing.position):
			_graph.connect_points(origin_id, target_id)
		var path := _graph.get_point_path(origin_id, target_id)
		var length := 0.0
		for i in range(1, path.size()):
			length += path[i-1].distance_to(path[i])
		if not path.is_empty() and length < best_length:
			best = path
			best_length = length
		_graph.remove_point(target_id)
	_graph.remove_point(origin_id)
	_sweep.exclude = _gate_ids
	return best

func can_step(from: Vector3, to: Vector3) -> bool:
	_sweep.exclude = []
	_sweep.transform = _shape_transform(from)
	_sweep.motion = Vector3.ZERO
	var overlaps := _actor.get_world_3d().direct_space_state.intersect_shape(_sweep, 4)
	var blocked := overlaps.any(func(hit: Dictionary): return _gate_ids.has(hit.rid))
	var clear := not blocked and _can_walk(from, to)
	_sweep.exclude = _gate_ids
	return clear
