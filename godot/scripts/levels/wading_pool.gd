extends RefCounted

const Water := preload("res://art/maze01/wading_water.gdshader")

static func add_surface(parent: Node3D, ground: Array[PackedVector3Array], water_y: float, bottom_y: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depth := water_y-bottom_y
	for faces: PackedVector3Array in ground:
		for i in range(0,faces.size(),3):
			# Clip the visible ground and treads at the horizontal water level.
			var polygon := PackedVector3Array()
			for j in 3:
				var a := faces[i+j]
				var b := faces[i+(j+1)%3]
				if a.y<water_y:
					polygon.append(a)
				if (a.y<water_y)!=(b.y<water_y):
					polygon.append(a.lerp(b,(water_y-a.y)/(b.y-a.y)))
			for j in range(1,polygon.size()-1):
				for point: Vector3 in [polygon[0],polygon[j],polygon[j+1]]:
					surface.set_uv(Vector2(clampf((water_y-point.y)/depth,0.0,1.0),0.0))
					surface.set_normal(Vector3.UP)
					surface.add_vertex(Vector3(point.x,water_y,point.z))
	var water := MeshInstance3D.new()
	water.name = "WadingPoolSurface"
	water.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = Water
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta("greybox_part","WadingPoolSurface")
	water.set_meta("art_role","water")
	water.set_meta("art_addition",true)
	parent.add_child(water)
