extends Node3D
## Local, depth-tested sunshafts plus dust visible only inside the light cone.
func _ready() -> void:
	name = "InteriorSunshaftsAndDust"
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://modules/maze03_final/interior_ray.gdshader")
	for i in 3:
		var start := Vector3(24.0+(i-1)*0.12,10.0,22.8)
		var end := Vector3(25.4+(i-1)*0.45,0.08,23.8+(i-1)*0.36)
		var along := (end-start).normalized()
		for plane in 2:
			var across := along.cross(Vector3.FORWARD if plane==0 else Vector3.RIGHT).normalized()
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for uv: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				st.set_uv(uv)
				st.add_vertex(start.lerp(end,uv.y)+across*(uv.x-0.5)*lerpf(0.09,0.65+float(i)*0.18,uv.y))
			var mesh := MeshInstance3D.new()
			mesh.name = "SoftInteriorRay"
			mesh.mesh = st.commit()
			mesh.material_override = paint
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh)
	var dust := CPUParticles3D.new()
	dust.name = "DustInSunlight"
	dust.amount = 38
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.local_coords = false
	dust.position = Vector3(24.5,5.0,23.2)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.6,4.4,1.6)
	dust.direction = Vector3(0.35,-0.25,0.15)
	dust.spread = 22
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 0.06
	dust.initial_velocity_max = 0.14
	var mote := SphereMesh.new()
	mote.radius = 0.010
	mote.height = 0.020
	mote.radial_segments = 4
	mote.rings = 1
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://modules/maze03_final/interior_dust.gdshader")
	mote.material = finish
	dust.mesh = mote
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,0.15,0.75,1.0])
	fade.colors = PackedColorArray([Color(1,1,1,0),Color.WHITE,Color(1,1,1,0.7),Color(1,1,1,0)])
	dust.color_ramp = fade
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)

