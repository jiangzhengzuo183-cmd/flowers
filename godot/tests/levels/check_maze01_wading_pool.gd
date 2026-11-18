extends "res://tests/levels/check_maze_01_greybox.gd"

const Level := preload("res://scenes/levels/maze_01_greybox.tscn")

func capture(id: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../.verification/maze01-pool-glow")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(id+".png"))==OK,"Capture "+id)

func run() -> void:
	Input.use_accumulated_input = false
	root.size = Vector2i(1440,1000)
	scene = Level.instantiate()
	root.add_child(scene)
	actor = scene.get_node("%Player")
	generator = scene.get_node("%GeneratedMaze")
	var garden: Node3D = generator.architecture.get_node("NorthwestCourtyard")
	var water: MeshInstance3D = garden.get_node("WadingPoolSurface")
	var splashes: Array[String] = []
	water.child_entered_tree.connect(func(child: Node) -> void:
		if child is CPUParticles3D:
			splashes.append(str(child.name))
	)
	var spec: Dictionary = Layout.config().northwest
	check(is_equal_approx(float(spec.waterSurface) - float(spec.minimum), 0.29), "The lower basin is 29 cm deep")
	check(water.material_override is ShaderMaterial and water.find_children("*", "CollisionObject3D", true, false).is_empty(),"Independent animated water surface has no collision")
	var water_is_level := true
	for vertex: Vector3 in water.mesh.get_faces():
		water_is_level = water_is_level and is_equal_approx(vertex.y,float(spec.waterSurface))
	check(water_is_level and water.mesh.get_aabb().size.x>4.0,"Level water spans the original lower court")
	check(not garden.has_node("DryFlowerbed"),"Old solid flowerbed is gone")
	for offset: float in [-0.75,0.0,0.75]:
		check(is_equal_approx(Layout.courtyard_height(Vector2(3.6+offset,9.6)),-0.30),"Pool stair spans the opening")
		check(is_equal_approx(Layout.courtyard_height(Vector2(6.0+offset,9.6)),0.45),"Gallery stair spans the opening")
	var follow = scene.get_node("%FollowRig")
	scene.inspect_location(7)
	await ticks(20)
	check(actor.position.y>float(spec.waterSurface),"Charlie starts on dry ground")
	await walk_to(Layout.cell_point([4,0]),"Enter water from the southwest stair",false)
	check(actor.is_on_floor() and absf(actor.position.y-float(spec.minimum))<0.03,"Charlie stands on the pool bottom")
	await walk_to(Layout.cell_point([4,1]),"Wade across the lower pool",false)
	check(actor.is_on_floor() and actor.position.y<float(spec.waterSurface)-0.1,"Charlie crosses through the water while standing on the bottom")
	var ripples: PackedVector4Array = water.material_override.get_shader_parameter("step_ripples")
	var active_steps := 0
	for ripple in ripples:
		if ripple.w > 0.0 and ripple.z < 0.95:
			active_steps += 1
	check(active_steps > 0, "Wading leaves short-lived surface ripples")
	key(KEY_SPACE,true)
	await ticks(1)
	key(KEY_SPACE,false)
	await ticks(10)
	check(splashes.any(func(id: String) -> bool: return id.begins_with("SplashTakeoff")), "Jumping out of the pool throws water")
	await capture("05_water_takeoff")
	await ticks(17)
	check(splashes.any(func(id: String) -> bool: return id.begins_with("SplashLanding")), "Crossing the water surface on landing throws water")
	await capture("06_water_landing")
	await ticks(10)
	await walk_to(Vector3(3.6,0,12),"Reach the old flowerbed crossing",false)
	await walk_to(Vector3(2.4,0,12),"Walk directly through the former obstruction",false)
	check(actor.is_on_floor() and absf(actor.position.y-float(spec.minimum))<0.03,"Former raised obstruction is now walkable")
	var flat: Dictionary = ray(Vector3(2.4,0.25,12.0),Vector3(2.4,-0.9,12.0))
	check(not flat.is_empty() and absf(float(flat.position.y)-float(spec.minimum))<0.01,"The original flowerbed footprint has a flat, open bottom")
	await walk_to(Vector3(3.6,0,12),"Return to the main wading lane",false)
	follow.yaw = 0.40
	follow.pitch = 0.58
	await ticks(18)
	await capture("01_charlie_in_water")
	follow.yaw = 0.0
	await walk_to(Layout.cell_point([5,1]),"Continue through the other pool arm",false)
	await walk_to(Layout.cell_point([5,0]),"Walk out along the second stair",false)
	check(actor.is_on_floor() and absf(actor.position.y)<0.03,"Charlie walks back onto dry ground without jumping")
	await walk_to(Layout.cell_point([4,0]),"Re-enter water in the opposite direction")
	await walk_to(Layout.cell_point([4,1]),"Run across the pool")
	check(splashes.any(func(id: String) -> bool: return id.begins_with("SplashRun")), "Running footsteps throw droplets")
	await walk_to(Layout.cell_point([3,1]),"Exit via the north stair")
	check(actor.is_on_floor() and absf(actor.position.y)<0.03,"North exit reconnects to the dry bypass")
	await walk_to(Layout.cell_point([3,2]),"Reach the elevated gallery approach")
	await walk_to(Layout.cell_point([4,2]),"Ascend to the gallery")
	await walk_to(Layout.cell_point([5,2]),"Cross the flat upper gallery")
	check(actor.is_on_floor() and absf(actor.position.y-float(spec.maximum))<0.03,"The gallery stays at its original upper height")
	await walk_to(Layout.cell_point([5,3]),"Cross the gallery landing",false)
	await walk_to(Layout.cell_point([4,3]),"Walk down the gallery stairs",false)
	check(actor.is_on_floor() and absf(actor.position.y)<0.03,"Gallery stairs connect back to the ground")
	follow.yaw = PI
	follow.pitch = 0.49
	follow.distance = 3.2
	await ticks(20)
	await capture("04_gallery_stairs")
	scene.inspect_location(18)
	var rig = scene.get_node("%CameraRig")
	rig.center = Vector3(3.6,0.45,11.1)
	rig.world_size = Vector3(9.6,4.5,8.0)
	rig.yaw = -0.75
	rig.pitch = 0.88
	rig.zoom = 1.10
	rig._update_camera()
	await ticks(18)
	await capture("02_courtyard")
	if OS.get_cmdline_user_args().has("--capture"):
		var first := root.get_texture().get_image()
		await ticks(42)
		await capture("03_water_motion")
		var second := root.get_texture().get_image()
		var changes := 0
		for y in range(0,first.get_height(),3):
			for x in range(0,first.get_width(),3):
				var a := first.get_pixel(x,y)
				var b := second.get_pixel(x,y)
				if a.g>a.r+0.10 and a.b>a.r+0.10 and absf(a.g-b.g)>0.009:
					changes += 1
		check(changes>60,"Water visibly changes under a stationary real camera (%d changed water samples)"%changes)
	scene.queue_free()
	await process_frame
	print("H5 WADING POOL: ","PASS" if failures==0 else "FAIL"," (",failures," failures)")
	quit(failures)
