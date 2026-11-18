extends RefCounted
## Closed architectural solids with small real chamfers and correct outward normals.
static func surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

static func face(st: SurfaceTool, points: PackedVector3Array, normal: Vector3) -> void:
	st.set_normal(normal)
	for i in range(1,points.size()-1):
		var b := points[i]
		var c := points[i+1]
		if (b-points[0]).cross(c-points[0]).dot(normal)>0:
			var swap := b
			b = c
			c = swap
		st.add_vertex(points[0])
		st.add_vertex(b)
		st.add_vertex(c)

static func solid(st: SurfaceTool, center: Vector3, size: Vector3, bevel: float = 0.35, taper: float = 1.0) -> void:
	var x := size.x/2
	var z := size.z/2
	var b := minf(bevel,minf(x,z)*0.45)
	var outline := PackedVector2Array([Vector2(-x+b,-z),Vector2(x-b,-z),Vector2(x,-z+b),Vector2(x,z-b),Vector2(x-b,z),Vector2(-x+b,z),Vector2(-x,z-b),Vector2(-x,-z+b)])
	var lower := PackedVector3Array()
	var upper := PackedVector3Array()
	for p: Vector2 in outline:
		lower.append(center+Vector3(p.x,-size.y/2,p.y))
		upper.append(center+Vector3(p.x*taper,size.y/2,p.y*taper))
	face(st,lower,Vector3.DOWN)
	face(st,upper,Vector3.UP)
	for i in outline.size():
		var j := (i+1)%outline.size()
		var vertices := PackedVector3Array([lower[i],lower[j],upper[j],upper[i]])
		var n := (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
		var middle := (vertices[0]+vertices[1]+vertices[2]+vertices[3])/4
		if n.dot(middle-center)<0:
			n = -n
		face(st,vertices,n)

static func arch(st: SurfaceTool, point: Vector3, opening: Vector2, spring: float, thickness: float, depth: float) -> void:
	# One structural arch with real piers and an open intrados, not a floating torus.
	for side: float in [-1.0,1.0]:
		solid(st,point+Vector3(side*(opening.x/2+thickness/2),spring/2,0),Vector3(thickness,spring,depth),0.32)
	var steps := 44
	for i in steps:
		var a: float = PI*i/steps
		var b: float = PI*(i+1)/steps
		var vertices := PackedVector3Array()
		for angle: float in [a,b]:
			for z: float in [-depth/2,depth/2]:
				for inset: float in [0.0,thickness]:
					vertices.append(point+Vector3(cos(angle)*(opening.x/2+inset),spring+sin(angle)*(opening.y+inset),z))
		var center := Vector3.ZERO
		for v: Vector3 in vertices:
			center += v/8
		var faces := [[0,1,5,4],[2,6,7,3],[0,4,6,2],[1,3,7,5]]
		if i==0:
			faces.append([0,2,3,1])
		if i==steps-1:
			faces.append([4,5,7,6])
		for indices: Array in faces:
			var points := PackedVector3Array()
			var middle := Vector3.ZERO
			for index: int in indices:
				points.append(vertices[index])
				middle += vertices[index]/4
			var normal := (points[1]-points[0]).cross(points[2]-points[0]).normalized()
			if normal.dot(middle-center)<0:
				normal = -normal
			face(st,points,normal)

static func finish(parent: Node3D, id: String, st: SurfaceTool, material: Material, shadow: bool = true) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = id
	visual.mesh = st.commit()
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual
