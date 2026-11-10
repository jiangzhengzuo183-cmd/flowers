extends MultiMeshInstance3D
## Sample bounded wind lanes across the map once, after world collisions are ready.
## The shader then animates the whole field with one MultiMesh and no physics bodies.

const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const DRIFT_EXTENT := Vector3(0.72, 0.17, 0.17)
const CLEARANCE := 0.11
const BASE_FLECKS := 3
const EXTRA_GUST_FLECKS := 2
const ARCHITECTURE_MASK := 1

@export var sand_material: ShaderMaterial
var occupied_cells := 0
var gust_count := 0
var height_range := Vector2(INF, -INF)

func _physics_process(_delta: float) -> void:
	set_physics_process(false)
	var space := get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 58127
	var positions: Array[Vector3] = []
	var parameters: Array[Color] = []
	var ceiling := float(Layout.config().building.eave) - 0.25
	var building: Dictionary = Layout.config().building
	var gust_cells := [Vector2i(18, 0), Vector2i(6, 9), Vector2i(7, 16), Vector2i(11, 1), Vector2i(5, 3)]
	for row in 19:
		for column in 19:
			# Leave the chapel walls and its three tight porches to the interior staging.
			if row >= building.rows[0] - 1 and row <= building.rows[1] + 1 and column >= building.cols[0] and column <= building.cols[1]:
				continue
			var cell := Vector2i(row, column)
			var center := Layout.cell_point([row, column])
			var gust := 0.0
			for i in gust_cells.size():
				if cell.distance_to(gust_cells[i]) <= 1.45:
					gust = 0.18 + float(i) * 0.18
					break
			var previous := positions.size()
			var flecks := BASE_FLECKS + (EXTRA_GUST_FLECKS if gust > 0.0 else 0)
			for i in flecks:
				var point := center + Vector3(rng.randf_range(-0.19, 0.19), 0.0, rng.randf_range(-0.55, 0.55))
				var floor_hit := _ray(space, Vector3(point.x, ceiling, point.z), Vector3(point.x, -1.1, point.z))
				if floor_hit.is_empty():
					continue
				var floor_height: float = floor_hit.position.y
				point.y = minf(ceiling - DRIFT_EXTENT.y - CLEARANCE, floor_height + rng.randf_range(0.69, 2.85))
				if point.y < floor_height + 0.38 or not _clear_lane(space, point):
					continue
				positions.append(point)
				parameters.append(Color(rng.randf(), rng.randf(), gust if i >= BASE_FLECKS else 0.0, rng.randf()))
				height_range.x = minf(height_range.x, point.y - DRIFT_EXTENT.y)
				height_range.y = maxf(height_range.y, point.y + DRIFT_EXTENT.y)
				if i >= BASE_FLECKS:
					gust_count += 1
			if positions.size() > previous:
				occupied_cells += 1

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var field := MultiMesh.new()
	field.transform_format = MultiMesh.TRANSFORM_3D
	field.use_custom_data = true
	field.mesh = quad
	field.instance_count = positions.size()
	for i in positions.size():
		var size := rng.randf_range(0.030, 0.072)
		field.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), positions[i]))
		field.set_instance_custom_data(i, parameters[i])
	field.custom_aabb = AABB(Vector3(-1, -1.1, -1), Vector3(47.6, ceiling + 1.1, 47.6))
	multimesh = field
	var wind := sand_material.duplicate() as ShaderMaterial
	wind.set_shader_parameter("drift_extent", DRIFT_EXTENT)
	material_override = wind

func _ray(space: PhysicsDirectSpaceState3D, start: Vector3, end: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, end, ARCHITECTURE_MASK)
	query.hit_from_inside = true
	return space.intersect_ray(query)

func _clear_lane(space: PhysicsDirectSpaceState3D, point: Vector3) -> bool:
	# Pad the shader displacement and the billboard on every side. The lanes stay
	# inside their cells, so opening a gate cannot move a leaf into the particle field.
	for y: float in [-DRIFT_EXTENT.y - CLEARANCE, 0.0, DRIFT_EXTENT.y + CLEARANCE]:
		for z: float in [-DRIFT_EXTENT.z - CLEARANCE, 0.0, DRIFT_EXTENT.z + CLEARANCE]:
			var offset := Vector3(0, y, z)
			var start := point + offset - Vector3.RIGHT * (DRIFT_EXTENT.x + CLEARANCE)
			var end := point + offset + Vector3.RIGHT * (DRIFT_EXTENT.x + CLEARANCE)
			if not _ray(space, start, end).is_empty() or not _ray(space, end, start).is_empty():
				return false
	return true
