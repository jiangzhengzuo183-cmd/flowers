extends Node3D
## A broad white-blue axis in the ring and one regional warm fill on the maze.
var beam_count := 0
var regional_light: SpotLight3D
func _ready() -> void:
	name = "RingAxisLight"
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://modules/maze03_final/ring_axis.gdshader")
	for i in 3:
		var mesh := MeshInstance3D.new()
		mesh.name = "WhiteBlueColumn"+str(i)
		var quad := QuadMesh.new()
		quad.size = Vector2(22,126)
		mesh.mesh = quad
		mesh.position.y = 63.0
		mesh.rotation.y = i*PI/3.0
		mesh.material_override = paint
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = 16
		add_child(mesh)
		beam_count += 1
	_build_ascent()
	# A bounded fill near the maze receives the same northeast-to-southwest direction.
	# No global exposure/light changes; it illuminates a limited part of actual geometry.
	regional_light = SpotLight3D.new()
	regional_light.name = "NortheastWarmSkyCast"
	regional_light.light_color = Color("ffd09c")
	regional_light.light_energy = 3.2
	regional_light.light_specular = 0.18
	regional_light.spot_range = 33.0
	regional_light.spot_angle = 43.0
	regional_light.spot_attenuation = 0.85
	regional_light.shadow_enabled = false
	regional_light.light_cull_mask = 1
	add_child(regional_light)
	regional_light.look_at_from_position(Vector3(45,13,0),Vector3(33,0,14))


func _build_ascent() -> void:
	var particles := CPUParticles3D.new()
	particles.name = "DenseBlueAscent"
	particles.amount = 256
	particles.lifetime = 12.0
	particles.preprocess = 12.0
	particles.position.y = 63.0
	particles.local_coords = true
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(10.5,54.0,10.5)
	particles.direction = Vector3.UP
	particles.spread = 9.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 4.2
	particles.initial_velocity_max = 8.0
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 1.15
	particles.layers = 16
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = 0.30
	mesh.height = 0.60
	mesh.radial_segments = 4
	mesh.rings = 2
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.vertex_color_use_as_albedo = true
	paint.albedo_color = Color("71d6fb")
	paint.emission_enabled = true
	paint.emission = Color("3dbbeb")
	paint.emission_energy_multiplier = 1.2
	mesh.material = paint
	particles.mesh = mesh
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,0.15,0.75,1.0])
	fade.colors = PackedColorArray([Color(0.6,0.9,1,0),Color(0.6,0.9,1,0.82),Color(0.6,0.9,1,0.74),Color(0.6,0.9,1,0)])
	particles.color_ramp = fade
	add_child(particles)

