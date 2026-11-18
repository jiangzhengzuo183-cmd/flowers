extends "res://modules/maze03_final/check_final.gd"
func run() -> void:
	root.size = Vector2i(1600,900)
	folder = "res://../.verification/maze03-pool-revision"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	scene = Third.instantiate()
	root.add_child(scene)
	actor = scene.get_node("%Player")
	generator = scene.get_node("%GeneratedMaze")
	await ticks(16)
	scene.play_view.set_mode(1)
	scene.set_walk_mode(true)
	scene.earthquakes.next_event = 99999.0
	scene.earthquakes.minor_next = 99999.0
	var movement := Camera3D.new()
	actor.get_parent().add_child(movement)
	actor.movement_camera = movement
	var boundary: Node3D = generator.architecture.get_node("StreamlinedPoolBoundary")
	check(int(boundary.get_meta("corridor_connections"))>=4 and int(boundary.get_meta("corridor_connections"))<=5,"Only four or five selected original corridor dividers join the shoreline")
	for spec: Array in [[Vector3(14.8,0,18.0),KEY_D,0,15.3,false],[Vector3(16.6,-0.40,18.0),KEY_A,0,15.9,true],[Vector3(33.05,0,21.4),KEY_A,0,32.7,true],[Vector3(20.4,0,13.6),KEY_S,2,14.1,false],[Vector3(28.2,0,32.05),KEY_W,2,31.5,true],[Vector3(14.9,0,25.4),KEY_S,2,26.1,false]]:
		await place(spec[0])
		key(spec[1],true)
		key(KEY_SHIFT,true)
		await ticks(75)
		key(spec[1],false)
		key(KEY_SHIFT,false)
		check(actor.position[spec[2]]>spec[3] if spec[4] else actor.position[spec[2]]<spec[3],"Shore/corridor shortcut physically blocked from "+str(spec[0])+" actual="+str(actor.position))
	# Jumping cannot clear the waist-high guard.
	await place(Vector3(14.8,0,18.0))
	key(KEY_D,true)
	key(KEY_SPACE,true)
	await ticks(8)
	key(KEY_SPACE,false)
	await ticks(65)
	key(KEY_D,false)
	check(actor.position.x<15.3,"Low guard also blocks the normal jump shortcut")
	for id: String in generator.ENTRY_REMOVED_WALLS:
		check(not generator.get_node("HorizontalWalls").has_node(id),"Entry obstruction entirely removed "+id)
	for x: float in [1.2,3.6]:
		check(ray(Vector3(x,0.6,46),Vector3(x,0.6,45.2)).is_empty(),"No hidden collider remains at the removed entry wall")
	for path: Array in generator.sanctuary.routes:
		await place(path[0])
		await walk_to(path[1],"Walk staggered rounded pads without jump",true)
		check(actor.position.y>-0.08,"Rounded stepping path finishes on the temple floor")
	for corner: Vector3 in [Vector3(15.72,0,14.52),Vector3(32.28,0,14.52),Vector3(15.72,0,31.08),Vector3(32.28,0,31.08)]:
		var hit := ray(corner+Vector3.UP,corner-Vector3.UP)
		check(not hit.is_empty() and absf(hit.position.y)<0.01,"All four outside rounded corners have dry walkable floor "+str(corner))
	for path: Array in generator.sanctuary.routes:
		await place(path[0])
		await walk_to(path[1],"Normal walking across the smaller separated stones",false)
	var pad: Node3D = generator.sanctuary.pads[2]
	check(pad.get_meta("rounded_footprint").size()>=12,"Stepping stones have actual rounded irregular collision footprints")
	await view("pool_top",Vector3(24,34,22.9),Vector3(24,0,22.8))
	await view("rounded_stones",Vector3(29.2,3.7,33.2),Vector3(24,0.4,27.8))
	await view("shore_and_reconnected_walls",Vector3(11.6,8.0,31.8),Vector3(16.1,0.4,23.5))
	var cube: Node3D = generator.sanctuary.get_node("HoveringBlueCube")
	cube.set_process(false)
	cube.rotation.y = 0.2
	await view("solid_cube",Vector3(24,1.45,25.6),Vector3(24,1.22,22.8))
	await place(Vector3(24.85,0,23.1))
	await view("cube_charlie_scale",Vector3(24,1.6,25.8),Vector3(24.4,1.3,22.8))
	var indoor_camera := Camera3D.new()
	actor.get_parent().add_child(indoor_camera)
	indoor_camera.fov = 65
	indoor_camera.look_at_from_position(Vector3(24,1.6,25.6),Vector3(24.3,1.3,22.6))
	indoor_camera.make_current()
	await ticks(45)
	await shot("interior_lighting_final")
	check(indoor_camera.environment!=null and indoor_camera.environment.ambient_light_energy<0.30,"Interior ambient light softens independently of surface color")
	var floor_visual: MeshInstance3D = generator.sanctuary.get_node("SanctuaryFoundation").get_child(0)
	check(floor_visual.material_override is ShaderMaterial and floor_visual.material_override.shader==preload("res://modules/maze03_final/wall_finish.gdshader"),"Original pale foundation material is preserved; no dark replacement")
	indoor_camera.free()
	cube.set_process(true)
	await place(Layout.cell_point([18,0]))
	var rig: Node3D = scene.get_node("%FollowRig")
	actor.movement_camera = rig.camera
	rig.manual_pitch = true
	rig.pitch = 0.36
	rig.yaw = 0.0
	rig.distance = 4.2
	rig.camera.make_current()
	await ticks(20)
	await shot("entry_charlie_view")
	await view("entry_wall_removed",Vector3(4.2,3.5,49.0),Vector3(1.2,0.7,43.3))
	await view("pool_northwest_corner",Vector3(13.5,2.3,16.2),Vector3(16.2,0.2,14.8))
	await view("pool_northeast_corner",Vector3(34.8,2.3,16.2),Vector3(31.8,0.2,14.8))
	await view("pool_southwest_corner",Vector3(13.5,2.3,29.4),Vector3(16.2,0.2,30.8))
	await view("pool_southeast_corner",Vector3(34.8,2.3,29.4),Vector3(31.8,0.2,30.8))
	var directions := [[Vector3(23,3.5,8),Vector3(24,34,-260)],[Vector3(42,3.8,24),Vector3(260,34,30)],[Vector3(23,3.8,42),Vector3(5,32,280)],[Vector3(4,3.8,24),Vector3(-240,32,15)]]
	for i in directions.size():
		await view("depth_direction_"+str(i),directions[i][0],directions[i][1])
	print("POOL REVISION ","PASS" if failures==0 else "FAIL"," failures=",failures)
	scene.queue_free()
	await process_frame
	await process_frame
	quit(failures)




