extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func capture(scene: Control, label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../.verification/charlie/look_refinement")
	DirAccess.make_dir_recursive_absolute(folder)
	var viewport: SubViewport = scene.get_node("%ViewportContainer").get_child(0)
	check(viewport.get_texture().get_image().save_png(folder.path_join(label + ".png")) == OK, "Save screenshot " + label)

func run_checks() -> void:
	root.size = Vector2i(1280, 900)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.show_scene("maze")
	await process_frame
	var scene = game.active_scene
	var actor = scene.get_node("%Player")
	var follow = scene.get_node("%FollowRig")
	var visual = actor.visual
	var player: AnimationPlayer = visual.animation_player
	check(visual.get_node("Model").scene_file_path.ends_with("charlie_refined.glb"), "Use refined model variant")
	check(is_equal_approx(follow.distance, 2.8) and is_equal_approx(follow.pitch, 0.68), "Default close third-person camera")
	check(is_equal_approx(follow.camera.fov, 48.0), "Close view lens")
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	follow.handle_input(wheel)
	check(follow.distance > 2.8, "Zoom remains adjustable")
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(20, 10)
	follow.handle_input(drag)
	check(not is_zero_approx(follow.yaw) and follow.pitch != 0.68, "View direction remains adjustable")
	follow.reset_view()
	check(is_zero_approx(follow.yaw) and is_equal_approx(follow.distance, 2.8), "Reset restores new view")
	var environment: Environment = scene.get_node("%WorldEnvironment").environment
	check(environment.tonemap_mode == Environment.TONE_MAPPER_AGX, "Use AgX highlight roll-off")
	check(scene.get_node("%GeneratedMaze").get_parent().get_node("SoftFill") is DirectionalLight3D, "Soft fill light must exist")
	for i in 10:
		await process_frame
	await capture(scene, "default_back")

	# Compare imported curves, including clips not changed by the arm revision.
	var original = load("res://assets/characters/charlie/charlie.glb").instantiate()
	var old_player := original.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in [&"Idle", &"Walk", &"Jump", &"Run"]:
		var before := old_player.get_animation(clip)
		var after := player.get_animation(clip)
		for track in before.get_track_count():
			var track_path := before.track_get_path(track)
			var name := String(track_path).get_slice(":", 1)
			if clip == &"Run" and (name.ends_with("UpperArm") or name.ends_with("LowerArm") or name.ends_with("Hand")):
				continue
			var target_track := after.find_track(track_path, before.track_get_type(track))
			check(target_track >= 0, "Preserve track " + String(track_path))
			if target_track < 0:
				continue
			for sample in 5:
				var time := before.length * sample / 4.0
				match before.track_get_type(track):
					Animation.TYPE_ROTATION_3D:
						check(before.rotation_track_interpolate(track, time).is_equal_approx(after.rotation_track_interpolate(target_track, time)), "Preserve rotation " + String(track_path))
					Animation.TYPE_POSITION_3D:
						check(before.position_track_interpolate(track, time).is_equal_approx(after.position_track_interpolate(target_track, time)), "Preserve position " + String(track_path))
	actor.set_physics_process(false)
	var skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
	# Hide wall display only in the diagnostic pose images, so the side view
	# can show the arms and feet; normal gameplay/default capture keeps walls.
	scene.get_node("%GeneratedMaze").get_node("VerticalWalls").visible = false
	scene.get_node("%GeneratedMaze").get_node("HorizontalWalls").visible = false
	actor.get_parent().add_child(original)
	original.visible = false
	var old_skeleton := original.find_child("Skeleton3D", true, false) as Skeleton3D
	var old_hand_span := 0.0
	var old_hand_height := 0.0
	var new_hand_height := 0.0
	var max_hand_span := 0.0
	for view in ["front", "side"]:
		follow.yaw = PI if view == "front" else PI / 2.0
		follow.pitch = 0.35
		follow.distance = 2.8
		for sample in 4:
			player.play(&"Run", 0.0)
			player.seek(player.get_animation(&"Run").length * sample / 4.0, true)
			player.pause()
			skeleton.force_update_all_bone_transforms()
			old_player.play(&"Run", 0.0)
			old_player.seek(old_player.get_animation(&"Run").length * sample / 4.0, true)
			old_player.pause()
			old_skeleton.force_update_all_bone_transforms()
			var left := skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin
			var right := skeleton.get_bone_global_pose(skeleton.find_bone("RightHand")).origin
			var old_left := old_skeleton.get_bone_global_pose(old_skeleton.find_bone("LeftHand")).origin
			var old_right := old_skeleton.get_bone_global_pose(old_skeleton.find_bone("RightHand")).origin
			old_hand_span = maxf(old_hand_span, absf(old_left.x - old_right.x))
			old_hand_height = maxf(old_hand_height, maxf(old_left.y, old_right.y))
			new_hand_height = maxf(new_hand_height, maxf(left.y, right.y))
			max_hand_span = maxf(max_hand_span, absf(left.x - right.x))
			for frame in 3:
				await process_frame
			await capture(scene, "run_%s_%d" % [view, sample])
	check(max_hand_span < 0.7, "Run arms should stay compact instead of winging out")
	check(max_hand_span < old_hand_span, "Run hand spread must be smaller than original")
	check(new_hand_height < old_hand_height, "Run hands should no longer be lifted as high")
	print("RUN HAND SPAN MAX: ", max_hand_span, " (original ", old_hand_span, "); HEIGHT MAX: ", new_hand_height, " (original ", old_hand_height, ")")
	game.queue_free()
	await process_frame
	print("LOOK REFINEMENT CHECK: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
