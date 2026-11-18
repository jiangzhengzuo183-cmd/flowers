extends RefCounted
## Strip only the old pointed caps; preserve district layout, bodies and opaque depth.
static func simplify(mesh: ArrayMesh, variant: int) -> ArrayMesh:
	var height := 15.0+float(variant%4)*3.5
	var x := -13.0+7.8*float(variant%4)
	var roofs: Array = []
	if variant%2==0:
		roofs.append([Vector2(x,-1.0),height,5.8])
	else:
		roofs.append([Vector2(x+(17.0 if x<0 else -17.0),-10.0),height*0.76,4.5])
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size():
			indices.append(i)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,indices.size(),3):
		var remove := false
		for roof: Array in roofs:
			var all_inside := true
			var top := -100.0
			for offset in 3:
				var p := vertices[indices[i+offset]]
				var center: Vector2 = roof[0]
				if absf(p.x-center.x)>float(roof[2])*0.64 or absf(p.z-center.y)>float(roof[2])*0.64:
					all_inside = false
				top = maxf(top,p.y)
			if all_inside and top>float(roof[1])+3.0:
				remove = true
		if remove:
			continue
		for offset in 3:
			var index := indices[i+offset]
			st.set_normal(normals[index])
			st.add_vertex(vertices[index])
	return st.commit()
