extends RefCounted
## Maze02 structural edits. Edges use [row, column], the same as the maze data.

const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const Stone := preload("res://art/maze02/ruins/ruin_stone.gdshader")
const Dust := preload("res://art/maze02/ruins/ruin_dust.gdshader")
const SITES := [
	{"portal": "G2", "label": "西南 G2 · 断冠拱", "preview": [16, 3],
		"closed": [[16, 3], [16, 4]], "opened": [[15, 3], [15, 4]],
		"detour": [[16, 3], [15, 3], [15, 4], [15, 5], [16, 5], [16, 4]],
		"arch_gap": [4, 7], "infill_gap": [3, 8], "pier": 0},
	{"portal": "G3", "label": "西北 G3 · 断柱", "preview": [4, 5],
		"closed": [[5, 5], [5, 6]], "opened": [[5, 6], [6, 6]],
		"detour": [[5, 5], [5, 4], [6, 4], [6, 5], [6, 6], [5, 6]],
		"arch_gap": [0, 6], "infill_gap": [0, 7], "pier": 1},
	{"portal": "G5", "label": "东北 G5 · 残拱", "preview": [3, 16],
		"closed": [[1, 17], [2, 17]], "opened": [[1, 17], [1, 18]],
		"detour": [[1, 17], [1, 18], [2, 18], [2, 17]],
		"arch_gap": [5, 11], "infill_gap": [4, 11], "pier": -1},
]
const WALL_CUTS := [
	{"label": "北侧 · 风蚀墙缺口", "node": "NorthCut", "preview": [1, 8], "yaw": -PI / 2.0,
		"opened": [[1, 8], [1, 9]], "shape": 1},
	{"label": "西侧 · 石廊旁缺口", "node": "WestCut", "preview": [10, 3], "yaw": PI / 2.0,
		"opened": [[10, 2], [10, 3]], "shape": -1},
	{"label": "东庭 · 残墙缺口", "node": "EastCut", "preview": [13, 17], "yaw": 0.0,
		"opened": [[12, 17], [13, 17]], "shape": 1},
]
const SOUTH_ARCH := {"portal": "G4", "label": "南庭 G4 · 缺角拱", "preview": [14, 11], "yaw": 0.0,
	"arch_gap": [2, 3], "infill_gap": [2, 4], "pier": 0}
static func inspection_sites() -> Array:
	return SITES + WALL_CUTS + [SOUTH_ARCH]

static func wall_path(edge: Array) -> NodePath:
	var a: Array = edge[0]
	var b: Array = edge[1]
	if a[0] == b[0]:
		return NodePath("VerticalWalls/WallSegment_V_%d_%d" % [a[0], maxi(a[1], b[1])])
	return NodePath("HorizontalWalls/WallSegment_H_%d_%d" % [maxi(a[0], b[0]), a[1]])

static func apply(generator: Node3D) -> void:
	var ruins := Node3D.new()
	ruins.name = "Maze02Ruins"
	generator.add_child(ruins)
	var cream := _stone(Color("ded0ba"), 0.16)
	var teal := _stone(Color("a0c3c0"), 0.14)
	var core := _stone(Color("c1ae94"), 0.94)
	var cap := _stone(Color("d1bea4"), 0.72)
	var dust := ShaderMaterial.new()
	dust.shader = Dust
	for i in SITES.size():
		var site: Dictionary = SITES[i]
		var region := Node3D.new()
		region.name = site.portal
		ruins.add_child(region)
		var depth := _replace_wall(generator, region, "Breach", site.opened, cream, core, dust)
		var closure := _edge_node(region, "BlockedBranch", site.closed)
		_install_broken_arch(generator, region, site, teal if i == 0 else cream, core)
		_block_branch(closure, i, depth, cream, core, cap, dust)
	for site: Dictionary in WALL_CUTS:
		_replace_wall(generator, ruins, site.node, site.opened, cream, core, dust, site.shape)
	_install_broken_arch(generator, ruins, SOUTH_ARCH, teal, core)

static func _replace_wall(generator: Node3D, parent: Node3D, label: String, opened: Array,
		face: Material, core: Material, dust: Material, shape := 0) -> float:
	var old_wall := generator.get_node(wall_path(opened)) as StaticBody3D
	var wall_mesh := old_wall.get_child(0) as MeshInstance3D
	var dimensions: Vector3 = (wall_mesh.mesh as BoxMesh).size
	var bottom := old_wall.position.y - dimensions.y * 0.5
	var top := old_wall.position.y + dimensions.y * 0.5
	var depth := minf(dimensions.x, dimensions.z)
	var breach := _edge_node(parent, label, opened)
	old_wall.free()
	_breach(breach, bottom, top, depth, face, core, dust, shape)
	return depth

static func _install_broken_arch(generator: Node3D, parent: Node3D, site: Dictionary, face: Material, core: Material) -> void:
	var portal: Node3D = generator.architecture.get_node(site.portal)
	var broken := Node3D.new()
	broken.name = "Broken" + str(site.portal)
	broken.transform = portal.transform
	parent.add_child(broken)
	_break_arch(portal, broken, site, face, core)

static func _stone(color: Color, exposed: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Stone
	material.set_shader_parameter("stone_color", color)
	material.set_shader_parameter("exposed", exposed)
	return material

static func _edge_node(parent: Node3D, label: String, edge: Array) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = (Layout.cell_point(edge[0]) + Layout.cell_point(edge[1])) * 0.5
	node.rotation.y = PI * 0.5 if edge[0][0] == edge[1][0] else 0.0
	parent.add_child(node)
	return node

static func _break_arch(portal: Node3D, parent: Node3D, site: Dictionary, face: Material, core: Material) -> void:
	for i in range(int(site.arch_gap[0]), int(site.arch_gap[1]) + 1):
		portal.get_node("ArchStone%d" % i).free()
	for i in range(int(site.infill_gap[0]), int(site.infill_gap[1]) + 1):
		portal.get_node("WallAboveArch%d" % i).free()
	var side := int(site.pier)
	if side != 0:
		portal.get_node("RightPier" if side > 0 else "LeftPier").free()
		var stump := PackedVector2Array([Vector2(0.90, 0), Vector2(1.20, 0), Vector2(1.20, 1.23),
			Vector2(1.10, 1.11), Vector2(1.03, 1.19), Vector2(0.90, 0.97)])
		if side < 0:
			for i in stump.size():
				stump[i].x *= -1
		_piece(parent, "BrokenPier", stump, 0.4, face, core)
	var first := int(site.arch_gap[0])
	var last := int(site.arch_gap[1])
	if first > 0:
		_cut_voussoir(parent, first * PI / 12.0, 0.118, face, core)
	if last < 11:
		_cut_voussoir(parent, (last + 1) * PI / 12.0, -0.143, face, core)

static func _cut_voussoir(parent: Node3D, seam: float, cut: float, face: Material, core: Material) -> void:
	# Match the original ring radii and start against the neighboring arch stone.
	var spring := Vector2(0, 1.6)
	var profile := PackedVector2Array([
		spring + Vector2.from_angle(seam) * 1.2,
		spring + Vector2.from_angle(seam + cut * 0.39) * 1.2,
		spring + Vector2.from_angle(seam + cut) * 1.11,
		spring + Vector2.from_angle(seam + cut * 0.67) * 1.04,
		spring + Vector2.from_angle(seam + cut * 0.88) * 0.99,
		spring + Vector2.from_angle(seam + cut * 0.49) * 0.90,
		spring + Vector2.from_angle(seam) * 0.90,
	])
	_piece(parent, "FracturedArchStone", profile, 0.386, face, core)

static func _breach(parent: Node3D, bottom: float, top: float, depth: float,
		face: Material, core: Material, dust: Material, shape: int) -> void:
	var span := top - bottom
	for side: float in [-1.0, 1.0]:
		var stagger := shape * side * 0.07
		# Overlap the neighboring wall internally, with the exposed faces inset.
		var profile := PackedVector2Array([Vector2(1.26, bottom), Vector2(0.78, bottom),
			Vector2(0.72, bottom + span * 0.17), Vector2(0.79, bottom + span * 0.24),
			Vector2(0.83 + stagger, bottom + span * 0.37), Vector2(0.90 + stagger, bottom + span * 0.44),
			Vector2(0.79 if side > 0 else 0.91, bottom + span * 0.60),
			Vector2(0.91 + stagger, bottom + span * 0.67), Vector2(1.02 + stagger, bottom + span * 0.79),
			Vector2(1.12, bottom + span * 0.87), Vector2(1.20, top - 0.016), Vector2(1.26, top - 0.016)])
		for i in profile.size():
			profile[i].x *= side
		_piece(parent, "JaggedJamb", profile, depth - 0.014, face, core)
		_dust_patch(parent, Vector2(side * 0.84, side * 0.32), Vector2(1.16, 0.84), side * 0.38, dust)
		# Two displaced paving flakes beside the gap, below walking clearance.
		var chip := _piece(parent, "FloorSpall", PackedVector2Array([
			Vector2(-0.23, 0.007), Vector2(0.17, 0.004), Vector2(0.22, 0.027),
			Vector2(-0.03, 0.042), Vector2(-0.21, 0.026)]), 0.29, core, face, false)
		chip.position = Vector3(side * 0.54, 0, side * 0.53)
		chip.rotation.y = side * 0.48

static func _block_branch(parent: Node3D, index: int, depth: float, face: Material,
		core: Material, cap: Material, dust: Material) -> void:
	# Keep the wall's cross section. The rubble below it sits within the old junction.
	var silhouettes := [
		[1.43, 1.54, 1.43, 1.48, 1.66, 1.61, 1.49, 1.62, 1.52],
		[1.57, 1.65, 1.78, 1.75, 1.55, 1.46, 1.38, 1.53, 1.50],
		[1.45, 1.39, 1.48, 1.63, 1.61, 1.51, 1.38, 1.54, 1.64],
	]
	var profile := PackedVector2Array([Vector2(-1.18, -0.07), Vector2(1.18, -0.07)])
	for i in silhouettes[index].size():
		profile.append(Vector2(1.18 - i * 2.36 / 8.0, silhouettes[index][i]))
	var fractured := face.duplicate() as ShaderMaterial
	fractured.set_shader_parameter("fissure", true)
	_piece(parent, "SplitWallRemnant", profile, depth, fractured, core)
	for side: float in [-1.0, 1.0]:
		_dust_patch(parent, Vector2(side * 0.25, side * 0.47), Vector2(2.26, 1.0), side * 0.12, dust)
		var slab := _piece(parent, "FallenMasonry", PackedVector2Array([
			Vector2(-0.43, -0.12), Vector2(0.34, -0.13), Vector2(0.46, 0.0),
			Vector2(0.29, 0.14), Vector2(-0.35, 0.13), Vector2(-0.45, 0.05)]),
			depth, cap if index != 0 else face, core)
		slab.position = Vector3(side * (0.38 + index * 0.16), 0.18, side * 0.32)
		slab.rotation = Vector3(side * 0.54, side * 0.28, -side * 0.24)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6201 + index * 97
	for i in 24:
		var width := rng.randf_range(0.035, 0.19)
		var height := rng.randf_range(0.018, 0.135)
		var chunk := _piece(parent, "StoneChip", PackedVector2Array([
			Vector2(-width, 0.0), Vector2(width * 0.77, 0.0), Vector2(width, height * 0.47),
			Vector2(width * 0.29, height), Vector2(-width * 0.74, height * 0.64)]),
			width * rng.randf_range(0.7, 1.55), face if i % 3 else cap, core, false)
		chunk.position = Vector3(rng.randf_range(-1.05, 1.05), 0.003,
			rng.randf_range(0.17, 0.94) * (1.0 if i % 2 == 0 else -1.0))
		chunk.rotation.y = rng.randf_range(0.0, TAU)

static func _dust_patch(parent: Node3D, center: Vector2, size: Vector2, angle: float, material: Material) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	var dust := MeshInstance3D.new()
	dust.name = "SettledSand"
	dust.mesh = plane
	dust.material_override = material
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.position = Vector3(center.x, 0.012, center.y)
	dust.rotation.y = angle
	parent.add_child(dust, true)

static func _piece(parent: Node3D, label: String, profile: PackedVector2Array, depth: float,
		face: Material, core: Material, collide := true) -> Node3D:
	var node: Node3D = StaticBody3D.new() if collide else Node3D.new()
	node.name = label
	parent.add_child(node, true)
	var mesh := ArrayMesh.new()
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	flat.set_material(face)
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	edge.set_material(core)
	var indices := Geometry2D.triangulate_polygon(profile)
	var half := depth * 0.5
	for i in range(0, indices.size(), 3):
		for z: float in [-half, half]:
			_triangle(flat, _at(profile[indices[i]], z), _at(profile[indices[i + 1]], z),
				_at(profile[indices[i + 2]], z), Vector3(0, 0, signf(z)))
	var orientation := -1.0 if Geometry2D.is_polygon_clockwise(profile) else 1.0
	for i in profile.size():
		var a := profile[i]
		var b := profile[(i + 1) % profile.size()]
		var delta := b - a
		var normal := (Vector3(delta.y, -delta.x, 0.0) * orientation).normalized()
		_triangle(edge, _at(a, -half), _at(b, -half), _at(b, half), normal)
		_triangle(edge, _at(a, -half), _at(b, half), _at(a, half), normal)
	flat.commit(mesh)
	edge.commit(mesh)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	node.add_child(visual)
	if collide:
		var shape := mesh.create_trimesh_shape()
		shape.backface_collision = true
		var collision := CollisionShape3D.new()
		collision.shape = shape
		node.add_child(collision)
		(node as StaticBody3D).collision_layer = 5
	return node

static func _at(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	surface.set_normal(normal)
	surface.add_vertex(a)
	if (b - a).cross(c - a).dot(normal) > 0.0:
		surface.add_vertex(c)
		surface.add_vertex(b)
	else:
		surface.add_vertex(b)
		surface.add_vertex(c)
