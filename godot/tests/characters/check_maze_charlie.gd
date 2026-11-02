extends SceneTree
## End-to-end controller, animation and original A/B route checks.

var failures := 0
var held_keys: Array[int] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	if pressed and not held_keys.has(code):
		held_keys.append(code)
	elif not pressed:
		held_keys.erase(code)

func release_keys() -> void:
	for code: int in held_keys.duplicate():
		key(code, false)

func ticks(count: int) -> void:
	for tick in count:
		await physics_frame
		# Native window focus changes may release keys between frames. Reapply
		# this harness's held inputs immediately before the controller step.
		for code: int in held_keys:
			var event := InputEventKey.new()
			event.physical_keycode = code
			event.pressed = true
			Input.parse_input_event(event)
		await process_frame

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../.verification/charlie/maze_integration")
	DirAccess.make_dir_recursive_absolute(folder)
	var image := root.get_texture().get_image()
	check(image.save_png(folder.path_join(label + ".png")) == OK, "Capture " + label)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	Input.use_accumulated_input = false
	root.size = Vector2i(1280, 900)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.show_scene("maze")
	await ticks(10)
	var scene = game.active_scene
	var actor = scene.get_node("%Player")
	var visual = actor.visual
	var animation: AnimationPlayer = visual.animation_player
	check(visual.scene_file_path == "res://scenes/characters/charlie_visual.tscn", "Maze must instance the Charlie module")
	check(visual.find_children("*", "Skeleton3D", true, false).size() == 1, "Maze actor must have a skeleton")
	check(animation.current_animation == "Idle", "Spawn must be Idle")
	check(actor.get_child_count() == 2, "Controller must contain only collider and Charlie visual")
	var collider := actor.get_child(0) as CollisionShape3D
	check(collider.shape is CapsuleShape3D and is_equal_approx(collider.shape.radius, 0.3) and is_equal_approx(collider.shape.height, 1.6), "Existing collision capsule must be preserved")
	await capture("idle")

	# A fixed world-aligned camera makes physical W/A/S/D directions predictable.
	var input_camera := Camera3D.new()
	actor.get_parent().add_child(input_camera)
	actor.movement_camera = input_camera
	var start: Vector3 = actor.position
	key(KEY_W, true)
	await ticks(30)
	var walk_distance: float = start.z - actor.position.z
	check(walk_distance > 0.7 and walk_distance < 0.9, "W must walk at 1.6 m/s")
	check(animation.current_animation == "Walk", "Walking must play Walk")
	await capture("walk")
	key(KEY_SHIFT, true)
	start = actor.position
	await ticks(30)
	check(start.z - actor.position.z > walk_distance * 1.5, "Shift must increase movement speed")
	check(animation.current_animation == "Run", "Shift + movement must play Run")
	await capture("run")
	release_keys()
	await ticks(15)
	check(animation.current_animation == "Idle", "Releasing movement must restore Idle")

	actor.reset_player()
	await ticks(3)
	key(KEY_D, true)
	key(KEY_SHIFT, true)
	await ticks(55)
	check(actor.position.x < 2.0, "Running into entry east wall must not pass through it")
	check(animation.current_animation == "Idle", "Blocked actor must idle even while run keys are held")
	check(absf(wrapf(visual.rotation.y + PI / 2, -PI, PI)) < 0.05, "Charlie -Z must turn to face east")
	release_keys()
	scene.reset_walk()
	await ticks(3)
	check(actor.position.distance_to(actor.spawn_point) < 0.1 and animation.current_animation == "Idle", "Restart must restore position and Idle")
	scene.show_top_view()
	var before: Vector3 = actor.position
	key(KEY_W, true)
	await ticks(15)
	check(actor.position.distance_to(before) < 0.01 and not actor.visible, "Top view must hide and disable the actor")
	release_keys()
	scene.set_walk_mode(true)
	await ticks(2)
	check(actor.visible and animation.current_animation == "Idle", "Returning to walk mode must restore Charlie")

	# Drive the real controller through every original route segment with wall
	# collision enabled; do not teleport between route cells or bypass physics.
	var maze: Dictionary = scene.maze_data
	var route_ids: Array[String] = ["A", "B"]
	if OS.get_cmdline_user_args().has("--smoke-only"):
		route_ids.clear()
	for route_id: String in route_ids:
		actor.reset_player()
		await ticks(3)
		key(KEY_SHIFT, true)
		var route: Array = maze.routes[route_id].cellPath
		var completed := 0
		for index in range(1, route.size()):
			var target: Array = route[index]
			var size := float(maze.grid.cellSizeWorld)
			var goal := Vector2((target[1] + 0.5) * size, (target[0] + 0.5) * size)
			var code := 0
			var reached := false
			for frame in 120:
				var offset := goal - Vector2(actor.position.x, actor.position.z)
				# Correct small lateral turn errors using the same real inputs.
				var next_code := (KEY_D if offset.x > 0 else KEY_A) if absf(offset.x) > absf(offset.y) else (KEY_S if offset.y > 0 else KEY_W)
				if next_code != code:
					if code != 0:
						key(code, false)
					code = next_code
					key(code, true)
				await ticks(1)
				if Vector2(actor.position.x, actor.position.z).distance_to(goal) < 0.04:
					reached = true
					break
			key(code, false)
			if not reached:
				check(false, "Route %s blocked at cell %s (step %d)" % [route_id, target, index])
				break
			completed += 1
		release_keys()
		await ticks(5)
		check(completed == int(maze.routes[route_id].moveCount), "Complete original route " + route_id)
		print("CHARLIE ROUTE ", route_id, ": ", completed, "/", maze.routes[route_id].moveCount, " steps")

	check(FileAccess.get_sha256("res://data/maze_01.json") == "f186db1678d73b5f90821290d09a31abc8516bf1b9aa4a7e10a65f4ea0f87bfb", "Original maze bytes must remain unchanged")
	scene.reset_walk()
	actor.movement_camera = scene.get_node("%FollowRig").camera
	await ticks(10)
	await capture("maze_ready")
	release_keys()
	game.queue_free()
	await process_frame
	print("CHARLIE MAZE CHECK: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
