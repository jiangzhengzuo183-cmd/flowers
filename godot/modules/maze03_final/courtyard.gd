extends RefCounted
const Base := preload("res://scripts/levels/maze_01_layout.gd")
const F := preload("res://modules/maze03_final/architecture_forms.gd")
const G := preload("res://scripts/levels/greybox_geometry.gd")
const AREA := Rect2(0,4.8,9.6,9.6)

static func height_at(_point: Vector2) -> float:
	return 0.0

static func build(parent: Node3D, material: Material) -> PackedVector3Array:
	for child in parent.get_children():
		child.free()
	var corners := PackedVector3Array([Vector3(0,0,4.8),Vector3(9.6,0,4.8),Vector3(9.6,0,14.4),Vector3(0,0,14.4)])
	var faces := PackedVector3Array()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in [0,1,2,0,2,3]:
		st.add_vertex(corners[i])
		faces.append(corners[i])
	var floor := MeshInstance3D.new()
	floor.name = "FlatCourtFloor"
	floor.set_meta("art_role","floor")
	floor.mesh = st.commit()
	floor.material_override = material
	parent.add_child(floor)
	_build_canopy(parent)
	return faces
static func _build_canopy(parent: Node3D) -> void:
	var roof := Node3D.new()
	roof.name = "LayeredRibbonCourt"
	parent.add_child(roof)
	var stone := load("res://art/maze01/materials/plaster_cream.tres").duplicate() as StandardMaterial3D
	stone.albedo_color = Color("e9e9e5")
	stone.normal_scale = 0.09
	# Three broad, asymmetric loop plates. These are continuous bending sheets,
	# not the rejected radial fan of thirty-two disconnected slices.
	var bands := [
		[Vector2(4.70,9.60),Vector2(4.12,3.55),2.90,0.88,-0.25,5.40],
		[Vector2(4.70,9.60),Vector2(2.70,2.20),3.19,0.75,0.42,5.10],
		[Vector2(4.70,9.60),Vector2(1.25,1.00),3.46,0.62,1.00,4.45],
	]
	for index in bands.size():
		var spec: Array = bands[index]
		var center: Vector2 = spec[0]
		var radius: Vector2 = spec[1]
		var top: float = spec[2]
		var width: float = spec[3]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 80:
			var vertices := PackedVector3Array()
			for step in [i,i+1]:
				var t := float(step)/80
				var angle: float = spec[4]+spec[5]*t
				var height := top+sin(angle*1.6+index)*0.11
				for y in [height,height-0.12]:
					for r in [-width*0.5,width*0.5]:
						vertices.append(Vector3(center.x+cos(angle)*(radius.x+r),y,center.y+sin(angle)*(radius.y+r)))
			for face: Array in [[0,1,5,4],[2,6,7,3],[0,4,6,2],[1,3,7,5]]:
				for vertex_index in [face[0],face[2],face[1],face[0],face[3],face[2]]:
					st.add_vertex(vertices[vertex_index])
		st.generate_normals()
		var surface := st.commit()
		var body := StaticBody3D.new()
		body.name = "ContinuousRibbon"+str(index)
		body.collision_layer = 5
		roof.add_child(body)
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface
		mesh.material_override = stone
		body.add_child(mesh)
		var collision := CollisionShape3D.new()
		collision.shape = surface.create_trimesh_shape()
		body.add_child(collision)
	# The lowest sheet extends into two existing edge walls; the terrace reads as
	# part of the maze architecture. Its low horizontal profile stays subordinate.
	for spec: Array in [[Vector3(0.34,1.30,8.0),Vector3(0.23,2.60,0.58)],[Vector3(9.25,1.34,7.2),Vector3(0.23,2.68,0.58)]]:
		G.box(roof,"WallIntegratedRibbonSpring",spec[1],spec[0],stone)
	_curved_walls(roof,stone)

	# The yellow-marked wall is extended, retaining a 1.55m walking opening above it.
	G.box(roof,"SouthCourtWallExtension",Vector3(0.24,1.10,0.85),Vector3(2.40,0.55,16.375),stone)

static func _curved_walls(parent: Node3D, stone: Material) -> void:
	# Staggered openings under the retained roof bands. They form a local curved maze.
	_arc_wall(parent,"OuterNorthwestArc",Vector2(3.95,3.35),155.0,280.0,1.78,stone)
	_arc_wall(parent,"OuterNortheastArc",Vector2(3.95,3.35),310.0,355.0,1.58,stone)
	_arc_wall(parent,"MiddleSouthArc",Vector2(2.50,2.00),20.0,195.0,1.48,stone)
	_arc_wall(parent,"InnerNorthArc",Vector2(1.05,0.80),175.0,400.0,0.92,stone)

static func _arc_wall(parent: Node3D,id: String,radii: Vector2,from_degrees: float,to_degrees: float,height: float,stone: Material) -> void:
	var begin := deg_to_rad(from_degrees)
	var finish := deg_to_rad(to_degrees)
	var steps := ceili((finish-begin)*18.0)
	var st := F.surface()
	for i in steps:
		var verts := PackedVector3Array()
		for step in [i,i+1]:
			var angle := lerpf(begin,finish,float(step)/steps)
			for y in [-0.04,height]:
				for offset in [-0.13,0.13]:
					verts.append(Vector3(4.70+cos(angle)*(radii.x+offset),y,9.60+sin(angle)*(radii.y+offset)))
		var faces := [[0,1,5,4],[2,6,7,3],[0,4,6,2],[1,3,7,5]]
		if i==0:
			faces.append([0,2,3,1])
		if i==steps-1:
			faces.append([4,5,7,6])
		var center := Vector3.ZERO
		for v in verts:
			center += v/8.0
		for face: Array in faces:
			var points := PackedVector3Array()
			var middle := Vector3.ZERO
			for index: int in face:
				points.append(verts[index])
				middle += verts[index]/4.0
			var normal := (points[1]-points[0]).cross(points[2]-points[0]).normalized()
			if normal.dot(middle-center)<0:
				normal = -normal
			_smooth_arc_face(st,points,normal,radii)
	var surface := st.commit()
	var body := StaticBody3D.new()
	body.name = id
	body.collision_layer = 5
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface
	mesh.material_override = stone
	mesh.set_meta("art_role","plaster")
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	collision.shape = surface.create_trimesh_shape()
	body.add_child(collision)


static func _smooth_arc_face(st: SurfaceTool,points: PackedVector3Array,normal: Vector3,radii: Vector2) -> void:
	var center := Vector3.ZERO
	for p in points:
		center += p/points.size()
	var outward := Vector3((center.x-4.7)/(radii.x*radii.x),0,(center.z-9.6)/(radii.y*radii.y)).normalized()
	var curved := absf(normal.y)<0.1 and absf(normal.dot(outward))>0.7
	for i in range(1,points.size()-1):
		var b := points[i]
		var c := points[i+1]
		if (b-points[0]).cross(c-points[0]).dot(normal)>0:
			var swap := b
			b = c
			c = swap
		for p: Vector3 in [points[0],b,c]:
			var n := normal
			if curved:
				n = Vector3((p.x-4.7)/(radii.x*radii.x),0,(p.z-9.6)/(radii.y*radii.y)).normalized()
				if n.dot(normal)<0:
					n = -n
			st.set_normal(n)
			st.add_vertex(p)

