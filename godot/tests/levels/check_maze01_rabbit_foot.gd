extends "res://tests/levels/check_maze_01_greybox.gd"

const Level := preload("res://scenes/levels/maze_01_greybox.tscn")
const Items := preload("res://modules/maze_items/maze_item_controller.gd")

func capture(id: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../.verification/maze01-rabbit-foot")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(id + ".png")) == OK, "Capture " + id)

func capture_from(id: String, eye: Vector3, target: Vector3) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	var camera := Camera3D.new()
	actor.get_parent().add_child(camera)
	camera.fov = 52.0
	camera.look_at_from_position(eye, target)
	camera.make_current()
	await ticks(3)
	await capture(id)
	camera.free()
	scene.get_node("%FollowRig").camera.make_current()

func run() -> void:
	Input.use_accumulated_input = false
	root.size = Vector2i(1440, 960)
	scene = Level.instantiate()
	root.add_child(scene)
	actor = scene.get_node("%Player")
	generator = scene.get_node("%GeneratedMaze")
	var world := actor.get_parent()
	var input_camera := Camera3D.new()
	world.add_child(input_camera)
	actor.movement_camera = input_camera
	var items := scene.get_node("MazeItems") as Items
	var inventory := items.inventory
	var use := inventory.get_node("UseItem") as Button
	await ticks(70)
	check(items._routes.ready and use.disabled, "The route graph is ready and the empty slot cannot be used")
	var pickup := items._pickup
	var old_y := pickup._display.position.y
	var old_rotation := pickup._display.rotation.y
	check(pickup is Area3D and pickup.collision_layer == 0
		and pickup.find_children("*", "PhysicsBody3D", true, false).is_empty(), "Pickup is a non-blocking sensor")
	scene.inspect_location(24)
	check(actor.position.distance_to(Items.PICKUP_PREVIEW) < 0.08, "The southeast inspection point is outside pickup range")
	actor.movement_camera = input_camera
	var follow = scene.get_node("%FollowRig")
	await ticks(12)
	await walk_to(Items.PICKUP_POINT - Vector3(1.26,0,0), "Approach the southeast charm", false)
	await ticks(12)
	check(not pickup.claimed and pickup._near > 0.5 and pickup._pool.transparency < 0.24,
		"Proximity raises the pickup glow before collection")
	check(absf(old_y - pickup._display.position.y) > 0.006 and absf(old_rotation - pickup._display.rotation.y) > 0.4,
		"The supplied charm bobs and turns")
	await capture_from("01_charm_in_the_maze", Items.PICKUP_POINT + Vector3(-1.19,1.60,-0.72), Items.PICKUP_POINT + Vector3.UP*0.76)
	key(KEY_D, true)
	await ticks(19)
	key(KEY_D, false)
	check(pickup.claimed and inventory.quantity(Items.RABBIT) == 1 and not use.disabled,
		"Walking into the sensor collects exactly one charm and enables use")
	await ticks(4)
	var hands := actor.global_position + Vector3.UP * 0.99
	check(pickup._display.scale.x < 0.96 and pickup._display.global_position.distance_to(hands) < 0.85,
		"The collected charm pulls toward Charlie and shrinks")
	check(scene.sound.get_node("PickupCue").stream.resource_path.ends_with("rabbit_pickup.wav"),
		"Collection plays the pickup sound through the scene audio")
	check(inventory.get_node("ItemNotice").text.contains("获得") and not is_instance_valid(items._guide),
		"Pickup only grants the item and shows its notification")
	await capture("02_collected")
	await ticks(30)
	check(not is_instance_valid(pickup) and inventory.quantity(Items.RABBIT) == 1, "Pickup cannot award a second item")

	use.pressed.emit()
	await ticks(3)
	var blocked_exit: PackedVector3Array = items._routes.path_to_nearest(actor.position, items._destinations)
	check(blocked_exit.is_empty() and inventory.quantity(Items.RABBIT) == 0 and is_instance_valid(items._guide),
		"When the exit is blocked, the charm gives a short hint to an accessible required item or gate")
	await walk_hint(items, "Follow the early item hint")
	await ticks(48)
	check(not is_instance_valid(items._guide), "The early hint ends at its local destination")
	scene.reset_level()
	await ticks(5)
	actor.position = Items.PICKUP_POINT + Vector3.UP * 0.04
	await ticks(6)
	for id: String in ["D1", "D3"]:
		generator.gates[id].set_open_state(true)
	generator.gates.D4.open_gate()
	await ticks(5)
	use.pressed.emit()
	await ticks(3)
	check(generator.gates.D4.is_open and not generator.gates.D4.leaf.get_node("GateCollision").disabled
		and inventory.quantity(Items.RABBIT) == 1, "A gate that is visually opening remains blocked")
	await ticks(ceili((generator.gates.D4.opening_lead_time + generator.gates.D4.descent_duration) * 60) + 6)
	check_navigation(items)

	use.pressed.emit()
	use.pressed.emit()
	await ticks(95)
	var guide := items._guide
	check(inventory.quantity(Items.RABBIT) == 0 and is_instance_valid(guide) and use.disabled,
		"One active use creates one guide and consumes one item")
	check(guide._halo.mesh.size.x >= 1.0, "The blue halo is large enough to read at a turn")
	var short_path: PackedVector3Array = items._routes.path_to_nearest(actor.position, PackedVector3Array([items._stop_point]))
	var hint_distance := items._length(short_path)
	check(short_path.size() > 2 and hint_distance >= 12.0 and hint_distance <= 15.0
		and items._stop_point.distance_to(Layout.cell_point([0,18])) > 12.0,
		"The guide ends after %.2f m of walkable route, well before the exit" % hint_distance)
	var stopped := guide.position
	await ticks(55)
	check(guide.position.distance_to(stopped) < 0.10 and guide.position.distance_to(actor.position) < 2.8,
		"The guide waits ahead of a stationary player")
	follow.yaw = PI / 2.0
	await ticks(12)
	await capture("03_blue_wisp")
	await walk_to(Vector3(36.25,0,39.90), "Follow the guide west", false)
	await walk_to(Vector3(35.35,0,40.05), "Follow the southeast guide into the turn", false)
	await ticks(35)
	check(guide.position.z > stopped.z + 0.9 and guide.position.distance_to(actor.position) < 3.1,
		"The moving guide turns and stays near the player")
	await capture_from("04_around_the_corner", Vector3(34.35,1.78,39.45), guide.position + Vector3.UP*0.62)
	await walk_to(Vector3(36.25,0,39.9), "Change direction while guiding", false)
	await walk_to(Items.PICKUP_POINT - Vector3(0.55,0,-0.30), "Return to the earlier passage", false)
	await ticks(85)
	check(guide.position.distance_to(actor.position) < 3.0, "Changing direction replans the guide near Charlie")
	await walk_hint(items, "Follow the short hint")
	check(not scene.completed and (not is_instance_valid(guide) or guide.fading),
		"The guide dissolves at the short hint endpoint without finishing the level")
	await ticks(50)
	check(not is_instance_valid(guide), "The light and particles are removed after dissolving")

	scene.reset_level()
	await ticks(5)
	check(is_instance_valid(items._pickup) and inventory.quantity(Items.RABBIT) == 0, "Full restart resets inventory and pickup")
	actor.position = Items.PICKUP_POINT + Vector3.UP * 0.04
	for id: String in ["D1", "D3", "D4"]:
		generator.gates[id].set_open_state(true)
	await ticks(6)
	use.pressed.emit()
	await ticks(3)
	check(is_instance_valid(items._guide) and is_equal_approx(items._duration, scene.rabbit_guide_seconds),
		"Guide lifetime uses the exposed level setting")
	items._remaining = 0.06
	await ticks(7)
	check(items._guide.fading, "The duration ending triggers the same dissolve")
	await ticks(49)
	check(not is_instance_valid(items._guide), "The timed guide cleans itself up")
	release()
	scene.queue_free()
	await process_frame
	print("MAZE 01 LUCKY RABBIT FOOT: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)

func walk_hint(items: Items, label: String) -> void:
	var remaining: PackedVector3Array = items._routes.path_to_nearest(actor.position, PackedVector3Array([items._stop_point]))
	for point: Vector3 in remaining.slice(1):
		if not await walk_to(point, label, false):
			break

func check_navigation(items: Items) -> void:
	var routes = items._routes
	var path: PackedVector3Array = routes.path_to_nearest(actor.position, items._destinations)
	var walkable := path.size() > 20
	for i in range(1, path.size()):
		walkable = walkable and routes.can_step(path[i-1], path[i])
	check(walkable and path[-1].is_equal_approx(Layout.cell_point([0,18])), "The full route leads to the exit without crossing solid collision")
	var upper: PackedVector3Array = routes.path_to_nearest(Vector3(39.6,2.6,18.0),items._destinations)
	var lower: PackedVector3Array = routes.path_to_nearest(Vector3(39.6,0.0,15.6),items._destinations)
	check(upper.size() > 5 and upper[3].y > 2.5 and lower.size() > 5 and lower[3].y < 0.2,
		"The upper deck and ground underpass remain distinct")
	var start := Vector3(1.37, 0.0, 39.60)
	var near := Vector3(1.2, 0, 37.2)
	var far := Vector3(3.6, 0, 38.0)
	var chosen: PackedVector3Array = routes.path_to_nearest(start, PackedVector3Array([near, far]))
	check(start.distance_to(near) < start.distance_to(far) and not chosen.is_empty() and chosen[-1].is_equal_approx(far),
		"The nearest reachable destination is selected by route length, not straight-line distance")
