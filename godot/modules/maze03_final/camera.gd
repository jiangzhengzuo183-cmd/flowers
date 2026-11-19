extends "res://scripts/levels/greybox_camera.gd"
## Remove the previous addition before the normal camera update: no cumulative FOV drift.
var speed_fov := 0.0
var earthquake_strength := 0.0
var earthquake_impulse := 0.0
@export_range(0.0,10.0,0.5) var impact_roll_degrees := 5.5
var shake_clock := 0.0
func _update_pose() -> void:
	if not is_instance_valid(camera):
		return
	camera.fov -= speed_fov
	super()
	var accelerating: bool = is_instance_valid(target) and target.get("boost_remaining")!=null and target.boost_remaining>0 and Vector2(target.velocity.x,target.velocity.z).length()>1.0
	speed_fov = lerpf(speed_fov,3.5 if accelerating else 0.0,1.0-exp(-5*minf(get_process_delta_time(),0.05)))

	camera.fov += speed_fov
	shake_clock += minf(get_process_delta_time(),0.05)
	camera.h_offset = sin(shake_clock*39.0)*0.026*earthquake_strength+earthquake_impulse*0.045
	camera.v_offset = (sin(shake_clock*47.0)+sin(shake_clock*21.0)*0.35)*0.020*earthquake_strength-absf(earthquake_impulse)*0.035
	camera.rotate_object_local(Vector3.FORWARD,sin(shake_clock*33.0)*0.004*earthquake_strength+deg_to_rad(impact_roll_degrees)*earthquake_impulse)
	camera.rotate_object_local(Vector3.RIGHT,absf(earthquake_impulse)*deg_to_rad(1.2))

