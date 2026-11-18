extends "res://scripts/levels/greybox_camera.gd"
const SanctuaryLayout:=preload("res://scripts/maze03/layout.gd")
func _inside_room() -> bool:
	if not is_instance_valid(target):
		return false
	var p: Vector3=target.position-SanctuaryLayout.CENTER
	return absf(p.x)<4.0 and absf(p.z)<4.0
