extends "res://tests/art_samples/check_art_sample.gd"

const Level := preload("res://scenes/levels/maze_01_greybox.tscn")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const Finish := preload("res://art/maze01/maze01_dream_finish.gd")
const GateArt := preload("res://art/maze01/dream_gate_finish.gd")
const Gate := preload("res://scripts/levels/greybox_gate.gd")

func check_mist_zones(air: Node3D) -> void:
	var lit_zones := {
		"PlazaBreeze": "PlazaWestFireflies", "WestWalkBreeze": "WestMistFireflies",
		"SouthBridgeBreeze": "SouthWalkFireflies", "EastWalkBreeze": "SouthEastWalkFireflies",
		"NorthArchBreeze": "NorthwestWalkFireflies", "EastBridgeBreeze": "RaisedEastMistFireflies",
		"EntryBreeze": "EntryMistFireflies", "ChapelTerraceBreeze": "ChapelTerraceFireflies",
		"ExitBreeze": "ExitFireflies",
	}
	for id: String in lit_zones:
		var mist: Node3D = air.get_node(id)
		var cluster: Node3D = air.get_node(lit_zones[id])
		check(mist.get_node("MistRibbon1").mesh.size.x >= 6.0 and mist.has_node("MistCanopy"),
			id + " has broad drifting mist at ground level and from above")
		check(mist.position.distance_to(cluster.position) < 2.1 and cluster.get_child_count() >= 3,
			id + " has visible fireflies nearby")
	check(air.get_node("ExteriorCloudBanks").get_child_count() == 8, "Eight cloud banks encircle the maze")
	var haze: MeshInstance3D = air.get_node("MazeFloorHaze")
	check(haze.mesh.size.is_equal_approx(Vector2(45.6,45.6))
		and haze.material_override.get_shader_parameter("maze_haze"), "Ground haze spans the maze footprint")
	var trail_clusters := air.find_children("*TrailFireflies","Node3D",false,false)
	check(trail_clusters.size() == 11, "Eleven additional warm clusters follow the mist trails")
	for cluster: Node3D in trail_clusters:
		var mist := air.get_node(str(cluster.name).replace("Fireflies","Breeze")) as Node3D
		var bounce := cluster.get_node("SoftAmberBounce") as OmniLight3D
		check(cluster.position.distance_to(mist.position) < 0.5 and bounce.light_energy > 0.18,
			"Trail fireflies cast amber light near " + str(mist.name))

func check_wall_junctions(gen: Node3D) -> void:
	var marked := {
		"HorizontalWalls/WallSegment_H_11_0": Finish.CREAM_VIOLET,
		"VerticalWalls/WallSegment_V_14_12": Finish.TEAL_WALL,
		"VerticalWalls/WallSegment_V_15_12": Finish.TEAL_WALL,
	}
	for path: String in marked:
		check(gen.get_node(path).get_child(0).get_meta("accent_tint", Color.TRANSPARENT) == marked[path],
			"The marked wall has its accent: " + path)
	var walls := gen.get_node("HorizontalWalls").get_children() + gen.get_node("VerticalWalls").get_children()
	for wall: Node3D in walls:
		var visual := wall.get_child(0) as MeshInstance3D
		if not visual.has_meta("accent_tint"):
			continue
		var colored := visual.global_transform * visual.get_aabb()
		for neighbor: Node3D in walls:
			var other := neighbor.get_child(0) as MeshInstance3D
			if other == visual or other.get_meta("accent_tint", Color.TRANSPARENT) == visual.get_meta("accent_tint"):
				continue
			var overlap := colored.intersection(other.global_transform * other.get_aabb()).size
			check(overlap.x < 0.003 or overlap.z < 0.003 or overlap.y < 0.003,
				"Different wall finishes do not overlap: %s / %s" % [wall.name, neighbor.name])

	var corridor: Node3D = gen.architecture.get_node("SunkenCorridor")
	for pair: Array in [
		["Panel0","H_6_1",Vector3.AXIS_Z], ["Panel0","H_6_2",Vector3.AXIS_Z],
		["Panel0","H_7_2",Vector3.AXIS_X], ["PanelEnd","H_11_2",Vector3.AXIS_X],
		["PanelEnd","H_12_1",Vector3.AXIS_Z],
	]:
		var panel := corridor.get_node("WallSegment_H6_" + pair[0]).get_child(0) as MeshInstance3D
		var cross_wall := gen.get_node("HorizontalWalls/WallSegment_" + pair[1]).get_child(0) as MeshInstance3D
		var along: int = pair[2]
		var a := panel.global_transform * panel.get_aabb()
		var b := cross_wall.global_transform * cross_wall.get_aabb()
		var touch := minf(a.end[along], b.end[along]) - maxf(a.position[along], b.position[along])
		check(absf(touch) < 0.002, "The niche join meets flush without competing surfaces: " + pair[1])

func snap(id: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../.verification/maze01-final")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(id+".png")) == OK, "Capture " + id)

func run() -> void:
	root.size = Vector2i(1440,1000)
	var baseline = Level.instantiate()
	baseline.dream_art_enabled = false
	root.add_child(baseline)
	await ticks(10)
	var original := geometry(baseline)
	baseline.free()
	scene = Level.instantiate()
	root.add_child(scene)
	await ticks(45)
	check(scene.loaded_ok, "The regular playable Maze 01 loads the full art pass")
	check(geometry(scene) == original, "Original geometry, collision layers and shape states match the raw level")
	var gen = scene.get_node("%GeneratedMaze")
	check(not gen.has_node("Entry") and not gen.has_node("Exit"), "Start and finish circles are absent")
	check(gen.get_parent().has_node("ExitTrigger"), "Removing circles retains the completion area")
	var air: Node3D = gen.get_parent().get_node("DreamAtmosphere")
	var stand: StaticBody3D = gen.get_parent().get_node("ChapelBookStand")
	var book: Node3D = stand.get_node("ChapelBook")
	var center: Array = Layout.config().building.circle.center
	check(Vector2(stand.position.x, stand.position.z).is_equal_approx(Vector2(center[0], center[1]))
		and Vector2(book.position.x, book.position.z).is_zero_approx(), "The column and book share the exact hall center")
	check(stand.get_node("StandCollision").shape.height > 1.20 and book.scale.x > 0.008,
		"The taller stone stand has collision and supports the larger book")
	check_mist_zones(air)
	check_wall_junctions(gen)
	var roof: Node3D = gen.round_hall.get_node("Roof")
	var pendant: Node3D = roof.get_node("CrystalChandelier")
	var light: SpotLight3D = roof.get_node("ChandelierFloorLight")
	check(pendant.scene_file_path.ends_with("/crystal_chandelier.tscn") and pendant.lit and pendant.scale.x > 1.25, "The enlarged lit crystal chandelier is installed")
	check((-light.global_basis.z).dot(Vector3.DOWN) > 0.999, "The chandelier illuminates the floor")
	var floor: ShaderMaterial = gen.round_hall.get_node("HallFloor").material_override
	check(floor.get_shader_parameter("finish_color") == Finish.CHAPEL_STONE, "Chapel stone has its own warm base color")
	check_chapel_windows(gen.round_hall, scene.get_node("%Player"))
	check(air.has_node("PoolFirefliesWest/SoftAmberBounce") and air.has_node("PoolFirefliesSouth/SoftAmberBounce"), "Both pool firefly groups light their surroundings")
	check(gen.architecture.find_children("DressedStoneArch", "MeshInstance3D", true, false).is_empty(), "No added frame overlays the original arches")
	check(not air.has_node("CourtyardTurnWarmPool"), "No bare wall hotspot at the water stairs")
	var bottom_light: OmniLight3D = air.get_node("PoolBottomLight")
	var pool: Dictionary = Layout.config().northwest
	var bottom_point := Vector2(bottom_light.position.x, bottom_light.position.z)
	check(bottom_light.position.y < float(pool.waterSurface) and bottom_light.position.y > Layout.courtyard_height(bottom_point), "Pool light sits between the pool floor and water surface")
	check_fish(gen.architecture.get_node("NorthwestCourtyard/PoolGoldfish"), float(pool.waterSurface))
	var floating: Node3D = gen.architecture.get_node("NorthwestCourtyard/FloatingDuckweed")
	check(floating.get_child_count()==3,"Three floating leaves")
	var leaf: Node3D = floating.get_child(0)
	var start := leaf.position
	await ticks(16)
	var lift := leaf.position.y-float(pool.waterSurface)
	check(leaf.position.distance_to(start)>0.002 and lift>0.014 and lift<0.041 and leaf.scale.x>0.20,"Larger leaves drift just above the waterline")
	check(gen.get_node("EarthBearer/PlazaGreenery").get_aabb().position.y>=0.0,"Plaza greenery sits on the floor")
	var meadow: MeshInstance3D = gen.get_node("EarthBearer/PlazaMeadow")
	check(meadow.mesh.size.is_equal_approx(Vector2(9.0,9.0)),"The grass finish reaches the open thresholds")
	check(not gen.get_node("EarthBearer").has_node("PlazaClimbingVines"),"The meadow leaves the walls clear of vines")
	for id: String in ["PlazaWestFireflies","PlazaEastFireflies"]:
		check(air.get_node(id+"/SoftAmberBounce").light_energy>0.35,"Plaza fireflies add warm light")
	for id: String in ["PlazaEntranceBreeze","PlazaBreeze","PlazaUpperBreeze","PlazaBackBreeze"]:
		check(air.get_node(id).get_child_count()>=2,"Mist occupies distinct levels and viewing angles")
	for cluster: String in ["SouthWalkFireflies", "NorthBridgeFireflies", "ExitFireflies"]:
		check(air.has_node(cluster + "/SoftAmberBounce"), "New firefly cluster is active: " + cluster)
	await snap("00_entry_arch")
	var counts: Dictionary = {}
	for container: Node3D in [gen.architecture, gen.get_node("VerticalWalls"), gen.get_node("HorizontalWalls")]:
		for mesh: MeshInstance3D in container.find_children("*","MeshInstance3D",true,false):
			if mesh.get_meta("greybox_part","") == "Indicator" or mesh.has_meta("art_addition"):
				continue
			var role: String = mesh.get_meta("art_role","")
			check(not role.is_empty(), "Missing finish on " + str(mesh.get_path()))
			counts[role] = counts.get(role,0) + 1
			var part: String = mesh.get_meta("greybox_part","")
			if part.begins_with("GuardRail"):
				check(role in ["prism_plaster","plaster"], "Other bridges retain their existing plaster rails")
			if part.begins_with("GalleryBal"):
				check(role == "pool_rail", "Only the pool gallery rails use teal")
			if part in Finish.POOL_TEAL_WALLS and mesh.get_parent().get_parent().name == &"NorthwestCourtyard":
				check(mesh.get_meta("accent_tint",Color.TRANSPARENT)==Finish.TEAL_WALL,"Pool wall masonry shares the lake color")
				check(mesh.material_override is StandardMaterial3D,"The teal walls have their smooth plaster finish")
			if part in Finish.NICHE_FACING_WALLS:
				check(mesh.get_meta("accent_tint",Color.TRANSPARENT)==Finish.CREAM_VIOLET,"The wall across from the niches is violet")
			if part == "WallSegment_H6_Panel0":
				check(not mesh.has_meta("accent_tint"),"The wall on the niche side keeps its cream finish")
			if role == "roof":
				check(mesh.material_override == Finish.Roof, "All roofs share the existing teal material")
			if role in ["floor", "floor_detail", "bridge"]:
				check(mesh.material_override.get_shader_parameter("finish_color") == Finish.Stone.albedo_color, "Walking surfaces retain the pale limestone color")
	check(counts.get("gate_glaze",0) == 4 and counts.get("roof",0) + counts.get("porch_roof",0) == 19, "Four gates, the teal roof, and cream porch roofs are finished")
	check(counts.get("floor",0) > 80 and counts.get("floor_detail",0) > 12 and counts.get("bridge",0) > 10,"Main floors, special paving and H1–H4 are finished")
	for portal: String in Finish.ACCENT_PORTALS:
		var accent: Color = Finish.ACCENT_PORTALS[portal]
		for mesh: MeshInstance3D in gen.architecture.get_node(portal).find_children("*","MeshInstance3D",true,false):
			check(mesh.get_meta("accent_tint",Color.TRANSPARENT)==accent,"Every piece of an accent arch is tinted together")
	for gate: Gate in gen.gates.values():
		check(gate.has_node("DreamGateFinish"), "Every gate has visual-only slide details")
		check(gate.get_node("DreamGateFinish").glaze.albedo_color == Finish.Roof.albedo_color, "All moving leaves and the spire use the same teal")
		check(gate.find_children("Sleeve*", "Node3D", true, false).is_empty(), "The upper housing is absent")
	for mesh: MeshInstance3D in gen.marker_pins:
		check(not mesh.visible, "Debug pins do not show during play")
	var rig = scene.get_node("%CameraRig")
	scene.set_walk_mode(false)
	rig.reset_view()
	rig.pitch = 0.52
	rig.zoom = 1.08
	rig._update_camera()
	await ticks(12)
	await snap("01_overview")
	scene.inspect_location(10)
	var follow = scene.get_node("%FollowRig")
	follow.yaw = 0.8
	follow.pitch = -0.1
	follow.distance = 3.8
	await ticks(42)
	await snap("02_charlie")
	scene.inspect_location(8)
	follow.yaw = -PI/2
	follow.pitch = 0.30
	await ticks(42)
	await snap("03_wall_and_floor")
	scene.inspect_location(17)
	rig.yaw = 0.85
	rig.pitch = 0.26
	rig.zoom = 1.0
	rig._update_camera()
	await ticks(15)
	await snap("04_chapel")
	scene.inspect_location(14)
	follow.yaw = 0.04
	follow.pitch = 0.64
	await ticks(24)
	await snap("09_south_terrace")
	scene.inspect_location(10)
	var interior := Camera3D.new()
	follow.get_parent().add_child(interior)
	interior.fov = 77.0
	interior.look_at_from_position(Vector3(25.18, 1.72, 25.95), Vector3(23.73, 2.49, 22.32))
	interior.current = true
	await ticks(24)
	await snap("10_chapel_interior")
	var glazing: Node3D = gen.round_hall.find_children("ArchedWindow*","Node3D",false,false).filter(func(window: Node3D): return window.get_meta("main_window", false)).front()
	interior.fov = 51.0
	interior.look_at_from_position(glazing.to_global(Vector3(0.36,1.85,-3.72)), glazing.to_global(Vector3(0.0,2.20,0.0)))
	await ticks(4)
	await snap("15_chapel_blue_glass")
	interior.free()
	scene.inspect_location(21)
	await ticks(24)
	await snap("11_star_corridor")
	scene.inspect_location(8)
	follow.yaw = 0.22
	follow.pitch = 0.56
	follow.distance = 3.5
	await ticks(30)
	await snap("12_wading_pool")
	scene.reset_walk()
	follow.pitch = 0.60
	follow.distance = 3.6
	key(KEY_W,true)
	key(KEY_SHIFT,true)
	await ticks(47)
	await snap("14_running_footprints")
	key(KEY_W,false)
	key(KEY_SHIFT,false)
	scene.inspect_location(1)
	var gate: Gate = gen.gates.D1
	var visual: GateArt = gate.get_node("DreamGateFinish")
	var probe := Camera3D.new()
	gate.get_parent().add_child(probe)
	probe.projection = Camera3D.PROJECTION_ORTHOGONAL
	probe.size = 5.6
	probe.look_at_from_position(gate.to_global(Vector3(-0.10,2.62,-0.85)),gate.to_global(Vector3(0,2.65,0)))
	probe.current = true
	await ticks(10)
	var collision: CollisionShape3D = gate.leaf.get_node("GateCollision")
	var closed_center := collision.global_position
	check(is_zero_approx(gate.leaf.position.y) and not collision.disabled, "Closed gate retains the original collision")
	check(scene.closest_switch == gen.switches.D1, "Player can operate the original S1 in the real level")
	await snap("05_gate_closed")
	key(KEY_E,true)
	await ticks(1)
	key(KEY_E,false)
	await ticks(6)
	check(gate.is_open and is_zero_approx(gate.leaf.position.y) and not collision.disabled, "Unlock lights the gate before it moves")
	check(float(visual.inlay.get_shader_parameter("elapsed"))>0.04 and float(visual.inlay.get_shader_parameter("elapsed"))<0.16,"Only the lowest relief starts to charge")
	await ticks(57)
	check(float(visual.trace.get_shader_parameter("charge"))>0.7 and is_zero_approx(gate.leaf.position.y),"Crescent and star finish charging before descent")
	check(visual.bounces[0].light_energy>0.5 and visual.sparks[0].emitting,"Release casts a local light and emits sparks")
	await snap("06_gate_unlock")
	await ticks(33)
	check(gate.leaf.position.y < -0.4 and gate.leaf.position.y > Gate.OPEN_Y and not collision.disabled, "Leaf sinks while still blocking")
	check(collision.global_position.is_equal_approx(closed_center), "The blocking volume stays in place during the descent")
	check(visual.dust.any(func(emitter: CPUParticles3D): return emitter.visible and emitter.emitting),"Threshold releases a limited dust burst")
	await snap("07_gate_lowering")
	await ticks(52)
	check(is_equal_approx(gate.leaf.position.y,Gate.OPEN_Y) and collision.disabled and not gate.panel.visible, "Open leaf is fully stowed beneath the threshold")
	check(is_equal_approx(float(visual.trace.get_shader_parameter("charge")),0.12), "Open frame settles to a soft glow")
	await snap("08_gate_open")
	scene.reset_level()
	await ticks(6)
	check(geometry(scene) == original and is_zero_approx(float(visual.trace.get_shader_parameter("charge"))), "Reset restores the original collision and idle gate light")
	gate.set_open_state(true)
	await ticks()
	check(is_equal_approx(float(visual.trace.get_shader_parameter("charge")),0.12) and collision.disabled, "Configured open state has the same quiet finish")
	scene.queue_free()
	await ticks()
	print("MAZE 01 DREAM ART: ", "PASS" if failures == 0 else "FAIL", " (",failures," failures), geometry=",original.size(),", roles=",counts)
	quit(failures)

func check_chapel_windows(hall: Node3D, actor: CharacterBody3D) -> void:
	var windows := hall.find_children("ArchedWindow*", "Node3D", false, false)
	var masonry: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in hall.find_children("*", "MeshInstance3D", true, false):
		var part: String = mesh.get_meta("greybox_part", "")
		if part.begins_with("CurvedWall") or part == "PorchWall":
			masonry.append(mesh)
	check(windows.size() == 5, "The pavilion keeps five arched windows")
	var motifs := 0
	for window: Node3D in windows:
		var a := window.to_global(Vector3(0.19, 1.82, -0.53))
		var b := window.to_global(Vector3(0.19, 1.82, 0.53))
		check(not crosses_wall(masonry, a, b), "Masonry is open through " + str(window.name))
		check(crosses_wall(masonry, a + Vector3.UP * 1.50, b + Vector3.UP * 1.50), "Masonry closes above each arch")
		var ray := PhysicsRayQueryParameters3D.create(a, b, 1)
		check(not actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Window remains impassable")
		var pane: ShaderMaterial = window.get_node("WindowPane").material_override
		check(pane.get_shader_parameter("clear_glass") == Finish.Roof.albedo_color, "Glass and roof share the lake-blue base color")
		if pane.get_shader_parameter("flower") == true:
			motifs += 1
	check(motifs == 1, "A single window carries the flower motif")

func crosses_wall(meshes: Array[MeshInstance3D], start: Vector3, end: Vector3) -> bool:
	for mesh: MeshInstance3D in meshes:
		var a := mesh.to_local(start)
		var b := mesh.to_local(end)
		if mesh.mesh.get_aabb().intersects_segment(a, b) == null:
			continue
		var faces := mesh.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			if Geometry3D.segment_intersects_triangle(a, b, faces[i], faces[i+1], faces[i+2]) != null:
				return true
	return false

func check_fish(school: Node3D, water: float) -> void:
	check(school.get_child_count() == 3, "H5 has three fish")
	for t in 48:
		for fish: Node3D in school.get_children():
			var point := fish.position
			var bottom := Layout.courtyard_height(Vector2(point.x, point.z))
			check(point.y + 0.075 < water and point.y - 0.075 > bottom, "The full fish stays submerged, above the floor")
		school._process(0.53)
