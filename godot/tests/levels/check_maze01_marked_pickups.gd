extends "res://tests/levels/check_maze_01_greybox.gd"

const Level := preload("res://scenes/levels/maze_01_greybox.tscn")
const KeyConfig := preload("res://modules/maze_keys/maze01_gate_keys.gd")
const Items := preload("res://modules/maze_items/maze_item_controller.gd")

func run() -> void:
	root.size = Vector2i(1280, 900)
	scene = Level.instantiate()
	root.add_child(scene)
	actor = scene.get_node("%Player")
	generator = scene.get_node("%GeneratedMaze")
	var input_camera := Camera3D.new()
	actor.get_parent().add_child(input_camera)
	actor.movement_camera = input_camera
	await ticks(75)
	var perks = scene.get_node("MazePickupEffects")
	var items = scene.get_node("MazeItems")
	var start := actor.position
	check(not actor.get_parent().has_node("FinishDoctor"), "Maze 01 omits the doctor")
	check(perks.pickups.size() == 4 and items._extra_rabbits.size() == 2, "Two cakes, two flour bags, and three rabbit feet exist")
	var bridge_coin: Area3D = items.key_pickups.D3
	var coin_point := bridge_coin.position
	var vault: Dictionary = Layout.config().bridge_vault
	check(coin_point.x > vault.x[0] and coin_point.x < vault.x[1] and absf(coin_point.z - vault.z_center) < 0.2 and coin_point.y < 0.1,
		"The final mandatory coin is underneath the bridge deck")
	generator.gates.D1.set_open_state(true)
	await ticks(4)
	for pickup in perks.pickups + items._extra_rabbits + items.key_pickups.values():
		check(items._routes.path_to_nearest(start, PackedVector3Array([pickup.position])).size() > 1,
			"Marked pickup reachable: " + str(pickup.position))
		check(pickup.collision_layer == 0 and pickup.find_children("*", "PhysicsBody3D", true, false).is_empty(), "Pickup is passable")
	await place(coin_point + Vector3.UP * 2.6)
	check(not bridge_coin.claimed, "Standing on the bridge cannot claim the coin below")
	await place(Vector3(37.2, 0, 15.9))
	await walk_to(coin_point, "Walk through the vault and pick up the coin", false)
	check((not is_instance_valid(bridge_coin) or bridge_coin.claimed) and items.inventory.quantity(KeyConfig.COIN) == 1, "Lower route collects the final coin")
	await place(items._extra_rabbits[0].position)
	await place(items._extra_rabbits[1].position)
	check(items.inventory.quantity(Items.RABBIT) == 2, "Red placements share the rabbit foot inventory")

	var first_cake: Vector3 = perks.pickups[0].position
	var second_cake: Vector3 = perks.pickups[1].position
	var first_flour: Vector3 = perks.pickups[2].position
	var second_flour: Vector3 = perks.pickups[3].position
	await capture_model("cake_model", first_cake)
	await capture_model("flour_model", first_flour)
	items.inventory.clear_items()
	await place(first_cake)
	check(perks.boost_remaining==0.0 and items.inventory.quantity(&"ChocolateCake")==1,"Cake is stored until selected and used")
	items.inventory.select_item(&"ChocolateCake")
	items.inventory.request_selected_use()
	check(actor.move_speed_multiplier == 1.3 and perks.boost_remaining > 7.7, "Actively used cake boosts movement for eight seconds")
	await place(Vector3(37.2, 0, 15.9))
	var follow_rig := scene.get_node("%FollowRig") as Node3D
	var previous_yaw: float = follow_rig.get("yaw")
	follow_rig.set("yaw", -PI * 0.5)
	key(KEY_D, true)
	await ticks(18)
	check(is_equal_approx(actor.velocity.x, 1.6 * 1.3), "Actual walking speed is boosted")
	check(perks._trail_mesh.get_surface_count() == 2, "Cake leaves two continuous lines during movement")
	key(KEY_SHIFT, true)
	await ticks(18)
	check(actor.velocity.x > 1.6 * 1.3 and perks._trail_points.size() > 4, "Running extends the lines behind Charlie")
	await capture_effect("cake_trail")
	follow_rig.set("yaw", previous_yaw)
	key(KEY_SHIFT, false)
	key(KEY_D, false)
	await ticks(120)
	check(perks._trail_mesh.get_surface_count() == 0, "Trail fades when Charlie stops, even while boosted")
	await place(second_cake)
	items.inventory.select_item(&"ChocolateCake")
	items.inventory.request_selected_use()
	check(actor.move_speed_multiplier == 1.3 and perks.boost_remaining > 7.7, "Second cake refreshes the timer without stacking")
	await ticks(485)
	check(actor.move_speed_multiplier == 1.0 and perks._trail_mesh.get_surface_count() == 0, "Cake expires and restores movement")

	await place(first_flour)
	check(perks.flour_remaining > 2.7 and perks._screen.visible, "Flour starts a three-second obscuration")
	await ticks(17)
	check(perks._flour_material.get_shader_parameter("opacity") > 0.96, "The powder burst reaches peak opacity")
	await capture_effect("flour")
	await place(second_flour)
	check(perks.flour_remaining > 2.7 and perks._flour_material.get_shader_parameter("age") < 0.3, "Repeated flour restarts the burst on the existing overlay")
	await ticks(165)
	check(perks._screen.visible and perks._flour_material.get_shader_parameter("opacity") < 0.3, "Flour fades before expiry")
	await ticks(24)
	check(not perks._screen.visible and actor.move_speed_multiplier == 1.0, "Flour clears without affecting speed")
	scene.reset_level()
	await ticks(6)
	await place(first_cake)
	await place(first_flour)
	scene.reset_level()
	await ticks(8)
	check(perks.boost_remaining == 0.0 and not perks._screen.visible and perks.pickups.size() == 4, "Reset clears both effects and restores pickups")
	scene.queue_free()
	await process_frame
	scene = Level.instantiate()
	root.add_child(scene)
	var fresh = scene.get_node("MazePickupEffects")
	check(fresh.boost_remaining == 0.0 and not fresh._screen.visible, "Re-entry starts with a clean effect state")
	scene.queue_free()
	await process_frame
	print("MAZE 01 MARKED PICKUPS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)

func place(point: Vector3) -> void:
	actor.position = point + Vector3.UP * 0.04
	actor.velocity = Vector3.ZERO
	await ticks(7)

func capture_effect(id: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../.verification/maze01-marked-items")
	check(root.get_texture().get_image().save_png(folder.path_join(id + ".png")) == OK, "Capture " + id)

func capture_model(id: String, point: Vector3) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	var world := actor.get_parent()
	var old_camera := actor.get_viewport().get_camera_3d()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 50.0
	camera.look_at_from_position(point + Vector3(0.67, 1.65, 0.89), point + Vector3.UP)
	camera.make_current()
	await capture_effect(id)
	camera.free()
	old_camera.make_current()
