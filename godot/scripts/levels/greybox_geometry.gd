extends RefCounted
## Small collision-matched building blocks; no authored model dependencies.
const WALL_GREY := Color("747e80")

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

static func box(parent: Node3D, id: String, size: Vector3, center: Vector3, mat: Material, collide: bool = true) -> Node3D:
	var node: Node3D = StaticBody3D.new() if collide else Node3D.new()
	node.name = id
	node.position = center
	parent.add_child(node)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = mat
	visual.set_meta("greybox_part",id)
	node.add_child(visual)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		node.add_child(collider)
	return node

static func prism(parent: Node3D, id: String, vertices: PackedVector3Array, mat: Material, clockwise: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = id
	parent.add_child(body)
	var shape := ConvexPolygonShape3D.new()
	shape.points = vertices
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3.ZERO
	for vertex: Vector3 in vertices:
		center += vertex / vertices.size()
	for face: Array in [[0,1,2,3],[4,7,6,5],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]:
		var normal: Vector3 = (vertices[face[1]] - vertices[face[0]]).cross(vertices[face[2]] - vertices[face[0]]).normalized()
		var face_center: Vector3 = (vertices[face[0]] + vertices[face[1]] + vertices[face[2]] + vertices[face[3]]) / 4
		if normal.dot(face_center - center) < 0:
			normal = -normal
		st.set_normal(normal)
		for triangle: Array in [[face[0],face[1],face[2]],[face[0],face[2],face[3]]]:
			var a: Vector3 = vertices[triangle[0]]
			var b: Vector3 = vertices[triangle[1]]
			var c: Vector3 = vertices[triangle[2]]
			if clockwise and (b-a).cross(c-a).dot(normal)>0:
				var swap := b
				b = c
				c = swap
			for p: Vector3 in [a,b,c]:
				st.add_vertex(p)
	var visual := MeshInstance3D.new()
	visual.mesh = st.commit()
	visual.material_override = mat
	visual.set_meta("greybox_part",id)
	body.add_child(visual)
	return body

static func extruded_polygon(parent: Node3D,id: String,poly: PackedVector2Array,bottom: float,top: float,mat: Material,clockwise: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = id
	parent.add_child(body)
	var vertices := PackedVector3Array()
	for y in [bottom,top]:
		for p: Vector2 in poly:
			vertices.append(Vector3(p.x,y,p.y))
	var shape := ConvexPolygonShape3D.new()
	shape.points = vertices
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3.ZERO
	for p: Vector3 in vertices:
		center += p/vertices.size()
	var count := poly.size()
	var faces: Array = []
	for i in range(1,count-1):
		faces.append([0,i,i+1])
		faces.append([count,count+i+1,count+i])
	for i in count:
		var j := (i+1)%count
		faces.append([i,j,count+j])
		faces.append([i,count+j,count+i])
	for face: Array in faces:
		var a: Vector3 = vertices[face[0]]
		var b: Vector3 = vertices[face[1]]
		var c: Vector3 = vertices[face[2]]
		var normal := (b-a).cross(c-a).normalized()
		if normal.dot((a+b+c)/3-center)<0:
			var swap := b
			b = c
			c = swap
			normal = -normal
		st.set_normal(normal)
		# Godot's front faces are clockwise. On a double-sided material, an
		# inverted front face reverses the otherwise outward lighting normal.
		for p: Vector3 in ([a,c,b] if clockwise else [a,b,c]):
			st.add_vertex(p)
	var visual := MeshInstance3D.new()
	visual.mesh = st.commit()
	visual.material_override = mat
	visual.set_meta("greybox_part",id)
	body.add_child(visual)
	return body

static func label(parent: Node3D, text: String, point: Vector3, size: int = 44) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.font = load("res://assets/fonts/SourceHanSansSC-Regular.otf")
	node.font_size = size
	node.pixel_size = 0.006
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.modulate = Color("263b3c")
	node.outline_modulate = Color("eeeae0")
	node.outline_size = 5
	node.position = point
	parent.add_child(node)
	return node

static func plan_surface(parent: Node3D,id: String,polys: Array[PackedVector2Array],height: float,mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for poly: PackedVector2Array in polys:
		for i in range(1,poly.size()-1):
			for p: Vector2 in [poly[0],poly[i],poly[i+1]]:
				st.add_vertex(Vector3(p.x,height,p.y))
	var mesh := MeshInstance3D.new()
	mesh.name = id
	mesh.mesh = st.commit()
	mesh.material_override = mat
	mesh.set_meta("greybox_part",id)
	parent.add_child(mesh)
	return mesh

static func extruded_section(parent: Node3D,id: String,poly: PackedVector2Array,x0: float,x1: float,mat: Material) -> StaticBody3D:
	# Map plan (horizontal, vertical) to a section in world Z/Y, extruded along X.
	var body := extruded_polygon(parent,id,poly,x0,x1,mat)
	body.basis = Basis(Vector3(0,0,1),Vector3(1,0,0),Vector3(0,1,0))
	return body

static func beam(parent: Node3D, id: String, a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var node := box(parent, id, Vector3(width,width,a.distance_to(b)), (a+b)/2, mat, false)
	if a.distance_to(b) > 0.001:
		node.look_at_from_position((a+b)/2, b, Vector3.UP)

static func chime(parent: Node) -> void:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(6615 * 2)
	for i in 6615:
		var t := float(i) / 22050
		var frequency := 520.0 if t < 0.15 else 680.0
		var value := int(sin(TAU * frequency * t) * sin(PI * t / 0.3) * 3500)
		bytes.encode_s16(i * 2, value)
	sound.data = bytes
	var player := AudioStreamPlayer.new()
	player.stream = sound
	player.volume_db = -8
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
