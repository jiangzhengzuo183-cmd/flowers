extends RefCounted
## The same arched profile cuts the masonry and builds both faces of the window.

const Geometry := preload("res://scripts/levels/greybox_geometry.gd")
const WallPlan := preload("res://scripts/levels/wall_plan.gd")
const SILL := 1.08
const SPRING := 2.72
const HALF_WIDTH := 0.48
const SEGMENTS := 12

static func frames(center: Vector2, radius: float, porches: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for angle: float in [0.26, 0.79, 1.83, 2.36, 2.88, 3.40, 3.93]:
		var outward := Vector2(cos(angle), sin(angle))
		var point := center + outward * radius
		var blocked := false
		for porch: Dictionary in porches:
			var r: Array = porch.rect
			var bounds := Rect2(r[0], r[2], float(r[1])-float(r[0]), float(r[3])-float(r[2]))
			if bounds.grow(0.64).has_point(point):
				blocked = true
				break
		if not blocked:
			result.append({"angle": angle, "radial": outward, "tangent": Vector2(outward.y, -outward.x)})
	return result

static func cut_wall(plan: PackedVector2Array, center: Vector2, inner: float, windows: Array[Dictionary], height: float) -> ArrayMesh:
	for window: Dictionary in windows:
		var radial: Vector2 = window.radial
		if radial.dot(plan[0] - center) < inner - 0.55:
			continue
		var axis: Vector2 = window.tangent
		var origin := axis.dot(center)
		var middle := _slice(plan, axis, origin - HALF_WIDTH, origin + HALF_WIDTH)
		if middle.size() < 3 or WallPlan.area(middle) < 0.000001:
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_volume(surface, WallPlan.clip(plan, axis, origin - HALF_WIDTH, false), 0.0, height)
		_volume(surface, WallPlan.clip(plan, axis, origin + HALF_WIDTH, true), 0.0, height)
		_volume(surface, middle, 0.0, SILL)
		for i in SEGMENTS:
			var a := _crown(i, HALF_WIDTH)
			var b := _crown(i+1, HALF_WIDTH)
			var strip := _slice(middle, axis, origin + a.x, origin + b.x)
			_volume(surface, strip, a.y, height, axis, origin + a.x, (b.y - a.y) / (b.x - a.x))
		return surface.commit()
	return null

static func _slice(plan: PackedVector2Array, axis: Vector2, low: float, high: float) -> PackedVector2Array:
	return WallPlan.clip(WallPlan.clip(plan, axis, low, true), axis, high, false)

static func _crown(index: int, radius: float) -> Vector2:
	var angle := PI * index / SEGMENTS
	return Vector2(-cos(angle) * radius, SPRING + sin(angle) * radius)

static func _volume(surface: SurfaceTool, plan: PackedVector2Array, floor_y: float, ceiling_y: float, axis := Vector2.ZERO, origin := 0.0, slope := 0.0) -> void:
	if plan.size() < 3 or WallPlan.area(plan) < 0.000001:
		return
	var low := PackedVector3Array()
	var high := PackedVector3Array()
	var center := Vector3.ZERO
	for point: Vector2 in plan:
		var bottom := Vector3(point.x, floor_y + (point.dot(axis) - origin) * slope, point.y)
		var top := Vector3(point.x, ceiling_y, point.y)
		low.append(bottom)
		high.append(top)
		center += (bottom + top) / (2 * plan.size())
	for i in range(1, plan.size()-1):
		_triangle(surface, low[0], low[i], low[i+1], low[0] - center)
		_triangle(surface, high[0], high[i], high[i+1], high[0] - center)
	for i in plan.size():
		var j := (i+1) % plan.size()
		_triangle(surface, low[i], high[i], high[j], low[i] - center)
		_triangle(surface, low[i], high[j], low[j], low[i] - center)

static func build(parent: Node3D, center: Vector2, inner: float, outer: float, specs: Array[Dictionary], trim: Material) -> void:
	var radius := (inner + outer) * 0.5
	var pane_mesh := _pane()
	var inside := _surround(inner, radius, -1.0)
	var outside := _surround(outer, radius, 1.0)
	for spec: Dictionary in specs:
		var window := Node3D.new()
		window.name = "ArchedWindowRecess"
		var point := center + (spec.radial as Vector2) * radius
		window.position = Vector3(point.x, 0, point.y)
		window.rotation.y = PI / 2.0 - float(spec.angle)
		parent.add_child(window, true)
		window.set_meta("main_window", is_equal_approx(float(spec.angle), 2.88))
		_mesh(window, "WindowPane", pane_mesh, Geometry.material(Color("6999a8")))
		_mesh(window, "ArchFrame", inside, trim)
		_mesh(window, "ArchFrame", outside, trim)
		Geometry.box(window, "Mullion", Vector3(0.038, SPRING + HALF_WIDTH - SILL, 0.075), Vector3(0, (SPRING + HALF_WIDTH + SILL) / 2.0, 0), trim, false)
		Geometry.box(window, "Transom", Vector3(HALF_WIDTH * 2, 0.040, 0.075), Vector3(0, SPRING, 0), trim, false)
		for side: float in [-1.0, 1.0]:
			var wall_radius := inner if side < 0.0 else outer
			var z := wall_radius - radius
			Geometry.box(window, "Sill", Vector3(1.16, 0.082, 0.16), Vector3(0, SILL - 0.04, z), trim, false)

static func _mesh(parent: Node3D, part: String, mesh: Mesh, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = part
	instance.mesh = mesh
	instance.material_override = material
	instance.set_meta("greybox_part", part)
	parent.add_child(instance, true)

static func _profile(half: float, sill: float) -> PackedVector2Array:
	var path := PackedVector2Array([Vector2(-half, sill), Vector2(half, sill)])
	for i in range(SEGMENTS, -1, -1):
		path.append(_crown(i, half))
	return path

static func _pane() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := _profile(HALF_WIDTH + 0.006, SILL - 0.006)
	var center := Vector2(0, (SILL + SPRING) * 0.5)
	surface.set_normal(Vector3.BACK)
	for i in points.size():
		for p: Vector2 in [center, points[(i + 1) % points.size()], points[i]]:
			surface.set_uv(Vector2(p.x / (HALF_WIDTH * 2) + 0.5, (p.y - SILL) / (SPRING + HALF_WIDTH - SILL)))
			surface.add_vertex(Vector3(p.x, p.y, 0))
	return surface.commit()

static func _surround(radius: float, anchor_radius: float, side: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := _profile(HALF_WIDTH - 0.016, SILL)
	var outer := _profile(HALF_WIDTH + 0.082, SILL - 0.07)
	for i in inner.size():
		var j := (i + 1) % inner.size()
		var a := _on_wall(inner[i], radius, anchor_radius, side * 0.038)
		var b := _on_wall(inner[j], radius, anchor_radius, side * 0.038)
		var c := _on_wall(outer[j], radius, anchor_radius, side * 0.026)
		var d := _on_wall(outer[i], radius, anchor_radius, side * 0.026)
		_triangle(surface, a, b, c, Vector3.BACK * side)
		_triangle(surface, a, c, d, Vector3.BACK * side)
	return surface.commit()

static func _on_wall(point: Vector2, radius: float, anchor_radius: float, offset: float) -> Vector3:
	return Vector3(point.x, point.y, sqrt(radius * radius - point.x * point.x) - anchor_radius + offset)

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b-a).cross(c-a)
	if normal.length_squared() < 0.00000000001:
		return
	var forward := normal.dot(outward) > 0.0
	surface.set_normal(normal.normalized() * (1.0 if forward else -1.0))
	for p: Vector3 in ([a,c,b] if forward else [a,b,c]):
		surface.add_vertex(p)
