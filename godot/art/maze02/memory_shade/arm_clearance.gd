extends SkeletonModifier3D
## Post-animation correction keeps lowered arms clear of the original wide cloak.
## It changes only the two existing upper-arm poses, preserving the source rig.

@export_range(0.0, 45.0) var minimum_spread_degrees: float = 12.0
@export_range(0.0, 40.0) var maximum_correction_degrees: float = 6.0
@export var hand_side_clearance: float = 0.10
var last_angles: Vector2 = Vector2.ZERO

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var left := skeleton.find_bone("L_Upperarm")
	var right := skeleton.find_bone("R_Upperarm")
	var chest := skeleton.find_bone("Spine02")
	if left < 0 or right < 0 or chest < 0:
		return
	var side_axis := (skeleton.get_bone_global_pose(right).origin - skeleton.get_bone_global_pose(left).origin).normalized()
	var chest_y := skeleton.get_bone_global_pose(chest).origin.y
	var chest_position := skeleton.get_bone_global_pose(chest).origin
	last_angles = Vector2.ZERO
	for side in range(2):
		var prefix := "L_" if side == 0 else "R_"
		var upper := left if side == 0 else right
		var elbow := skeleton.find_bone(prefix + "Forearm")
		var hand := skeleton.find_bone(prefix + "Hand")
		var shoulder_pose := skeleton.get_bone_global_pose(upper)
		var hand_position := skeleton.get_bone_global_pose(hand).origin
		# Raised hands retain the source sob/face gesture.
		var lowered := 1.0 - smoothstep(chest_y - 0.04, chest_y + 0.035, hand_position.y)
		var outward := side_axis * (-1.0 if side == 0 else 1.0)
		var direction := (skeleton.get_bone_global_pose(elbow).origin - shoulder_pose.origin).normalized()
		var lateral := clampf(direction.dot(outward), -0.98, 0.98)
		var minimum := sin(deg_to_rad(minimum_spread_degrees))
		var hand_lateral := (hand_position - chest_position).dot(outward)
		if (lateral >= minimum and hand_lateral >= hand_side_clearance) or lowered < 0.001:
			continue
		var axis := direction.cross(outward).normalized()
		var low := 0.0
		var high := deg_to_rad(maximum_correction_degrees)
		for step in range(8):
			var middle := (low + high) * 0.5
			var trial := Quaternion(axis, middle)
			var trial_hand := shoulder_pose.origin + trial * (hand_position - shoulder_pose.origin)
			if (trial * direction).dot(outward) >= minimum and (trial_hand - chest_position).dot(outward) >= hand_side_clearance:
				high = middle
			else:
				low = middle
		var angle := high * lowered
		var correction := Quaternion(axis, angle)
		shoulder_pose.basis = Basis(correction) * shoulder_pose.basis
		skeleton.set_bone_global_pose(upper, shoulder_pose)
		last_angles[side] = rad_to_deg(angle)
