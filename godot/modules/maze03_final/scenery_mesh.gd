extends RefCounted
## Builds static scenery into a handful of surfaces; scenery never has collision.
static func box(st: SurfaceTool, center: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	# Keep every primitive non-indexed. Mixing indexed BoxMesh faces with newly
	# added ring vertices would leave the latter outside the active index buffer.
	st.set_smooth_group(-1)
	var transform := Transform3D(basis,center)
	for vertex: Vector3 in mesh.get_faces():
		st.add_vertex(transform*vertex)

static func ellipse(st: SurfaceTool, center: Vector3, radius: Vector2, thickness: float, depth: float, start: float = 0.0, sweep: float = TAU, basis: Basis = Basis.IDENTITY) -> void:
	st.set_smooth_group(-1)
	var count := maxi(16,roundi(80*absf(sweep)/TAU))
	for i in count:
		var a := start+sweep*float(i)/count
		var b := start+sweep*float(i+1)/count
		var v := PackedVector3Array()
		for angle in [a,b]:
			for z in [-depth/2,depth/2]:
				for offset in [-thickness/2,thickness/2]:
					v.append(center+basis*Vector3(cos(angle)*(radius.x+offset),sin(angle)*(radius.y+offset),z))
		for face: Array in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:
			for triangle: Array in [[face[0],face[1],face[2]],[face[0],face[2],face[3]]]:
				for index: int in triangle:
					st.add_vertex(v[index])

static func finish(parent: Node3D, id: String, st: SurfaceTool, material: Material) -> MeshInstance3D:
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = id
	mesh.mesh = st.commit()
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh
