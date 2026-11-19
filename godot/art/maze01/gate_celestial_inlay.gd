extends RefCounted
## The two faces share this beveled relief mesh. Red stores the ignition time.

static func build() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_relief(tool, _star(Vector2(0,2.02), Vector2(0.163,0.178), 8), Vector2(0,2.02), 0.49)
	var tip := Vector2(-0.39,1.84)
	var outer_bottom := Vector2(0,1.02)
	var inner_bottom := Vector2(0,1.22)
	var outer := _arc(tip, Vector2(-0.78,1.40), Vector2(-0.52,1.02), outer_bottom)
	var inner := _arc(tip, Vector2(-0.65,1.43), Vector2(-0.36,1.22), inner_bottom)
	var crescent := outer.duplicate()
	for i in range(outer.size()-2,-1,-1):
		crescent.append(Vector2(-outer[i].x, outer[i].y))
	for i in range(1,inner.size()):
		crescent.append(Vector2(-inner[i].x, inner[i].y))
	for i in range(inner.size()-2,0,-1):
		crescent.append(inner[i])
	_relief(tool, crescent, Vector2(0,1.38), 0.35, true)
	for data: Vector3 in [Vector3(0.86,0.058,0.10), Vector3(1.39,0.018,0.17), Vector3(1.50,0.023,0.22), Vector3(1.59,0.016,0.265), Vector3(1.71,0.025,0.30)]:
		var center := Vector2(0,data.x)
		var dot_shape := PackedVector2Array()
		for i in 12:
			dot_shape.append(center + Vector2.from_angle(TAU*i/12.0)*data.y)
		_relief(tool, dot_shape, center, data.z)
	_relief(tool, _star(Vector2(0,0.39), Vector2(0.082,0.131), 4), Vector2(0,0.39), 0.0)
	return tool.commit()

static func _star(center: Vector2, radii: Vector2, rays: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in rays*2:
		var arm := 0.36 if i%2 else (0.86 if rays==8 and i%4==2 else 1.0)
		points.append(center + Vector2.from_angle(PI/2.0 + TAU*i/(rays*2.0))*radii*arm)
	return points

static func _arc(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 21:
		points.append(a.bezier_interpolate(b,c,d,i/20.0))
	return points

static func _relief(tool: SurfaceTool, points: PackedVector2Array, center: Vector2, start: float, crescent: bool = false) -> void:
	var top := PackedVector2Array()
	for point in points:
		# Compress the crescent's two edges toward the centerline of the band.
		var inner_center := Vector2(0,1.13) if crescent else center
		top.append(point.lerp(inner_center,0.045 if crescent else 0.16))
	var faces := Geometry2D.triangulate_polygon(top)
	for i in range(0,faces.size(),3):
		_triangle(tool, Vector3(top[faces[i]].x,top[faces[i]].y,0.015), Vector3(top[faces[i+2]].x,top[faces[i+2]].y,0.015), Vector3(top[faces[i+1]].x,top[faces[i+1]].y,0.015), start, crescent, false)
	for i in points.size():
		var j := (i+1)%points.size()
		var a := Vector3(points[i].x,points[i].y,0.0)
		var b := Vector3(points[j].x,points[j].y,0.0)
		var c := Vector3(top[j].x,top[j].y,0.015)
		var d := Vector3(top[i].x,top[i].y,0.015)
		_triangle(tool,a,b,c,start,crescent,true)
		_triangle(tool,a,c,d,start,crescent,true)

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, start: float, crescent: bool, bevel: bool) -> void:
	var normal := (c-a).cross(b-a).normalized()
	if normal.z < 0.0:
		normal = -normal
		var swap := b
		b = c
		c = swap
	tool.set_normal(normal)
	for point: Vector3 in [a,b,c]:
		var ignition := start + (absf(point.x)*0.25 if crescent else 0.0)
		tool.set_color(Color(ignition, 1.0 if bevel else 0.0, 0, 1))
		tool.add_vertex(point)
