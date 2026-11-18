extends RefCounted
## Unioned thin shoreline walls and fitted dry corner infills share one collision surface.
const F := preload("res://modules/maze03_final/architecture_forms.gd")
const POOL := Rect2(15.6,14.4,16.8,16.8)
const HEIGHT := 0.80
const BOTTOM := -0.24
const WIDTH := 0.16
const OPENING := 2.8
const RADIUS := 0.85
static func build(parent: Node3D) -> Node3D:
	var group := Node3D.new()
	group.name = "StreamlinedPoolBoundary"
	parent.add_child(group)
	var x0 := POOL.position.x
	var x1 := POOL.end.x
	var z0 := POOL.position.y
	var z1 := POOL.end.y
	var outlines: Array[PackedVector2Array] = []
	var west := PackedVector2Array([Vector2(24-OPENING/2,z0),Vector2(x0+RADIUS,z0)])
	_append_arc(west,Vector2(x0+RADIUS,z0+RADIUS),PI*1.5,PI)
	west.append(Vector2(x0,z1-RADIUS))
	_append_arc(west,Vector2(x0+RADIUS,z1-RADIUS),PI,PI*0.5)
	west.append(Vector2(24-OPENING/2,z1))
	outlines.append(_outline(west))
	var east := PackedVector2Array([Vector2(24+OPENING/2,z0),Vector2(x1-RADIUS,z0)])
	_append_arc(east,Vector2(x1-RADIUS,z0+RADIUS),PI*1.5,TAU)
	east.append(Vector2(x1,z1-RADIUS))
	_append_arc(east,Vector2(x1-RADIUS,z1-RADIUS),0,PI*0.5)
	east.append(Vector2(24+OPENING/2,z1))
	outlines.append(_outline(east))
	var st := F.surface()
	for polygon: PackedVector2Array in outlines:
		_extrude(st,polygon)
	var material := load("res://art/maze01/materials/plaster_cream.tres").duplicate() as StandardMaterial3D
	material.albedo_color = Color("e9e9e5")
	var visual := F.finish(group,"ContinuousLowShoreWalls",st,material)
	visual.set_meta("art_role","plaster")
	var corners := F.surface()
	for spec: Vector3 in [Vector3(x0+RADIUS,z0+RADIUS,PI),Vector3(x1-RADIUS,z0+RADIUS,PI*1.5),Vector3(x1-RADIUS,z1-RADIUS,0),Vector3(x0+RADIUS,z1-RADIUS,PI*0.5)]:
		var corner := Vector3(x0 if spec.x<24 else x1,0,z0 if spec.y<22.8 else z1)
		for i in 64:
			var a := spec.z+PI*0.5*i/64.0
			var b := spec.z+PI*0.5*(i+1)/64.0
			var p := Vector3(clampf(spec.x+cos(a)*(RADIUS+WIDTH/2),x0,x1),0,clampf(spec.y+sin(a)*(RADIUS+WIDTH/2),z0,z1))
			var q := Vector3(clampf(spec.x+cos(b)*(RADIUS+WIDTH/2),x0,x1),0,clampf(spec.y+sin(b)*(RADIUS+WIDTH/2),z0,z1))
			if (p-corner).cross(q-corner).length_squared()>0.000000001:
				F.face(corners,PackedVector3Array([corner,p,q]),Vector3.UP)
	var corner_mesh := F.finish(group,"FittedDryCornerGround",corners,material)
	corner_mesh.set_meta("art_role","floor")
	corner_mesh.layers = 4
	var faces := visual.mesh.get_faces()
	faces.append_array(corner_mesh.mesh.get_faces())
	var body := StaticBody3D.new()
	body.name = "ShoreAndCorridorCollision"
	body.collision_layer = 5
	group.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collider.shape = shape
	body.add_child(collider)
	group.set_meta("corridor_connections",0)
	group.set_meta("entrance_centers",[Vector3(24,0,z0),Vector3(24,0,z1)])
	return group
static func _append_arc(points: PackedVector2Array,center: Vector2,start: float,end: float) -> void:
	for i in range(1,65):
		var a := lerpf(start,end,i/64.0)
		points.append(center+Vector2(cos(a),sin(a))*RADIUS)
static func _outline(points: PackedVector2Array) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in points.size():
		var direction := (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var side := Vector2(-direction.y,direction.x)*WIDTH/2
		left.append(points[i]+side)
		right.append(points[i]-side)
	right.reverse()
	left.append_array(right)
	return left
static func _extrude(st: SurfaceTool,p: PackedVector2Array) -> void:
	if Geometry2D.is_polygon_clockwise(p):
		p.reverse()
	var triangles := Geometry2D.triangulate_polygon(p)
	for i in range(0,triangles.size(),3):
		var points := PackedVector3Array()
		for index: int in [triangles[i],triangles[i+1],triangles[i+2]]:
			points.append(Vector3(p[index].x,HEIGHT,p[index].y))
		F.face(st,points,Vector3.UP)
	var normals := PackedVector3Array()
	for i in p.size():
		var along := (p[(i+1)%p.size()]-p[i]).normalized()
		normals.append(Vector3(along.y,0,-along.x))
	for i in p.size():
		var j := (i+1)%p.size()
		var n := normals[i]
		var prev := normals[(i+p.size()-1)%p.size()]
		var next := normals[j]
		var ni := (prev+n).normalized() if prev.dot(n)>0.97 else n
		var nj := (next+n).normalized() if next.dot(n)>0.97 else n
		var a := Vector3(p[i].x,BOTTOM,p[i].y)
		var b := Vector3(p[j].x,BOTTOM,p[j].y)
		var c := Vector3(p[j].x,HEIGHT,p[j].y)
		var e := Vector3(p[i].x,HEIGHT,p[i].y)
		for tri: Array in [[a,b,c],[a,c,e]]:
			if (tri[1]-tri[0]).cross(tri[2]-tri[0]).dot(n)>0:
				var swap: Vector3 = tri[1]
				tri[1] = tri[2]
				tri[2] = swap
			for v: Vector3 in tri:
				st.set_normal(ni if v.is_equal_approx(a) or v.is_equal_approx(e) else nj)
				st.add_vertex(v)


