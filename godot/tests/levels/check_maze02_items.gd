extends "res://tests/levels/check_maze01_keys.gd"

const Level02 := preload("res://scenes/levels/Maze02.tscn")
const Marks := preload("res://modules/maze02_items/placements.gd")
const PerkEffects := preload("res://modules/maze02_items/item_effects.gd")

func run() -> void:
	Input.use_accumulated_input = false
	root.size = Vector2i(1280, 900)
	var initial_bus_count := AudioServer.bus_count
	scene = Level02.instantiate()
	root.add_child(scene)
	actor = scene.get_node("%Player")
	generator = scene.get_node("%GeneratedMaze")
	items = scene.get_node("MazeItems")
	inventory = items.inventory
	var camera := Camera3D.new()
	actor.get_parent().add_child(camera)
	actor.movement_camera = camera
	await ticks(95)
	var effects: PerkEffects = scene._item_effects
	var spawn := actor.position
	check(effects.televisions[0].broadcast.resource_path != effects.televisions[1].broadcast.resource_path
		and effects.televisions[0]._speech.stream.data != effects.televisions[1]._speech.stream.data, "Each TV plays a different program")
	check(items.key_pickups.size() + scene._perks.pickups.size() + effects.capsules.size() + effects.televisions.size() + 1 == 11, "Eleven marked props")
	check(is_equal_approx(effects.vision_chance, 0.8), "Both capsules share the 80 percent default and roll on active use")
	for id: String in Marks.KEYS:
		check_placement(items.key_pickups[id], Marks.KEYS[id])
	for i in 2:
		check_placement(scene._perks.pickups[i], Marks.CAKES[i])
		check_placement(effects.capsules[i], Marks.CAPSULES[i])
		check_capsule_pose(effects.capsules[i])
		check_placement(effects.televisions[i], Marks.TELEVISIONS[i].point)
	check_placement(items._pickup, Marks.RABBIT)
	await capture_effect("capsule_pose", Marks.CAPSULES[0] + Vector3(0.1, 1.3, 0.45), Marks.CAPSULES[0] + Vector3.UP * 0.23)

	check(reachable(spawn, Marks.KEYS.D1), "First coin is accessible while every gate is closed")
	await place(Marks.KEYS.D1)
	await open_and_check("D1", Keys.COIN, 0)
	for id: String in ["D3", "D4", "D2"]:
		check(reachable(spawn, Marks.KEYS[id]), "Reachable marked key " + id)
		await place(Marks.KEYS[id])
		await open_and_check(id, Keys.GATES[id].item, 0)
	check(scene.can_finish(), "Four marked keys still operate the proper gates")

	await place(Marks.RABBIT)
	check(inventory.quantity(Rabbit.RABBIT) == 1, "Marked rabbit foot is collectible")
	inventory.get_node("UseItem").pressed.emit()
	await ticks(3)
	check(inventory.quantity(Rabbit.RABBIT) == 0 and is_instance_valid(items._guide), "Rabbit still uses the reachable exit guide")
	items.cancel_guide()

	effects.vision_chance = 1.0
	await place(Marks.CAPSULES[0])
	inventory.select_item(&"PinkCapsule")
	inventory.request_selected_use()
	check(effects.vision.remaining > 6.5 and effects.capsules[0].claimed and not effects.capsules[1].claimed, "First capsule independently starts vision")
	check(effects.vision._paint.no_depth_test and effects.vision._mesh.get_surface_count() > 0
		and effects.vision._trail.instance_count > 0 and effects.vision._pickups.get_child_count() > 0, "World markers render through walls")
	check(effects.vision._screen.visible and effects.vision._screen.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Vision overlay does not consume camera input")
	var first_strength: float = effects.vision._screen_material.get_shader_parameter("strength")
	var first_cues: float = effects.vision._screen_material.get_shader_parameter("cue_strength")
	check(first_strength > 0.0 and first_strength < 0.5 and first_cues < first_strength, "Vision begins with a graded darkening before its highlights")
	check(effects.vision._focus_audio._intro.playing, "Positive capsule starts the gathering sound")
	var vision_eye := Vector3(23.0, 3.1, 39.2)
	var vision_look := Vector3(27.6, 0.7, 36.0)
	var movement_basis := camera.transform
	camera.fov = 57.0
	camera.look_at_from_position(vision_eye, vision_look)
	camera.make_current()
	await ticks(36)
	check(effects.vision._focus_audio._hold.playing, "Focus sustains a looping attention sound")
	var focus_bus := StringName(effects.vision._focus_audio._buses.values()[0])
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(focus_bus)) < -9.0, "Vision ducks its scene environment smoothly")
	check(float(effects.vision._screen_material.get_shader_parameter("cue_strength")) > first_cues + 0.6, "Highlights ease into view")
	var translucent := false
	for id: String in scene.wall_occlusion.guide_blockers:
		translucent = translucent or float(scene.wall_occlusion.groups[id].opacity) < 0.8
	check(translucent, "Walls that occlude the route become translucent")
	camera.transform = movement_basis
	await capture_effect("capsule_vision", vision_eye, vision_look)
	scene.get_node("%FollowRig").camera.make_current()
	await ticks(120)
	check(effects.vision.remaining > 4.1, "Vision retains over four seconds after its entrance and two-second hold")
	await ticks(238)
	check(effects.vision.remaining > 0.0 and effects.vision._screen_material.get_shader_parameter("strength") < 1.0, "Vision fades in the last fraction of seven seconds")
	await ticks(29)
	check(not effects.vision._view.visible and not effects.vision._screen.visible
		and scene.wall_occlusion.guide_blockers.is_empty(), "Vision finishes and releases the walls")
	check(not effects.vision._focus_audio._hold.playing
		and is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(focus_bus))), "Vision restores its environment and stops the focus loop")

	await place(Marks.CAKES[0])
	inventory.select_item(&"ChocolateCake")
	inventory.request_selected_use()
	check(is_equal_approx(actor.move_speed_multiplier, scene.cake_speed_multiplier), "First marked cake gives the existing boost")
	effects.vision_chance = 0.0
	await place(Marks.CAPSULES[1])
	inventory.select_item(&"PinkCapsule")
	inventory.request_selected_use()
	check(effects.slow_remaining > 3.8 and is_equal_approx(actor.capsule_speed_factor, 0.45), "Second capsule independently gives the four-second slowdown")
	check(is_equal_approx(absf(actor._movement_modifier()), scene.cake_speed_multiplier * 0.45), "Boost and slowdown compose")
	await ticks(223)
	check(effects.slow_remaining > 0.0, "Slowdown still active before four seconds")
	await ticks(24)
	check(is_equal_approx(absf(actor._movement_modifier()), scene.cake_speed_multiplier), "Slowdown expires without canceling the cake boost")
	await ticks(250)
	check(is_equal_approx(absf(actor._movement_modifier()), 1.0), "Original speed returns after cake expires")
	await place(Marks.CAKES[1])
	inventory.select_item(&"ChocolateCake")
	inventory.request_selected_use()
	check(is_equal_approx(actor.move_speed_multiplier, scene.cake_speed_multiplier), "Second marked cake is collectible")

	for tv in effects.televisions:
		var cylinder: CylinderShape3D = tv.get_node("InterferenceCylinder").shape
		var ring: PlaneMesh = tv.get_node("InterferenceRing").mesh
		var light: OmniLight3D = tv.get_node("BlueScreenSpill")
		check(is_equal_approx(tv.radius, 3.0) and is_equal_approx(cylinder.radius, tv.radius) and ring.size.is_equal_approx(Vector2.ONE * tv.radius * 2.0)
			and is_equal_approx(light.omni_range, tv.radius) and tv.collision_layer == 0 and tv.collision_mask == 2, "Radius shared by collision, circle and light")
		check(reachable(spawn, tv.position), "TV corner remains reachable")
		var clear := true
		for x: float in [-0.46, 0.46]:
			for z: float in [-0.50, 0.50]:
				var corner := Vector3(x, 0.0, z).rotated(Vector3.UP, tv.facing)
				var origin := tv.position + Vector3.UP * 0.45
				var ray := PhysicsRayQueryParameters3D.create(origin, origin + corner, 1)
				clear = clear and actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		check(clear, "Angled model footprint clears both corner walls")
		check(not tv._ring.visible, "Ring stays hidden before the player enters")
		var idle_glow: float = tv._tv.blue_glow_strength
		await place(tv.position)
		var entering_alpha: float = tv._ring_material.get_shader_parameter("presence")
		check(entering_alpha > 0.0 and entering_alpha < 1.0, "Circle fades in instead of appearing immediately")
		await ticks(12)
		check(tv._ring.visible, "Ring shows only while the TV affects the player")
		check(tv.active and actor.tv_reversed and tv._audio.playing and tv._tv.intensity > 0.5, "Active TV reverses input, starts static and raises CRT noise")
		check(tv._tv.screen_overlay.visible and not tv._tv.symbols.is_enabled and not tv._tv.symbols.visible
			and tv._tv.blue_glow_strength > idle_glow + 0.2 and light.light_energy > 0.0, "Blue CRT and local light strengthen without noise symbols")
		var brightness := light.light_energy
		await ticks(8)
		check(not is_equal_approx(brightness, light.light_energy), "Local light follows the CRT flicker")
		var from := actor.position.z
		var camera_basis := camera.basis
		key(KEY_W, true)
		await ticks(8)
		key(KEY_W, false)
		check(actor.position.z > from + 0.04 and camera.basis == camera_basis, "W actually moves backwards while the camera stays unchanged")
		var across_wall := wall_test_point(tv)
		check(across_wall != Vector3.INF, "Found a nearby corridor across a solid wall")
		if across_wall != Vector3.INF:
			await place(across_wall)
			check(tv.active and actor.tv_reversed, "Interference reaches the player on the other side of the wall")
		await place(spawn)
		check(not tv.active and not actor.tv_reversed and tv._ring.visible
			and float(tv._ring_material.get_shader_parameter("presence")) < 1.0, "Leaving restores controls while the ring fades")
		await ticks(50)
		check(not tv._audio.playing and not tv._ring.visible, "Local static and the fading circle finish cleanly")
	var first = effects.televisions[0]
	var second = effects.televisions[1]
	await place(first.position + Vector3(0.12, 0.0, 1.44))
	await capture_effect("tv_interference", first.position + Vector3(2.2, 1.75, 0.75), first.position + Vector3.UP * 0.53)
	await capture_effect("tv_ring", first.position + Vector3(0.0, 6.1, 2.2), first.position)
	# Temporarily overlap the test instances in the open approach. Production placements stay unchanged.
	first.position = Vector3(21.1, 0.0, 16.9)
	second.position = Vector3(23.0, 0.0, 16.9)
	await place(Vector3(22.0, 0.0, 16.9))
	check(first.active and second.active and actor.tv_reversed, "Both test areas can overlap")
	await place(Vector3(24.3, 0.0, 16.9))
	check(not first.active and float(first._ring_material.get_shader_parameter("presence")) < 1.0 and second.active and second._ring.visible and actor.tv_reversed, "Leaving one overlapping TV does not restore direction")
	await place(second.position + Vector3.BACK * (second.radius + 0.08))
	check(not second.active and not actor.tv_reversed, "Effect stops just outside the actual drawn radius")
	# Hold a single movement across the edge in both directions.
	second.position = Vector3(100.0, 0.0, 100.0)
	scene._perks.boost_remaining = 0.0
	actor.move_speed_multiplier = 1.0
	await place(first.position + Vector3.RIGHT * (first.radius + 0.25))
	await check_edge_travel(KEY_A, -1.0, first, true)
	await ticks(2)
	check(first.active and actor.tv_reversed, "Standing inside keeps the interference active")
	await check_edge_travel(KEY_A, 1.0, first, false)
	key(KEY_D, true)
	var start_x := actor.position.x
	await ticks(6)
	key(KEY_D, false)
	check(actor.position.x > start_x + 0.08, "Fresh movement outside immediately uses normal controls")
	# Small position noise at the painted edge cannot continually toggle the field.
	await place(first.position + Vector3.RIGHT * (first.radius - 0.2))
	var changes := 0
	var previous: bool = first.active
	for i in 20:
		actor.position = first.position + Vector3.RIGHT * (first.radius + (0.015 if i % 2 == 0 else -0.015)) + Vector3.UP * 0.04
		actor.velocity = Vector3.ZERO
		await ticks(1)
		if first.active != previous:
			changes += 1
		previous = first.active
	check(changes <= 1, "Boundary position noise does not repeatedly toggle lights, ring or input")

	# Lighting and radio follow player distance beyond the movement-interference circle.
	actor.set_physics_process(false)
	await place(first.position + Vector3.RIGHT * 15.1)
	await ticks(50)
	check(not first.illuminated and not first._audio.playing and not first._speech.playing,
		"Both radio streams stop beyond the outer sensing distance")
	await place(first.position + Vector3.RIGHT * 10.0)
	await ticks(40)
	check(first.illuminated and not first.active and not first._ring.visible and not actor.tv_reversed,
		"TV lights at ten meters while movement and the three-meter ring remain normal")
	check(first._audio.playing and first._speech.playing and first._speech.stream.get_length() > 900.0,
		"Electrical current and the long English news program play at ten meters")
	var ten_meter_level: float = first._audio.volume_db
	await place(first.position + Vector3.RIGHT * 14.05)
	await ticks(55)
	check(first.illuminated and first._audio.volume_db < -50.0 and first._speech.volume_db < -47.0
		and first._audio.volume_db < ten_meter_level - 12.0, "Radio is almost inaudible at fourteen meters")
	await place(first.position + Vector3.RIGHT * 2.0)
	await ticks(55)
	check(first.active and first._audio.volume_db > ten_meter_level + 8.0,
		"Radio becomes clearly louder as the player approaches")
	scene.sound.set_muted(true)
	await ticks(3)
	check(not first._audio.playing and not first._speech.playing, "Sound toggle stops both TV sources")
	scene.sound.set_muted(false)
	actor.set_physics_process(true)
	first.position = Marks.TELEVISIONS[0].point
	second.position = Marks.TELEVISIONS[1].point
	scene.reset_level()
	await ticks(6)
	check(effects.capsules.size() == 2 and not effects.capsules[0].claimed and not effects.capsules[1].claimed
		and not actor.tv_reversed and is_equal_approx(absf(actor._movement_modifier()), 1.0), "Reset restores capsules and motion state")
	release()
	scene.queue_free()
	await process_frame
	check(AudioServer.bus_count == initial_bus_count, "Scene exit removes its focus audio buses")
	print("MAZE 02 MARKED ITEMS: ", failures, " failures")
	quit(failures)

