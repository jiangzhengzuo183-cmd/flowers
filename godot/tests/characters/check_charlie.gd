extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var raw = load("res://assets/characters/charlie/charlie.glb").instantiate()
	var imported_player := raw.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in [&"Idle", &"Walk", &"Run"]:
		check(imported_player.has_animation(clip), "Raw GLB missing clip: " + clip)
		if imported_player.has_animation(clip):
			check(imported_player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, "Raw GLB must loop without wrapper: " + clip)
	check(imported_player.has_animation(&"Jump"), "Raw GLB must include Jump")
	if imported_player.has_animation(&"Jump"):
		check(imported_player.get_animation(&"Jump").loop_mode == Animation.LOOP_NONE, "Jump must be one-shot")
		check(absf(imported_player.get_animation(&"Jump").length - 1.4) < 0.001, "Jump must last 1.4 s")
	raw.free()
	var packed := load("res://scenes/characters/charlie_visual.tscn") as PackedScene
	check(packed != null, "Charlie module must load")
	if packed == null:
		quit(1)
		return
	var visual = packed.instantiate()
	root.add_child(visual)
	await process_frame
	var player: AnimationPlayer = visual.animation_player
	check(player != null, "AnimationPlayer must exist")
	var skeleton: Skeleton3D
	for node in visual.find_children("*", "Skeleton3D", true, false):
		skeleton = node
	check(skeleton != null and skeleton.get_bone_count() == 24, "24-bone skeleton must import")
	if player == null or skeleton == null:
		quit(1)
		return
	for clip in [&"Idle", &"Walk", &"Run"]:
		check(player.has_animation(clip), "Missing clip: " + clip)
		var anim := player.get_animation(clip)
		check(anim.loop_mode == Animation.LOOP_LINEAR, "Clip must loop: " + clip)
		var expected := 3.0 if clip == &"Idle" else (1.0 if clip == &"Walk" else 2.0 / 3.0)
		check(absf(anim.length - expected) < 0.001, "Incorrect duration: " + clip)
		player.play(clip, 0.0)
		player.seek(0, true)
		var first: Array[Transform3D] = []
		for bone in skeleton.get_bone_count():
			first.append(skeleton.get_bone_pose(bone))
		player.seek(anim.length, true)
		for bone in skeleton.get_bone_count():
			check(first[bone].is_equal_approx(skeleton.get_bone_pose(bone)), "Loop discontinuity: " + clip + "/" + skeleton.get_bone_name(bone))
		player.seek(anim.length * 0.25, true)
		var root_bone := skeleton.find_bone("Root")
		check(skeleton.get_bone_pose(root_bone).origin.length() < 0.0001, "Root motion must remain in place")
		if clip != &"Idle":
			var leg := skeleton.find_bone("LeftUpperLeg")
			check(not first[leg].basis.is_equal_approx(skeleton.get_bone_pose(leg).basis), "Leg must animate: " + clip)
	player.play(&"Run", 0.0)
	var max_knee := 0.0
	for frame in 21:
		player.seek(frame / 30.0, true)
		var knee := skeleton.get_bone_pose_rotation(skeleton.find_bone("LeftLowerLeg"))
		max_knee = maxf(max_knee, 2.0 * acos(clampf(absf(knee.w), 0, 1)))
	check(max_knee > deg_to_rad(100), "Run must have a clearly flexed recovery knee")
	visual.set_locomotion(0.0)
	check(player.current_animation == "Idle", "Stationary -> Idle")
	visual.set_locomotion(1.2)
	check(player.current_animation == "Walk", "1.2 m/s -> Walk")
	visual.set_locomotion(2.7)
	check(player.current_animation == "Run", "2.7 m/s -> Run")
	visual.play_jump()
	check(player.current_animation == "Jump", "Jump helper must play one-shot")
	visual.set_locomotion(1.2)
	check(player.current_animation == "Jump", "Locomotion must not interrupt jump")
	# Measure the authored pose without a still-running transition from Run.
	player.stop()
	player.play(&"Jump", 0.0)
	player.seek(0.6, true)
	var root_bone := skeleton.find_bone("Root")
	var apex := skeleton.get_bone_pose_position(root_bone)
	# Godot's default curve optimization may remove the exact apex sample.
	check(absf(apex.y - 0.43) < 0.01 and absf(apex.x) < 0.001 and absf(apex.z) < 0.001, "Jump apex must be about 43 cm with no horizontal root motion")
	player.seek(0.9, true)
	check(skeleton.get_bone_pose_position(root_bone).length() < 0.001, "Jump root must return to ground at contact")
	player.advance(0.6)
	check(player.current_animation == "Walk", "Finished jump must restore queued locomotion")
	visual.play_jump(false)
	player.stop()
	player.play(&"JumpInPlace", 0.0)
	player.seek(0.6, true)
	check(player.current_animation == "JumpInPlace", "Physics-driven jump must use in-place variant")
	check(skeleton.get_bone_pose_position(root_bone).length() < 0.001, "In-place jump must not double the controller height")
	player.advance(1.0)
	var preview := load("res://scenes/characters/charlie_preview.tscn") as PackedScene
	check(preview != null, "Preview scene must load")
	if preview:
		var instance := preview.instantiate()
		root.add_child(instance)
		await process_frame
		instance.queue_free()
	visual.queue_free()
	await process_frame
	print("CHARLIE_CHECK: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
