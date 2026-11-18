extends RefCounted
## Exact exterior union of the finished wall solids. Physics and grid positions
## stay untouched; shared faces and the bevels at every grid seam disappear.
static func apply(generator: Node3D) -> void:
	var sources: Array[MeshInstance3D] = []
	for group: String in ["VerticalWalls","HorizontalWalls"]:
		for body: Node3D in generator.get_node(group).get_children():
			var visual := body.get_child(0) as MeshInstance3D
			if visual.mesh is BoxMesh:
				sources.append(visual)
	for portal: Node3D in generator.architecture.get_children():
		if str(portal.name).begins_with("Frame_"):
			for visual: MeshInstance3D in portal.find_children("*","MeshInstance3D",true,false):
				if visual.mesh is BoxMesh:
					sources.append(visual)
	var coordinates: Array = [{},{},{}]
	var bounds: Array[AABB] = []
	for visual: MeshInstance3D in sources:
		var box: BoxMesh = visual.mesh
		var transformed: AABB = visual.global_transform*AABB(-box.size*0.5,box.size)
		var lo := transformed.position.snapped(Vector3.ONE*0.0001)
		var hi := transformed.end.snapped(Vector3.ONE*0.0001)
		bounds.append(AABB(lo,hi-lo))
		for axis in 3:
			coordinates[axis][lo[axis]]=true
			coordinates[axis][hi[axis]]=true
	var axes: Array = []
	var indices: Array = []
	for axis in 3:
		var values: Array = coordinates[axis].keys()
		values.sort()
		axes.append(values)
		var lookup: Dictionary = {}
		for i in values.size():
			lookup[values[i]]=i
		indices.append(lookup)
	var cells: Dictionary = {}
	for owner in bounds.size():
		var box := bounds[owner]
		for x in range(indices[0][box.position.x],indices[0][box.end.snapped(Vector3.ONE*0.0001).x]):
			for y in range(indices[1][box.position.y],indices[1][box.end.snapped(Vector3.ONE*0.0001).y]):
				for z in range(indices[2][box.position.z],indices[2][box.end.snapped(Vector3.ONE*0.0001).z]):
					cells[Vector3i(x,y,z)]=owner
	var builders: Array[SurfaceTool] = []
	for owner in sources.size():
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builders.append(builder)
	var face_counts: Dictionary = {}
	var directions := [Vector3i(-1,0,0),Vector3i(1,0,0),Vector3i(0,-1,0),Vector3i(0,1,0),Vector3i(0,0,-1),Vector3i(0,0,1)]
	for cell: Vector3i in cells:
		var owner: int = cells[cell]
		var lo := Vector3(axes[0][cell.x],axes[1][cell.y],axes[2][cell.z])
		var hi := Vector3(axes[0][cell.x+1],axes[1][cell.y+1],axes[2][cell.z+1])
		var points := [
			[Vector3(lo.x,lo.y,lo.z),Vector3(lo.x,hi.y,lo.z),Vector3(lo.x,hi.y,hi.z),Vector3(lo.x,lo.y,hi.z)],
			[Vector3(hi.x,lo.y,lo.z),Vector3(hi.x,hi.y,lo.z),Vector3(hi.x,hi.y,hi.z),Vector3(hi.x,lo.y,hi.z)],
			[Vector3(lo.x,lo.y,lo.z),Vector3(hi.x,lo.y,lo.z),Vector3(hi.x,lo.y,hi.z),Vector3(lo.x,lo.y,hi.z)],
			[Vector3(lo.x,hi.y,lo.z),Vector3(hi.x,hi.y,lo.z),Vector3(hi.x,hi.y,hi.z),Vector3(lo.x,hi.y,hi.z)],
			[Vector3(lo.x,lo.y,lo.z),Vector3(hi.x,lo.y,lo.z),Vector3(hi.x,hi.y,lo.z),Vector3(lo.x,hi.y,lo.z)],
			[Vector3(lo.x,lo.y,hi.z),Vector3(hi.x,lo.y,hi.z),Vector3(hi.x,hi.y,hi.z),Vector3(lo.x,hi.y,hi.z)]]
		for side in 6:
			if not cells.has(cell+directions[side]):
				_quad(builders[owner],points[side],Vector3(directions[side]),sources[owner].global_transform.affine_inverse())
				face_counts[owner]=true
	for owner in sources.size():
		var source := sources[owner]
		source.set_meta("art_source_mesh",source.mesh)
		source.set_meta("unified_wall",true)
		if face_counts.has(owner):
			source.mesh=builders[owner].commit()
		else:
			source.hide()
	generator.set_meta("unified_wall_count",sources.size())

static func _quad(builder: SurfaceTool, points: Array, normal: Vector3, to_local: Transform3D) -> void:
	builder.set_normal((to_local.basis*normal).normalized())
	var order := [0,1,2,0,2,3]
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal)>0.0:
		order=[0,2,1,0,3,2]
	for index in order:
		builder.add_vertex(to_local*points[index])
