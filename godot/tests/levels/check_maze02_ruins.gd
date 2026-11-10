extends "res://tests/levels/check_maze_01_greybox.gd"

const Maze02 := preload("res://scenes/levels/Maze02.tscn")
const Ruins := preload("res://art/maze02/ruins/maze02_ruins.gd")

func set_wall(map: Dictionary, edge: Array, closed: bool) -> void:
	var a: Array = edge[0]
	var b: Array = edge[1]
	if a[0] == b[0]:
		map.grid.verticalWalls[a[0]][maxi(a[1], b[1])] = closed
	else:
		map.grid.horizontalWalls[maxi(a[0], b[0])][a[1]] = closed

func run() -> void:
	Input.use_accumulated_input = false
	var original: Dictionary = Loader.load_map().data
	var ruined := original.duplicate(true)
	for site: Dictionary in Ruins.SITES:
		set_wall(ruined, site.closed, true)
		set_wall(ruined, site.opened, false)
	for site: Dictionary in Ruins.WALL_CUTS:
		set_wall(ruined, site.opened, false)
	for mask in 16:
		var closed: Array[String] = []
		for door in 4:
			if mask & (1 << door):
				closed.append("D%d" % (door + 1))
		check(Layout.reachable(original, closed) == Layout.reachable(ruined, closed),
			"Same reachable cells for gate combination " + str(mask))

	scene = Maze02.instantiate()
	root.add_child(scene)
	await process_frame
	actor = scene.get_node("%Player")
	generator = scene.get_node("%GeneratedMaze")
	var camera := Camera3D.new()
	actor.get_parent().add_child(camera)
	actor.movement_camera = camera
	await ticks(6)
	check(scene.loaded_ok and generator.gates.size() == 4, "Maze02 and all four gates loaded")
	check(scene.maze_data.routes == original.routes, "Both reference routes are preserved")
	check(generator.architecture.has_node("H2_Bridge") and is_equal_approx(generator.gates.D4.position.y, 2.6),
		"East bridge and the raised D4 door remain")
	var deck := ray(Vector3(14.4, 2.5, 44.4), Vector3(14.4, 0.0, 44.4))
	check(generator.architecture.has_node("H1_Deck") and is_equal_approx(deck.position.y, 1.2),
		"Original H1 deck and its collision are present")
	await walk_cells([[18, 3], [18, 4], [18, 5], [18, 6], [18, 7], [18, 8]], "Restored H1")
	for site: Dictionary in Ruins.WALL_CUTS:
		await walk_cells(site.opened, str(site.node))
	for site: Dictionary in Ruins.SITES:
		var region := "Maze02Ruins/" + str(site.portal)
		check(not generator.has_node(Ruins.wall_path(site.opened)), "Full wall replaced at " + region)
		var reverse_route: Array = site.detour.duplicate()
		reverse_route.reverse()
		for route: Array in [site.detour, reverse_route]:
			var start := Layout.cell_point(route[0])
			var blocked := Layout.cell_point(route[-1])
			actor.position = start + Vector3.UP * 0.06
			actor.velocity = Vector3.ZERO
			await ticks(8)
			var probe := KinematicCollision3D.new()
			var transform := actor.global_transform
			transform.origin.y += 0.06
			var collided := actor.test_move(transform, blocked - start, probe)
			check(collided and region + "/BlockedBranch/" in String(probe.get_collider().get_path()),
				"Rubble actually stops the player capsule at " + region)
			# A full standing jump peaks below 0.8 m. Check the same obstruction at that height.
			transform.origin.y = start.y + 0.8
			check(actor.test_move(transform, blocked - start, probe)
				and region + "/BlockedBranch/" in String(probe.get_collider().get_path()),
				"Rubble also blocks the capsule at jump height at " + region)
			var across := (blocked - start).normalized().cross(Vector3.UP)
			for offset: float in [-0.84, 0.84]:
				transform.origin = actor.global_position + across * offset + Vector3.UP * 0.06
				check(actor.test_move(transform, blocked - start), "No walkable gap at a rubble edge in " + region)
			for index in range(1, route.size()):
				if not await walk_to(Layout.cell_point(route[index]), "%s detour %s to %s" % [region, route[index-1], route[index]]):
					break
			check(actor.is_on_floor(), "Detour ends on the ground at " + region)
		print("MAZE02 RUINS WALKED: ", site.portal)
	scene.queue_free()
	await process_frame
	print("MAZE02 RUINS: 16 gate combinations; H1 traversal; three new breaches; failures=", failures)
	quit(0 if failures == 0 else 1)

func walk_cells(route: Array, label: String) -> void:
	actor.position = Layout.cell_point(route[0], 0.06)
	actor.velocity = Vector3.ZERO
	await ticks(8)
	for index in range(1, route.size()):
		if not await walk_to(Layout.cell_point(route[index]), label + " " + str(route[index])):
			break
