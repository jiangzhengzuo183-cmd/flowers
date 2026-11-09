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
	check(skeleton != null and skeleton.get_bone_count() == 41, "The re-rigged 41-bone skeleton must import")
	if player == null or skeleton == null:
		quit(1)
		return
	var hip := skeleton.find_bone("Hip")
	var hip_rest := skeleton.get_bone_global_rest(hip).origin
	for clip in [&"Idle", &"Walk", &"Run", &"Jump", &"JumpInPlace", &"Dance"]:
		check(player.has_animation(clip), "Missing clip: " + clip)
		var anim := player.get_animation(clip)
		var expected_loop := Animation.LOOP_LINEAR if clip in [&"Idle", &"Walk", &"Run"] else Animation.LOOP_NONE
		check(anim.loop_mode == expected_loop, "Correct loop mode: " + clip)
		player.play(clip, 0.0)
		player.seek(0, true)
		var leg := skeleton.find_bone("L_Thigh")
		var start_leg := skeleton.get_bone_pose_rotation(leg)
		for sample in 9:
			player.seek(anim.length * sample / 8.0, true)
			var offset := skeleton.get_bone_global_pose(hip).origin - hip_rest
			check(Vector2(offset.x, offset.z).length() < 0.001, "Authored travel stays within the character body: " + clip)
			if clip == &"JumpInPlace":
				check(offset.y < 0.001, "Physics jump has no baked lift")
		player.seek(anim.length * 0.25, true)
		if clip in [&"Walk", &"Run"]:
			check(not start_leg.is_equal_approx(skeleton.get_bone_pose_rotation(leg)), "Leg must animate: " + clip)
	for clip in [&"cry_001", &"heart_pose_001", &"defeat_03_001"]:
		check(player.has_animation(clip), "Additional authored animation remains available: " + clip)
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
	check(player.has_section(), "Preview plays one hop from the authored sequence")
	player.advance(0.6)
	check(player.current_animation == "Walk", "Finished jump must restore queued locomotion")
	visual.play_jump(false)
	check(player.current_animation == "JumpInPlace", "Physics-driven jump must use in-place variant")
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
