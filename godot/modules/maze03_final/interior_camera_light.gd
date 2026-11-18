extends Node
## Camera-local ambient reduction. Surface colors, outdoor light and exposure stay unchanged.
var camera: Camera3D
var indoor_environment: Environment
var original_override: Environment
var blend := 0.0
func _process(delta: float) -> void:
	var current := get_viewport().get_camera_3d()
	if current==null:
		return
	if camera!=current:
		_restore()
		camera = current
		original_override = camera.environment
		var world: World3D = get_parent().get_world_3d()
		var base := world.environment
		if base==null:
			return
		indoor_environment = base.duplicate()
		blend = 0.0
	var point := camera.global_position-Vector3(24,0,22.8)
	var half_span := 3.5-clampf(point.y/10.3,0,1)*2.73
	var inside := point.y>0.1 and point.y<9.5 and absf(point.x)<half_span-0.05 and absf(point.z)<half_span-0.05
	blend = move_toward(blend,1.0 if inside else 0.0,delta*3.0)
	if blend>0.001 and indoor_environment!=null:
		indoor_environment.ambient_light_energy = lerpf(0.38,0.24,blend)
		camera.environment = indoor_environment
	else:
		camera.environment = original_override
func _restore() -> void:
	if is_instance_valid(camera):
		camera.environment = original_override
func _exit_tree() -> void:
	_restore()

