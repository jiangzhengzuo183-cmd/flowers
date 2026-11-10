extends RefCounted

const Layout := preload("res://scripts/levels/maze_01_layout.gd")

static func wall_ends(generator: Node3D, cell_size: float) -> Dictionary:
	var junctions: Dictionary = {}
	for vertical: bool in [false, true]:
		var group := generator.get_node("VerticalWalls" if vertical else "HorizontalWalls")
		var axis := Vector2i(0, 1) if vertical else Vector2i(1, 0)
		for wall: Node3D in group.get_children():
			var mesh := wall.get_child(0) as MeshInstance3D
			var size := (mesh.mesh as BoxMesh).size
			var key := str(wall.name).split("_")
			var start := Vector2i(int(key[3]), int(key[2]))
			var center := wall.position.z if vertical else wall.position.x
			var half_length := (size.z if vertical else size.x) * 0.5
			var half_width := (size.x if vertical else size.z) * 0.5
			for end in 2:
				var joint := start + axis * end
				var plane := Vector2(axis).dot(Vector2(joint)) * cell_size
				# A rail cut may leave a stub at just one of the grid endpoints.
				if absf(plane - center) <= half_length + 0.001:
					_add_wall_end(junctions, joint, {
						"mesh": mesh, "end": end, "axis": axis, "plane": plane - center,
						"half_width": half_width, "top": wall.position.y + size.y * 0.5,
					})

	for arch: Dictionary in Layout.config().arches:
		if str(arch.id) in ["G6", "G7", "G8"]:
			continue
		var portal: Node3D = generator.architecture.get_node(arch.id)
		var axis := Vector2i(0, 1) if arch.edge[0][0] == arch.edge[1][0] else Vector2i(1, 0)
		var center := Vector2(portal.position.x, portal.position.z) / cell_size
		for direction: float in [-0.5, 0.5]:
			var point := center + Vector2(axis) * direction
			_add_wall_end(junctions, Vector2i(point.round()), {
				"mesh": null, "axis": axis, "half_width": 0.20, "top": 3.4,
			})

	var corridor: Dictionary = Layout.config().sunken_corridor
	var east_col := roundi(float(corridor.rect[1]) / cell_size)
	var north_row := roundi(float(corridor.rect[2]) / cell_size)
	var south_row := roundi(float(corridor.rect[3]) / cell_size)
	# The continuous niche wall replaces the grid walls along the east side
	# of H6. Its through wall owns the intersections between the two landings.
	for row in range(north_row + 1, south_row):
		_add_wall_end(junctions, Vector2i(east_col, row), {
			"mesh": null, "axis": Vector2i(0, 1), "half_width": 0.15, "top": corridor.wall_top,
		})

	var ends: Dictionary = {}
	for neighbors: Array in junctions.values():
		if neighbors.size() < 2:
			continue
		# The higher run owns a crossing. A straight run owns its half on
		# either side of the grid line, with no overlapping cap or side faces.
		var owner: Dictionary = neighbors[0]
		for candidate: Dictionary in neighbors:
			if candidate.mesh == null or (owner.mesh != null and candidate.top > owner.top + 0.001):
				owner = candidate
		for entry: Dictionary in neighbors:
			if entry.mesh == null:
				continue
			var straight := false
			for neighbor: Dictionary in neighbors:
				if neighbor.mesh != entry.mesh and neighbor.axis == entry.axis:
					straight = true
					break
			if entry.axis == owner.axis and not straight:
				continue
			if not ends.has(entry.mesh):
				ends[entry.mesh] = [null, null]
			var inward := 1.0 if entry.end == 0 else -1.0
			ends[entry.mesh][entry.end] = entry.plane + inward * (owner.half_width if entry.axis != owner.axis else 0.0)

	# At the landings the transverse walls run through instead. Stop the
	# visible niche panels at their inner faces, leaving the original physics.
	var corridor_node: Node3D = generator.architecture.get_node("SunkenCorridor")
	var horizontal: Node3D = generator.get_node("HorizontalWalls")
	for side in 2:
		var row := north_row if side == 0 else south_row
		var panel_id := "WallSegment_H6_Panel0" if side == 0 else "WallSegment_H6_PanelEnd"
		var cross_wall := horizontal.get_node_or_null("WallSegment_H_%d_%d" % [row, east_col - 1]) as Node3D
		if cross_wall == null:
			continue
		var cross_mesh := cross_wall.get_child(0) as MeshInstance3D
		var panel := corridor_node.get_node(panel_id).get_child(0) as MeshInstance3D
		var inward := 1.0 if side == 0 else -1.0
		var face := cross_wall.position.z + inward * (cross_mesh.mesh as BoxMesh).size.z * 0.5
		ends[panel] = [null, null]
		ends[panel][side] = face - panel.get_parent_node_3d().position.z
	return ends

static func _add_wall_end(junctions: Dictionary, joint: Vector2i, endpoint: Dictionary) -> void:
	if not junctions.has(joint):
		junctions[joint] = []
	junctions[joint].append(endpoint)

static func soften_edges(instance: MeshInstance3D, cache: Dictionary, joined: Array = []) -> void:
	var source := instance.mesh as BoxMesh
	var size := source.size
	var half := size * 0.5
	var low := Vector2(-half.x, -half.z)
	var high := -low
	var bevel_low := Vector2.ONE
	var bevel_high := Vector2.ONE
	if not joined.is_empty():
		var long_axis := 0 if size.x > size.z else 1
		if joined[0] != null:
			low[long_axis] = maxf(low[long_axis], joined[0])
			bevel_low[long_axis] = 0.0
		if joined[1] != null:
			high[long_axis] = minf(high[long_axis], joined[1])
			bevel_high[long_axis] = 0.0
	var key := [half.y, low, high, bevel_low, bevel_high]
	if not cache.has(key):
		cache[key] = _chamfered_cap(half.y, low, high, bevel_low, bevel_high)
	instance.set_meta("art_source_mesh", source)
	instance.mesh = cache[key]

static func _chamfered_cap(half_height: float, low: Vector2, high: Vector2,
		bevel_low: Vector2, bevel_high: Vector2) -> ArrayMesh:
	var span := high - low
	var bevel := minf(0.039, minf(half_height * 0.65, minf(span.x, span.y) * 0.13))
	var bottom := _ring(low, high, -half_height)
	var shoulder := _ring(low, high, half_height - bevel)
	var cap := _ring(low + bevel_low * bevel, high - bevel_high * bevel, half_height)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(builder, bottom[0], bottom[1], bottom[2], bottom[3], Vector3.DOWN)
	_quad(builder, cap[0], cap[1], cap[2], cap[3], Vector3.UP)
	var sides := [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]
	for i in 4:
		var j := (i + 1) % 4
		_quad(builder, bottom[i], bottom[j], shoulder[j], shoulder[i], sides[i])
		_quad(builder, shoulder[i], shoulder[j], cap[j], cap[i], sides[i] + Vector3.UP)
	return builder.commit()

static func _ring(low: Vector2, high: Vector2, y: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(low.x, y, low.y), Vector3(high.x, y, low.y),
		Vector3(high.x, y, high.y), Vector3(low.x, y, high.y)])

static func _quad(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var clockwise := normal.dot(outward) < 0.0
	builder.set_normal(-normal if clockwise else normal)
	for point: Vector3 in ([a,b,c,a,c,d] if clockwise else [a,c,b,a,d,c]):
		builder.add_vertex(point)