func check_capsule_pose(pickup: Node3D) -> void:
	var source := pickup._display.find_child("SourceModel", true, false) as Node3D
	check(source != null and is_equal_approx(absf(source.global_basis.z.normalized().dot(Vector3.UP)), sqrt(0.5)),
		"Capsule's long axis tilts 45 degrees from vertical")
	var floor_y := INF
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var bounds := mesh.global_transform * mesh.get_aabb()
		floor_y = minf(floor_y, bounds.position.y)
	check(floor_y >= pickup.global_position.y and floor_y < pickup.global_position.y + 0.04,
		"Tilted capsule stays above the floor")

func check_edge_travel(code: int, direction: float, tv: Node, finish_inside: bool) -> void:
	var start_x := actor.position.x
	var previous_x := start_x
	var last_active: bool = tv.active
	var changes := 0
	var monotonic := true
	key(code, true)
	for i in 70:
		await ticks(1)
		monotonic = monotonic and (actor.position.x - previous_x) * direction >= -0.0005
		if tv.active != last_active:
			changes += 1
		last_active = tv.active
		previous_x = actor.position.x
	key(code, false)
	await ticks(2)
	check(monotonic and (actor.position.x - start_x) * direction > 1.4,
		"Held movement crosses the TV boundary without bouncing")
	check(changes == 1 and tv.active == finish_inside, "A complete crossing changes interference once")

