extends "res://tests/levels/check_maze_01_greybox.gd"
const Third := preload("res://scenes/levels/Maze03.tscn")
const First := preload("res://scenes/levels/maze_01_greybox.tscn")
var folder := "res://../.verification/maze03-middle-axis-functional"
var frame_samples: Array[float] = []

func shot(id: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder.path_join(id+".png")))

func view(id: String, point: Vector3, aim: Vector3) -> void:
	var camera := Camera3D.new()
	actor.get_parent().add_child(camera)
	camera.far = 500
	camera.fov = 52
	camera.look_at_from_position(point,aim)
	camera.make_current()
	await ticks(4)
	await shot(id)
	camera.free()
	scene.get_node("%FollowRig").camera.make_current()

func place(point: Vector3) -> void:
	actor.position = point + Vector3.UP * 0.03
	actor.velocity = Vector3.ZERO
	await ticks(8)

func run() -> void:
	root.size = Vector2i(1440,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	scene = First.instantiate()
	root.add_child(scene)
	actor = scene.get_node("%Player")
	await ticks(10)
	var original_map: Dictionary = scene.maze_data.duplicate(true)
	var original_walls: int = scene.get_node("%GeneratedMaze/VerticalWalls").get_child_count() + scene.get_node("%GeneratedMaze/HorizontalWalls").get_child_count()
	scene.show_top_view()
	await ticks(3)
	await shot("maze01_top")
	scene.queue_free()
	await process_frame
	scene = Third.instantiate()
	root.add_child(scene)
	actor = scene.get_node("%Player")
	generator = scene.get_node("%GeneratedMaze")
	await ticks(12)
	check(scene.loaded_ok, "Finished-based scene loads")
	var horizon := actor.get_parent().get_node("FinalTrialHorizon")
	var enclosure := horizon.get_node("WhiteMegastructureEnclosure")
	check(enclosure.focal_count==6 and enclosure.secondary_count==0 and enclosure.connector_count==0 and enclosure.near_count==0,"Only the six approved primary forms remain; extra intermediate slabs and spokes are absent")
	check(enclosure.closest_extent>90.0,"All solid scenery leaves at least 90m from maze centre, beyond the playable bounds")
	var low_disc: Node3D = enclosure.middle.get_node("NorthwestRaisedDisc")
	for group: Node3D in enclosure.middle.get_children():
		if group!=low_disc:
			check(float(low_disc.get_meta("top_altitude"))<float(group.get_meta("top_altitude")),"The waisted disc is lower than every other primary megastructure")
	var disc_bounds: AABB = low_disc.get_node("ContinuousWhiteVolume").get_aabb()
	check(disc_bounds.size.y/disc_bounds.size.x<0.36,"Disc has a low horizontal profile matching the selected reference proportions")
	check(enclosure.glazing_count==2,"Two glazing areas follow the recessed slit and original disc window band")
	check(enclosure.middle.has_node("SouthwestConnectedTwins") and not enclosure.middle.has_node("SouthwestOpenBowl"),"Congress reference is the connected twin slabs, not a bowl")
	var distances: Array[float] = []
	var heights: Array[float] = []
	for group: Node3D in enclosure.middle.get_children():
		distances.append(float(group.get_meta("centre_distance")))
		heights.append(float(group.get_meta("top_altitude")))
	check(distances.max()-distances.min()>45.0 and heights.max()-heights.min()>50.0,"Primary silhouettes have deliberate front/back distances and high/low skyline")
	var wind := horizon.get_node("TrialAtmosphere/HighAltitudeWind")
	check(wind.streak_count==44 and wind.get_child_count()==2,"World-space wind retains two bounded batches at the previously approved density")
	check(wind.find_children("*","CollisionObject3D",true,false).is_empty(),"Wind adds no force or collision to the player")
	var wind_audio := scene.sound.get_node("WindAmbience") as AudioStreamPlayer
	check(wind_audio.playing and wind_audio.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Existing wind bed starts as a scene-local loop")
	scene.sound.set_muted(true)
	await ticks(2)
	check(not wind_audio.playing,"Existing mute control stops the wind ambience")
	scene.sound.set_muted(false)
	await ticks(2)
	check(wind_audio.playing,"Unmuting resumes wind without adding duplicate players")
	wind_audio.seek(wind_audio.stream.get_length()-0.1)
	await ticks(14)
	check(wind_audio.playing,"Wind ambience continues over its loop boundary")
	check(horizon.roofs_simplified==17,"Outer district roof caps simplified without changing the source assets")
	check(not enclosure.has_node("MiddleDistanceVolumes"),"Rejected eight extra giant slabs are absent")
	var ring_axis: Node3D = enclosure.get_node("RingAxisLight")
	check(ring_axis.beam_count==3 and ring_axis.position.is_equal_approx(enclosure.get_node("SlowMegastructureMotion").pieces[0].origin),"Broad white-blue column is centered in the curved megastructure")
	var warm: SpotLight3D = ring_axis.regional_light
	check(enclosure.find_children("*","Light3D",true,false).size()==1 and not warm.shadow_enabled and warm.light_cull_mask==1,"One bounded warm light reaches the maze without adding shadow maps")
	check(warm.global_position.is_equal_approx(Vector3(45,13,0)),"Regional warm light is physically near the maze rather than stranded in distant scenery")
	var local_lanes: MeshInstance3D = wind.get_node("AcrossMaze")
	check(local_lanes.get_aabb().position.y<1.4,"Straight wind includes lanes at the actual character viewing height")
	check(absf(wind.local_material.get_shader_parameter("wind_direction").y)<0.001,"Wind direction is horizontal")
	check(generator.sanctuary.reflection_camera.cull_mask & 24 == 24,"New megastructures are included in the mirror reflection")
	for mesh: MeshInstance3D in enclosure.find_children("*","MeshInstance3D",true,false):
		check((mesh.material_override is ShaderMaterial and mesh.material_override.shader==preload("res://modules/maze03_final/geometric_stone.gdshader")) or (mesh.material_override is ShaderMaterial and mesh.material_override.shader==preload("res://modules/maze03_final/distant_glazing.gdshader")) or (mesh.material_override is ShaderMaterial and mesh.material_override.shader==preload("res://modules/maze03_final/ring_axis.gdshader")) or mesh.name==&"LowFoundationCloud","Simple volumes use opaque lit stone with aerial perspective")
	for mesh: MeshInstance3D in enclosure.find_children("ContinuousWhiteVolume","MeshInstance3D",true,false):
		check(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Remote masses cannot cast shadows across the playable maze")
		check(mesh.material_override.get_shader_parameter("sun_direction").is_equal_approx(actor.get_parent().get_node("Sun").global_basis.z),"Distant form shading follows the unchanged scene sun")
	check(enclosure.find_children("*","CollisionObject3D",true,false).is_empty(),"Horizon architecture introduces no collision")
	check(horizon.depth_counts == [8,0,9],"Seventeen original outer districts retained behind the new simple volumes")
	check(horizon.silhouette_count==17 and horizon.inlay_count==0,"Seventeen layered districts retained; all rejected guidance panels removed")
	check(horizon.get_node("TrialAtmosphere").sky_track_count==0,"Rejected floating sky arcs removed")
	check(horizon.get_node("TrialAtmosphere").cloud_count == 10,"Cloud ocean has depth and banks hiding the foundations")
	check(horizon.get_node("TrialAtmosphere").mist_count == 9,"Nine independent broad patches of drifting air")
	check(generator.architecture.get_node("NorthwestCourtyard/LayeredRibbonCourt").find_children("ContinuousRibbon*","StaticBody3D",true,false).size()==3,"Three continuous curved canopy ribbons replace radial slices")
	check(scene.maze_data.grid == original_map.grid and scene.maze_data.openings == original_map.openings and scene.maze_data.routes.A == original_map.routes.A, "Original grid, entry, exit and A route retained")
	check(generator.gates.is_empty() and generator.barriers.size() == 6, "Four original thresholds and two added B-route barriers without gate leaves")
	check(generator.removed_south_bridge == 4, "All four H4 bridge pieces removed")
	for node: Node3D in generator.architecture.get_children():
		for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",false,false):
			var part := str(mesh.get_meta("greybox_part",""))
			var center: Vector3 = generator.architecture.to_local(mesh.to_global(mesh.get_aabb().get_center()))
			var old_bridge_area := center.x > 20.6 and center.x < 26.4 and center.z > 27.4 and center.z < 31.2
			check(not (old_bridge_area and (part == "Tread" or part.begins_with("GuardRail") or part.begins_with("H4_"))), "No old southern bridge treads or rails remain " + part)
	check(generator.architecture.has_node("SunkenCorridor") and generator.architecture.has_node("NorthwestCourtyard"), "Both original sunken structures retained")
	var walls: int = generator.get_node("VerticalWalls").get_child_count()+generator.get_node("HorizontalWalls").get_child_count()
	check(walls + generator.removed_walls == original_walls, "Every removed wall is accounted for by the approved pool, northwest or shortcut changes")
	for group_name: String in ["VerticalWalls","HorizontalWalls"]:
		for wall: Node3D in generator.get_node(group_name).get_children():
			var mesh := wall.get_child(0) as MeshInstance3D
			check(mesh.material_override.shader==preload("res://modules/maze03_final/wall_finish.gdshader"),"All retained ordinary wall faces use the same scene-local finish")
			check(scene.wall_occlusion._collider_groups.has(wall.get_instance_id()),"Opaque and faded walls are registered with matching color")
			var bounds := mesh.get_aabb()
			var a: Vector3 = mesh.to_global(bounds.position)
			var b: Vector3 = mesh.to_global(bounds.end)
			var footprint := Rect2(Vector2(minf(a.x,b.x),minf(a.z,b.z)),Vector2(absf(a.x-b.x),absf(a.z-b.z)))
			check(wall.get_meta("pool_join",false) or not footprint.intersects(generator.sanctuary.POOL.grow(0.745)),"Only the four planned original dividers join the shoreline")
	check(generator.northwest_removed_wall_count>0,"Straight walls below the northwest roof were actually removed")
	check(generator.shortcut_count == 3, "Three new passage openings remove actual pre-existing walls")
	check(generator.sanctuary.rib_count >= 120, "New sanctuary has structural fins")
	for point: Vector3 in [Vector3(1.2,0,10.8),Vector3(3.6,0,21.6)]:
		var hit := ray(point+Vector3.UP*2, point+Vector3.DOWN*2)
		check(not hit.is_empty() and (absf(hit.position.y)<0.02 if point.x < 2.0 else hit.position.y < -0.3), "Flat northwest court and retained sunken corridor have correct heights " + str(point))
	check(not generator.architecture.get_node("NorthwestCourtyard").has_node("WadingPoolSurface"), "Old basin water removed while terrain stays")
	for node in generator.architecture.get_node("SunkenCorridor").get_children():
		check(not str(node.name).begins_with("Niche"), "All three niche recesses removed")
	for mesh: MeshInstance3D in generator.sanctuary.find_children("*","MeshInstance3D",true,false):
		check(not mesh.mesh is TorusMesh, "No raised decorative ring at sanctuary roof")
	for offset in [Vector3(0,0,-1),Vector3(0,0,1)]:
		check(ray(Vector3(24,0.9,22.8)+offset*4,Vector3(24,0.9,22.8)+offset*2.8).is_empty(), "Centered north/south entrance is clear")
	for offset in [Vector3(-1,0,0),Vector3(1,0,0)]:
		check(not ray(Vector3(24,0.9,22.8)+offset*4,Vector3(24,0.9,22.8)+offset*2.8).is_empty(), "East/west sanctuary wall remains closed")
	check(generator.sanctuary.pads.size() == 10 and generator.sanctuary.routes.size() == 2, "Ten small separated stepping slabs serve the two original centered entrances")
	check(scene.find_children("*", "Node", true, false).filter(func(n): return str(n.name) == "MazeItems").is_empty(), "No item system instantiated")
	scene.play_view.set_mode(1)
	await ticks(3)
	check(not scene.get_node("Heading").visible and not scene.get_node("WalkControls").visible, "F10 play-only hides both toolbars")
	await shot("play_only")
	scene.play_view.set_mode(2)
	await ticks(2)
	check(scene.get_window().mode == Window.MODE_FULLSCREEN or DisplayServer.get_name()=="headless", "F11 requests fullscreen")
	scene.play_view.set_mode(0)
	check(scene.get_node("Heading").visible, "Exit restores chrome")
	# Run across one original energy doorway with actual physics and key input.
	var movement_camera := Camera3D.new()
	actor.get_parent().add_child(movement_camera)
	actor.movement_camera = movement_camera
	for spec: Dictionary in generator.EXTRA_BARRIERS:
		var extra: Area3D = generator.architecture.get_node("EnergyFrame_"+spec.id+"/"+spec.id)
		var a := Layout.cell_point(spec.edge[0])
		var b := Layout.cell_point(spec.edge[1])
		await place(a)
		actor.boost_remaining = 0.0
		await walk_to(b,"Added B-route threshold "+spec.id,true)
		check(actor.boost_remaining>0.0,"New B-route barrier applies boost "+spec.id)

	var gate: Node3D = generator.barriers[0].get_parent()
	var start: Vector3 = gate.to_global(Vector3(0,0,1.6))
	start.y = gate.global_position.y
	await place(start)
	var code := KEY_W if absf(gate.global_basis.z.z) > 0.5 else KEY_A
	if (gate.global_position-start).dot(Vector3.FORWARD if code == KEY_W else Vector3.LEFT) < 0:
		code = KEY_S if code == KEY_W else KEY_D
	key(code,true)
	key(KEY_SHIFT,true)
	await ticks(44)
	key(code,false)
	key(KEY_SHIFT,false)
	check(actor.boost_remaining > 0 and actor.boost_remaining <= 3.0, "Passing through barrier starts three-second boost")
	await shot("barrier_crossing")
	check(actor.speed_ribbons.stamp_count>0,"Boost produces frozen character poses on actual movement")
	check(generator.barriers[0].pulse>0.0,"Actual crossing triggers luminous barrier pulse")
	check(scene.sound.barrier_whoosh!=null,"Crossing uses independent whoosh without restarting music")
	await view("barrier_detail",gate.to_global(Vector3(0,1.7,1.7)),gate.to_global(Vector3(0,1.2,0)))
	actor.apply_boost()
	await ticks(8)
	actor.apply_boost()
	check(actor._movement_modifier() == 1.35, "Repeated trigger refreshes without stacking")
	await ticks(190)
	check(actor._movement_modifier() == 1.0, "Boost restores base speed")
	check(scene.footprints._lifetimes.size() == 12 , "Finished footprint pool installed")
	var music := scene.sound.get_node("Music") as AudioStreamPlayer
	check(music.playing and music.stream is AudioStreamMP3 and music.stream.loop, "Dedicated downloaded music plays with loop enabled")
	music.seek(maxf(0.0,music.stream.get_length()-0.05))
	await ticks(5)
	check(music.playing, "Music stays playing after barrier interaction and end-of-track seek")
	for path: Array in generator.sanctuary.routes:
		await place(path[0])
		await walk_to(path[1], "Separated slabs " + str(path[0]), true)
	check(actor.position.y > -0.15, "Stepping slabs remain walkable without repeated jumps")
	# Walk the actual original B cells through the changed sanctuary region.
	var central_b: Array = [[5,10],[5,9.5],[5.375,9.5],[6,9.5],[7,9.5],[8,9.5],[9,9.5],[10,9.5],[11,9.5],[12,9.5],[12.833333,9.5],[12.833333,13.25],[11,13.25],[10,13.25],[9,13.25],[9,14]]
	await place(Layout.cell_point(central_b[0]))
	for i in range(1, central_b.size()):
		await walk_to(Layout.cell_point(central_b[i]), "Original B sanctuary cell " + str(central_b[i]), true)
	# Establish that running still produces actual footprints, not just an installed pool.
	await place(Vector3(37.2,0,15.9))
	# This check measures running footprints, so establish enough stamina to run.
	actor.stamina.restore(actor.stamina.settings.maximum, &"footprint_test")
	key(KEY_D,true)
	key(KEY_SHIFT,true)
	await ticks(25)
	key(KEY_D,false)
	key(KEY_SHIFT,false)
	check(actor.stamina.is_sprinting and scene.footprints._next_mark > 0, "Running produces the finished character's footprint marks")
	await shot("footprints")
	if OS.get_cmdline_user_args().has("--routes"):
		for route_id in ["A","B"]:
			var cells: Array = scene.maze_data.routes[route_id].cellPath
			await place(Layout.cell_point(cells[0]))
			for i in range(1,cells.size()):
				var goal := Layout.cell_point(cells[i])
				if not await walk_to(goal,route_id+" cell "+str(cells[i]),true):
					break
	for spec in generator.SHORTCUTS:
		var a: Array = [spec[1],spec[2]-1] if spec[0] == "v" else [spec[1]-1,spec[2]]
		var b: Array = [spec[1],spec[2]]
		await place(Layout.cell_point(a))
		await walk_to(Layout.cell_point(b), "New shortcut " + str(spec), true)
	scene.show_top_view()
	await ticks(3)
	await shot("maze03_top")
	scene.select_route("B")
	await shot("maze03_route_b")
	scene.select_route("A")
	await shot("maze03_route_a")
	scene.select_route("none")
	# Test actual water entry, continuous running, takeoff and landing.
	scene.set_walk_mode(true)
	actor.movement_camera = movement_camera
	var pool: Rect2 = generator.sanctuary.POOL
	# Side banks intentionally terminate at the restored corridor dividers.
	# Return to shore through an actual entrance, not through a forbidden pool side.
	await place(Vector3(25.0,-0.36,pool.position.y+0.55))
	await walk_to(Vector3(25.0,0,pool.position.y-0.7),"Walk from shallow water through the north shore opening",true)
	check(actor.position.y>-0.05,"Underwater entrance ramp permits walking back onto shore")
	var water_effect: Node = generator.sanctuary.get_node("ReflectiveRingWater/FootstepRipples")
	await place(Vector3(28.2,-0.40,24.5))
	key(KEY_W,true)
	key(KEY_SHIFT,true)
	await ticks(35)
	key(KEY_W,false)
	key(KEY_SHIFT,false)
	check(water_effect.stamp_count>0 and water_effect.splash_count>0,"Running through the mirror pool produces ripples and splashes")
	var splash_before: int = water_effect.splash_count
	key(KEY_SPACE,true)
	await ticks(10)
	key(KEY_SPACE,false)
	await view("water_takeoff",Vector3(31.4,1.5,25.2),actor.position+Vector3.UP*0.35)
	await ticks(45)
	check(water_effect.splash_count>splash_before,"Jumping in water triggers takeoff and landing splashes")
	await view("water_interaction",Vector3(31.4,1.5,25.2),actor.position+Vector3.UP*0.35)
	scene.play_view.set_mode(1)
	await ticks(3)
	await view("overview",Vector3(51,35,53),Vector3(23,1,23))
	await view("sanctuary",Vector3(36,10,37),Vector3(24,4,22.8))
	await view("interior",Vector3(24,1.65,24.7),Vector3(24,6,22.8))
	await view("restored_sunken_garden",Vector3(12,9,17),Vector3(4,-0.1,10))
	await view("restored_sunken_corridor",Vector3(7,4,28),Vector3(3.6,-0.3,20))
	await view("centered_north_entrance",Vector3(24,5,11),Vector3(24,1,21))
	await view("mirror_pool",Vector3(30.7,2.1,30.4),Vector3(24,2,22.8))
	await view("distant_architecture",Vector3(13.2,3,37),Vector3(-35,20,-45))
	scene.set_walk_mode(true)
	await place(Vector3(13.2,0,34.8))
	await ticks(35)
	await shot("charlie_view")
	await view("horizon_northeast",Vector3(38,2.8,12),Vector3(115,34,-109))
	await view("horizon_west",Vector3(8,2.7,25),Vector3(-105,23,-23))
	await view("horizon_southeast",Vector3(38,3,37),Vector3(160,27,110))
	await view("sky_tracks",Vector3(25,3.5,35),Vector3(105,65,-105))
	var samples: Array[float] = []
	if DisplayServer.get_name()!="headless":
		for i in 60:
			var sample_start := Time.get_ticks_usec()
			await process_frame
			samples.append(float(Time.get_ticks_usec()-sample_start)/1000000.0)
		var total := 0.0
		for sample in samples:
			total += sample
		print("RENDER FRAME SAMPLE mean_ms=",total/samples.size()*1000.0," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("MAZE03 FINAL ", "PASS" if failures==0 else "FAIL", " failures=",failures," retained_walls=",walls,"/",original_walls)
	scene.queue_free()
	await process_frame
	# Allow the audio mixer to release queued scene playback before process exit.
	OS.delay_msec(120)
	await process_frame
	quit(failures)








