extends Node3D
## World-space wind lanes: two small draw batches, not a screen-space speed overlay.
const Settings := preload("res://modules/maze03_final/wind_settings.tres")
var streak_count := 0
var local_material: ShaderMaterial
var high_material: ShaderMaterial
var elapsed := 0.0

func _ready() -> void:
	name = "HighAltitudeWind"
	local_material = _lanes("AcrossMaze",20,false)
	high_material = _lanes("HighAirCurrent",24,true)

func _lanes(id: String, count: int, high: bool) -> ShaderMaterial:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 30529 if high else 30528
	for i in count:
		var point := Vector3(rng.randf_range(-37,84),rng.randf_range(5.0,15.0),rng.randf_range(-35,85)) if high else Vector3(rng.randf_range(2,46),rng.randf_range(0.9,2.8),rng.randf_range(2,46))
		var phase := rng.randf()
		var velocity := rng.randf_range(0.84,1.16)
		for uv: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
			st.set_uv(uv)
			st.set_uv2(Vector2(phase,velocity))
			st.add_vertex(point)
		streak_count += 1
	var mesh := MeshInstance3D.new()
	mesh.name = id
	mesh.mesh = st.commit()
	mesh.custom_aabb = AABB(Vector3(-105,-2,-105),Vector3(260,70,260))
	mesh.layers = 4
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://modules/maze03_final/wind_flow.gdshader")
	paint.set_shader_parameter("wind_direction",Settings.direction)
	paint.set_shader_parameter("wind_color",Vector3(0.93,0.97,1.0) if high else Vector3(0.82,0.87,0.90))
	paint.set_shader_parameter("speed",Settings.high_speed if high else Settings.local_speed)
	paint.set_shader_parameter("path_length",112.0 if high else 48.0)
	paint.set_shader_parameter("streak_length",13.0 if high else 7.0)
	paint.set_shader_parameter("streak_width",0.075 if high else 0.045)
	paint.set_shader_parameter("visibility",Settings.visibility*(1.12 if high else 0.90))
	mesh.material_override = paint
	add_child(mesh)
	return paint

func _process(delta: float) -> void:
	elapsed += delta
	var gain := 0.72+Settings.gust_at(elapsed)*0.38
	local_material.set_shader_parameter("flow_gain",gain)
	high_material.set_shader_parameter("flow_gain",gain)
