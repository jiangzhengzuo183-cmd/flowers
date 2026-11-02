extends Node3D
## Coordinates: JSON [row, col] -> world x=col, z=row, y=height.

const WALL_HEIGHT := 3.2
const WALL_THICKNESS := 0.3
var route_nodes: Dictionary = {}
var wall_count := 0
var marker_count := 0
var marker_pins: Array[MeshInstance3D] = []
var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func build(maze: Dictionary) -> void:
	var cell_size := float(maze.grid.cellSizeWorld)
	var width := int(maze.grid.cols) * cell_size
	var depth := int(maze.grid.rows) * cell_size
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(width + 1.4, 0.25, depth + 1.4)
	floor_material = _material(Color("eeede8"))
	_add_mesh(floor_mesh, floor_material, Vector3(width / 2, -0.125, depth / 2), self)
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorCollision"
	add_child(floor_body)
	var floor_shape := BoxShape3D.new()
	floor_shape.size = floor_mesh.size
	_add_collision(floor_shape, Vector3(width / 2, -0.125, depth / 2), floor_body)
	var walls_body := StaticBody3D.new()
	walls_body.name = "WallCollisions"
	add_child(walls_body)
	wall_material = _material(Color("9b9d9b"))
	_build_walls(maze.grid.verticalWalls, true, cell_size, wall_material, walls_body)
	_build_walls(maze.grid.horizontalWalls, false, cell_size, wall_material, walls_body)
	_marker(maze.openings.entry.cell, Color("e79346"), cell_size, "Entry")
	_marker(maze.openings.exit.cell, Color("dc82a3"), cell_size, "Exit")
	for point: Dictionary in maze.checkpoints:
		_marker(point.cell, Color("459c98"), cell_size, str(point.id))
	for id: String in ["A", "B"]:
		var group := Node3D.new()
		group.name = "Route" + id
		add_child(group)
		route_nodes[id] = group
		var path: Array = maze.routes[id].cellPath
		var route_material := _material(Color(maze.routes[id].color), true)
		for i in range(1, path.size()):
			var a: Array = path[i - 1]
			var b: Array = path[i]
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.15 if a[1] == b[1] else cell_size + 0.15, 0.07, 0.15 if a[0] == b[0] else cell_size + 0.15)
			_add_mesh(mesh, route_material, Vector3((a[1] + b[1] + 1) * cell_size / 2, 0.24, (a[0] + b[0] + 1) * cell_size / 2), group)
	set_route("none")

func _build_walls(matrix: Array, vertical: bool, size: float, material: StandardMaterial3D, body: StaticBody3D) -> void:
	var transforms: Array[Transform3D] = []
	for r in range(matrix.size()):
		for c in range(matrix[r].size()):
			if matrix[r][c]:
				var center := Vector3((c + (0.0 if vertical else 0.5)) * size, WALL_HEIGHT / 2, (r + (0.5 if vertical else 0.0)) * size)
				transforms.append(Transform3D(Basis.IDENTITY, center))
	if transforms.is_empty():
		return
	var dimensions := Vector3(WALL_THICKNESS if vertical else size + WALL_THICKNESS, WALL_HEIGHT, size + WALL_THICKNESS if vertical else WALL_THICKNESS)
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "VerticalWalls" if vertical else "HorizontalWalls"
	instance.multimesh = multi
	add_child(instance)
	var shape := BoxShape3D.new()
	shape.size = dimensions
	for transform: Transform3D in transforms:
		_add_collision(shape, transform.origin, body)
	wall_count += transforms.size()

func _add_collision(shape: Shape3D, center: Vector3, body: StaticBody3D) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	body.add_child(collision)

func _add_mesh(mesh: Mesh, material: Material, center: Vector3, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	parent.add_child(instance)
	return instance

func _marker(cell: Array, color: Color, size: float, id: String) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = size * 0.32
	mesh.bottom_radius = size * 0.32
	mesh.height = 0.16
	var center := Vector3((cell[1] + 0.5) * size, 0.12, (cell[0] + 0.5) * size)
	var instance := _add_mesh(mesh, _material(color, true), center, self)
	instance.name = id
	# Small pins keep the markers identifiable above the greybox walls.
	var pin_mesh := SphereMesh.new()
	pin_mesh.radius = 0.28
	pin_mesh.height = 0.56
	marker_pins.append(_add_mesh(pin_mesh, _material(color, true), center + Vector3(0, WALL_HEIGHT + 0.3, 0), self))
	marker_count += 1

func set_route(id: String) -> void:
	for key: String in route_nodes:
		route_nodes[key].visible = key == id

func set_soft_palette(enabled: bool) -> void:
	wall_material.albedo_color = Color("f5e7cd") if enabled else Color("9b9d9b")
	floor_material.albedo_color = Color("d6c2b7") if enabled else Color("eeede8")

func set_walk_cutaway(enabled: bool) -> void:
	# Only the displayed wall height changes; the original collision and layout stay intact.
	for id: String in ["VerticalWalls", "HorizontalWalls"]:
		get_node(id).scale.y = 0.38 if enabled else 1.0
	for pin: MeshInstance3D in marker_pins:
		pin.visible = not enabled
