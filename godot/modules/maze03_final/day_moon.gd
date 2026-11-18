extends MeshInstance3D
## A distant, softly lit lunar sphere; no sky or global-light replacement.
const DIRECTION := Vector3(-0.52,0.43,-0.74)
func _ready() -> void:
	name = "DistantDaytimeHalfMoon"
	var sphere := SphereMesh.new()
	sphere.radius = 5.7
	sphere.height = 11.4
	sphere.radial_segments = 64
	sphere.rings = 32
	mesh = sphere
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://modules/maze03_final/day_moon.gdshader")
	var sideways := DIRECTION.cross(Vector3.UP).normalized()
	paint.set_shader_parameter("moon_light",sideways-DIRECTION.normalized()*0.10)
	material_override = paint
	layers = 16
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	process_priority = 90
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera!=null:
		global_position = camera.global_position+DIRECTION.normalized()*420.0

