extends Node3D
## Seeded, collision-free stone chips. Sample the real walking surface once.

const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const Room := preload("res://scripts/levels/round_hall.gd")
const Stone := preload("res://art/maze02/ruins/ruin_stone.gdshader")
const GRID_SIZE := 19
const PILE_LIMIT := 42
const SIDES := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const FOOTPRINT := [
	Vector2(-0.54, -0.21), Vector2(-0.25, -0.49), Vector2(0.33, -0.44),
	Vector2(0.55, -0.03), Vector2(0.26, 0.46), Vector2(-0.38, 0.33),
]

var protected_points := PackedVector3Array()
var piece_count := 0
var occupied_cells := 0

func _physics_process(_delta: float) -> void:
	set_physics_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 972437
	var scene_space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)
	var groups: Array[Array] = [[], [], []]
	var pool := Rect2(0, 4.8, 9.6, 9.6)
	var water := float(Layout.config().northwest.waterSurface)
	var chapel: Dictionary = Layout.config().building
	var cells := range(GRID_SIZE * GRID_SIZE)
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	for cell: int in cells:
		if occupied_cells == PILE_LIMIT:
			break
		@warning_ignore("integer_division")
		var center := Layout.cell_point([cell / GRID_SIZE, cell % GRID_SIZE])
		var side := _wall_side(scene_space, ray, center, rng.randi_range(0, 3))
		if side == Vector2.ZERO:
			continue
		var tangent := side.orthogonal()
		var before := piece_count
		for i in rng.randi_range(3, 5):
			var offset := side * rng.randf_range(0.71, 0.80) + tangent * rng.randf_range(-0.31, 0.31)
			var point := Vector2(center.x, center.z) + offset
			if Room.contains(point, chapel) or _protected(point):
				continue
			ray.from = Vector3(point.x, 6.7, point.y)
			ray.to = Vector3(point.x, -1.1, point.y)
			var hit := scene_space.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y < 0.79:
				continue
			var ground: Vector3 = hit.position
			if absf(ground.y - Layout.height_at(point)) > 0.24 or (pool.has_point(point) and ground.y < water + 0.05):
				continue
			if not _hits_wall(scene_space, ray, ground + Vector3.UP * 0.19, side, 0.48):
				continue
			var width := rng.randf_range(0.071, 0.14)
			var height := rng.randf_range(0.026, 0.058)
			if i == 0:
				width = rng.randf_range(0.24, 0.36)
				height = rng.randf_range(0.067, 0.113)
			elif i == 1:
				width = rng.randf_range(0.15, 0.23)
				height = rng.randf_range(0.046, 0.085)
			var scale := Vector3(width, height, width * rng.randf_range(0.65, 1.22))
			var slope := Basis(Quaternion(Vector3.UP, hit.normal))
			var rotated := slope * Basis(Vector3.UP, rng.randf_range(0.0, TAU))
			groups[rng.randi_range(0, 2)].append(Transform3D(rotated.scaled_local(scale), ground - Vector3.UP * 0.008))
			piece_count += 1
		occupied_cells += int(piece_count > before)
	for i in groups.size():
		_draw_batch(groups[i], i)

func _wall_side(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D, center: Vector3, start: int) -> Vector2:
	center.y = Layout.height_at(Vector2(center.x, center.z)) + 0.19
	for i in SIDES.size():
		var side: Vector2 = SIDES[(start + i) % SIDES.size()]
		if _hits_wall(space, ray, center, side, 1.24):
			return side
	return Vector2.ZERO

func _hits_wall(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D,
		from: Vector3, side: Vector2, distance: float) -> bool:
	ray.from = from
	ray.to = from + Vector3(side.x, 0.0, side.y) * distance
	var hit := space.intersect_ray(ray)
	return not hit.is_empty() and hit.collider.get_parent().name in [&"HorizontalWalls", &"VerticalWalls"]

func _protected(point: Vector2) -> bool:
	for marker: Vector3 in protected_points:
		if point.distance_squared_to(Vector2(marker.x, marker.z)) < 0.83:
			return true
	return false

func _draw_batch(transforms: Array, index: int) -> void:
	var paint := ShaderMaterial.new()
	paint.shader = Stone
	paint.set_shader_parameter("stone_color", [Color("d9c7ae"), Color("c6ad93"), Color("e1d1bc")][index])
	paint.set_shader_parameter("exposed", 0.46)
	paint.set_shader_parameter("foot_shade", 0.21)
	var field := MultiMesh.new()
	field.transform_format = MultiMesh.TRANSFORM_3D
	field.mesh = _rock(index)
	field.instance_count = transforms.size()
	for i in transforms.size():
		field.set_instance_transform(i, transforms[i])
	var batch := MultiMeshInstance3D.new()
	batch.name = "LimestoneChips%d" % index
	batch.multimesh = field
	batch.material_override = paint
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)

func _rock(index: int) -> ArrayMesh:
	var lower := PackedVector3Array()
	var upper := PackedVector3Array()
	for i in FOOTPRINT.size():
		var p: Vector2 = FOOTPRINT[i]
		var taper := 0.55 + float((i + index) % 3) * 0.13
		lower.append(Vector3(p.x, 0.0, p.y))
		upper.append(Vector3(p.x * taper + 0.08, 0.63 + float((i * 2 + index) % 5) * 0.09, p.y * taper))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in lower.size():
		var j := (i + 1) % lower.size()
		var outward := (lower[i] + lower[j]).normalized()
		_face(surface, lower[i], upper[i], upper[j], outward)
		_face(surface, lower[i], upper[j], lower[j], outward)
	for i in range(1, upper.size() - 1):
		_face(surface, upper[0], upper[i], upper[i + 1], Vector3.UP)
	return surface.commit()

func _face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var reverse := normal.dot(outward) > 0.0
	surface.set_normal(normal if reverse else -normal)
	surface.add_vertex(a)
	surface.add_vertex(c if reverse else b)
	surface.add_vertex(b if reverse else c)
