extends Node3D
const M := preload("res://modules/maze03_final/scenery_mesh.gd")
var mist_count := 0
var cloud_count := 0
var sky_track_count := 0

func _ready() -> void:
	name = "TrialAtmosphere"
	_cloud_sea()
	_ground_air()
	add_child(preload("res://modules/maze03_final/day_moon.gd").new())
	add_child(preload("res://modules/maze03_final/sky_comet.gd").new())
	add_child(preload("res://modules/maze03_final/wind.gd").new())

func _cloud(id: String, point: Vector3, size: Vector2, opacity: float, phase: float, bank: bool, outside: bool) -> MeshInstance3D:
	var cloud := MeshInstance3D.new()
	cloud.name = id
	if bank:
		var quad := QuadMesh.new()
		quad.size = size
		cloud.mesh = quad
	else:
		var plane := PlaneMesh.new()
		plane.size = size
		cloud.mesh = plane
	cloud.position = point
	var material := ShaderMaterial.new()
	material.shader = preload("res://modules/maze03_final/clouds.gdshader")
	material.set_shader_parameter("opacity",opacity)
	material.set_shader_parameter("phase",phase)
	material.set_shader_parameter("vertical_bank",bank)
	if outside:
		material.set_shader_parameter("tint",Color("f0f6fc"))
	material.set_shader_parameter("outside_only",outside)
	material.set_shader_parameter("drift",Vector2(0.027,-0.011)*(1.0+phase*0.025))
	cloud.material_override = material
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The reflection pass excludes these broad transparent layers.
	cloud.layers = 4
	add_child(cloud)
	return cloud

func _cloud_sea() -> void:
	# Same two broad distances as the successful first maze, with a cold-white tint.
	for spec: Array in [[-19.0,0.037,0.48],[-9.5,0.053,0.58]]:
		var cloud := MeshInstance3D.new()
		cloud.name = "ReferenceCloudSea"
		var plane := PlaneMesh.new()
		plane.size = Vector2(440,440)
		cloud.mesh = plane
		cloud.position = Vector3(24,spec[0],22.8)
		cloud.layers = 4
		var paint := ShaderMaterial.new()
		paint.shader = preload("res://art/environments/cloud_sea.gdshader")
		paint.set_shader_parameter("pattern_scale",spec[1])
		paint.set_shader_parameter("opacity",spec[2])
		paint.set_shader_parameter("cloud_tint",Color("edf3fa"))
		paint.set_shader_parameter("drift",Vector2(0.018,-0.0075))
		cloud.material_override = paint
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cloud)
		cloud_count += 1
	for i in 8:
		var angle := TAU*float(i)/8.0+0.18
		var radius: float = 52.0+(i%3)*8
		var point := Vector3(24+cos(angle)*radius,-5.9+(i%3)*1.3,22.8+sin(angle)*radius)
		var cloud := _cloud("ExteriorCloudBank"+str(i),point,Vector2(52,12.5),0.47,float(i)*1.7,true,true)
		cloud.rotation.y = atan2(24-point.x,22.8-point.z)
		cloud_count += 1
func _sky_tracks() -> void:
	for layer in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count := 128
		var basis := Basis(Vector3.UP,0.42)*Basis(Vector3.RIGHT,1.10)
		var center := Vector3(24,49+layer*16,22.8)
		for i in count:
			var u := float(i)/count
			var v := float(i+1)/count
			var vertices := PackedVector3Array()
			for t: float in [u,v]:
				var angle: float = -2.9+t*4.8+layer*0.5
				for offset: float in [-1.05,1.05]:
					vertices.append(center+basis*Vector3(cos(angle)*(158+layer*35+offset),sin(angle)*(104+layer*25+offset),0))
			for index: int in [0,2,1,1,2,3]:
				st.set_uv(Vector2(u if index<2 else v,0 if index%2==0 else 1))
				st.add_vertex(vertices[index])
		var material := ShaderMaterial.new()
		material.shader = preload("res://modules/maze03_final/sky_tracks.gdshader")
		material.set_shader_parameter("phase",float(layer)*2.7)
		M.finish(self,"DistantEnergyTrajectory"+str(layer),st,material)
		sky_track_count += 1

func _ground_air() -> void:
	var patches := [Vector3(8,1.25,10),Vector3(8,1.7,26),Vector3(14,0.85,38),Vector3(27,1.6,40),Vector3(37,1.3,30),Vector3(39,1.8,15),Vector3(28,1.0,7),Vector3(17,1.7,15),Vector3(31,2.1,24)]
	for i in patches.size():
		var cloud := _cloud("DriftingMist"+str(i),patches[i],Vector2(19.0,12.0),0.135,1.4*i,false,false)
		cloud.rotation.y = -0.45
		(cloud.material_override as ShaderMaterial).set_shader_parameter("pattern_scale",0.11)
		(cloud.material_override as ShaderMaterial).set_shader_parameter("drift",Vector2(0.045,-0.019))
		(cloud.material_override as ShaderMaterial).set_shader_parameter("tint",Color("dae7eb"))
		mist_count += 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.86,0.93,0.98,0.36)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for point: Vector3 in [Vector3(12,2,29),Vector3(35,2,12)]:
		var dust := CPUParticles3D.new()
		dust.name = "SlowWindDust"
		dust.amount = 18
		dust.lifetime = 7
		dust.preprocess = 5
		dust.position = point
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.emission_box_extents = Vector3(7,1.6,6)
		dust.direction = Vector3(1,0,-1)
		dust.spread = 8
		dust.gravity = Vector3.ZERO
		dust.initial_velocity_min = 0.70
		dust.initial_velocity_max = 1.30
		var mesh := SphereMesh.new()
		mesh.radius = 0.012
		mesh.height = 0.023
		mesh.radial_segments = 4
		mesh.rings = 2
		mesh.material = material
		dust.mesh = mesh
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0,0.3,1.0])
		fade.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.45),Color(1,1,1,0)])
		dust.color_ramp = fade
		dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dust)


