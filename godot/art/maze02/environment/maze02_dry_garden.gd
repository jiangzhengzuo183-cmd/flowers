extends RefCounted
## Refinish the existing meadow and its visual-only flower mesh.

static func apply(statue: Node3D) -> void:
	var meadow := statue.get_node("PlazaMeadow") as MeshInstance3D
	var ground := meadow.material_override.duplicate() as ShaderMaterial
	ground.set_shader_parameter("turf", Color("9f925e"))
	ground.set_shader_parameter("fresh", Color("dcc389"))
	meadow.material_override = ground

	var growth := statue.get_node("PlazaGreenery") as MeshInstance3D
	var arrays := growth.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	# Lean blades and droop the shorter flowers together so petals stay on their stems.
	var lean := Basis(Vector3.RIGHT, Vector3(0.41, 0.70, 0.15), Vector3.BACK)
	var normal_basis := lean.inverse().transposed()
	for i in points.size():
		var source := colors[i]
		var variation := 0.5 + 0.5 * sin(points[i].x * 2.3 + points[i].z * 3.4)
		var dried := Color("8c8c55").lerp(Color("d7b674"), variation)
		if source.r > source.g and source.r > 0.75:
			dried = Color("a87848").lerp(Color("d9bd8c"), source.b)
		colors[i] = dried.lightened(clampf(points[i].y * 0.19, 0.0, 0.08))
		points[i] = lean * points[i]
		normals[i] = (normal_basis * normals[i]).normalized()
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var dry_mesh := ArrayMesh.new()
	dry_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	growth.mesh = dry_mesh