func snapshot(_id: String, _point: Vector3, _offset: Vector3) -> void:
	# Keep gate timing assertions independent of the display's frame rate.
	pass

func wall_test_point(tv: Node3D) -> Vector3:
	var space := actor.get_world_3d().direct_space_state
	for radius: float in [1.55, 1.77, 1.94]:
		for i in 24:
			var candidate := tv.position + Vector3.RIGHT.rotated(Vector3.UP, TAU * i / 24.0) * radius
			var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				tv.position + Vector3.UP * 0.85, candidate + Vector3.UP * 0.85, 1))
			if wall.is_empty() or Vector3(wall.position).distance_to(candidate + Vector3.UP * 0.85) < 0.65:
				continue
			var floor := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				candidate + Vector3.UP * 0.85, candidate - Vector3.UP * 0.15, 1))
			if floor.is_empty() or absf(floor.position.y) > 0.06:
				continue
			var clear := true
			for axis: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
				var origin := candidate + Vector3.UP * 0.55
				clear = clear and space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + axis * 0.47, 1)).is_empty()
			if clear:
				return candidate
	return Vector3.INF

func check_placement(prop: Node3D, expected: Vector3) -> void:
	var ray := PhysicsRayQueryParameters3D.create(expected + Vector3.UP * 6.0, expected - Vector3.UP, 1)
	var floor := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	check(prop.global_position.is_equal_approx(expected) and not floor.is_empty()
		and absf(float(floor.position.y) - expected.y) < 0.045, "Grounded marker " + String(prop.name))
	check(prop is Area3D and prop.collision_layer == 0 and prop.collision_mask == 2, "Non-blocking marked prop " + String(prop.name))

func capture_effect(id: String, eye: Vector3, look: Vector3) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	var camera := Camera3D.new()
	actor.get_parent().add_child(camera)
	camera.fov = 57.0
	camera.look_at_from_position(eye, look)
	camera.make_current()
	await process_frame
	RenderingServer.force_draw(false)
	var folder := ProjectSettings.globalize_path("res://../.verification/maze02-items-20261112")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(id + ".png")) == OK, "Capture " + id)
	camera.free()
	scene.get_node("%FollowRig").camera.make_current()
