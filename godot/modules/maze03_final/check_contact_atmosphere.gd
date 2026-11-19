extends "res://modules/maze03_final/check_final.gd"
func run() -> void:
	root.size = Vector2i(1600,900)
	folder = "res://../.verification/maze03-contact-atmosphere"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	scene = Third.instantiate()
	root.add_child(scene)
	actor = scene.get_node("%Player")
	generator = scene.get_node("%GeneratedMaze")
	await ticks(20)
	scene.play_view.set_mode(1)
	await ticks(3)
	var quake: Node3D = scene.earthquakes
	quake.next_event = 99999.0
	quake.minor_next = 99999.0
	var horizon: Node3D = actor.get_parent().get_node("FinalTrialHorizon")
	var enclosure: Node3D = horizon.get_node("WhiteMegastructureEnclosure")
	var wind: Node3D = horizon.get_node("TrialAtmosphere/HighAltitudeWind")
	check(wind.streak_count==44 and wind.get_child_count()==2,"Wind ribbons retain the previous restrained two-batch setting")
	check(wind.local_material.get_shader_parameter("speed")>=20 and wind.high_material.get_shader_parameter("speed")>=30,"World wind has a clear fast horizontal flow")
	check(wind.find_children("*","CollisionObject3D",true,false).is_empty(),"Air adds no collision or force")
	var moon: MeshInstance3D = horizon.get_node("TrialAtmosphere/DistantDaytimeHalfMoon")
	await ticks(2)
	check(absf(moon.global_position.distance_to(moon.get_viewport().get_camera_3d().global_position)-420.0)<0.1,"Day moon maintains distant scale independent of player movement")
	var ring: Node3D = enclosure.middle.get_node("NortheastCurvedMonolith")
	var disc: Node3D = enclosure.middle.get_node("NorthwestRaisedDisc")
	var ring_angle := ring.rotation.y
	var disc_level := disc.position.y
	await view("giant_motion_t0",Vector3(38,3.5,12),Vector3(128,50,-109))
	await ticks(240)
	await view("giant_motion_t4",Vector3(38,3.5,12),Vector3(128,50,-109))
	check(absf(ring.rotation.y-ring_angle)>deg_to_rad(4.0),"Ring continuously rotates enough to read within four seconds")
	check(absf(disc.position.y-disc_level)>0.20,"Disc flotation is visible at its distant scale")
	check(enclosure.closest_extent>90.0,"Larger silhouettes still keep the approved distance buffer")
	var giant_height: AABB = ring.get_node("ContinuousWhiteVolume").get_aabb()
	check(giant_height.size.y>=99.0,"Primary curved monolith has a stronger vertical scale")
	await view("overview",Vector3(57,35,57),Vector3(23,1,23))
	var views := [[Vector3(23,3.5,8),Vector3(24,45,-160)],[Vector3(42,3.8,24),Vector3(180,45,30)],[Vector3(23,3.8,42),Vector3(5,40,210)],[Vector3(4,3.8,24),Vector3(-160,35,15)]]
	for i in views.size():
		await view("world_direction_"+str(i),views[i][0],views[i][1])
	await view("wind_all_maze_t0",Vector3(12,4.6,42),Vector3(35,4.0,10))
	await ticks(18)
	await view("wind_all_maze_t1",Vector3(12,4.6,42),Vector3(35,4.0,10))
	var moon_camera := Vector3(10,3.0,10)
	await view("daytime_half_moon",moon_camera,moon_camera+Vector3(-0.52,0.43,-0.74)*200.0)
	var cube: Node3D = generator.sanctuary.get_node("HoveringBlueCube")
	var initial_cube_yaw := cube.rotation.y
	var low_cube_y: float = cube.position.y
	var high_cube_y: float = cube.position.y
	for sample in 12:
		await ticks(25)
		low_cube_y = minf(low_cube_y,cube.position.y)
		high_cube_y = maxf(high_cube_y,cube.position.y)
	check(absf(cube.rotation.y-initial_cube_yaw)>0.25 and high_cube_y-low_cube_y>0.08,"Central translucent cube floats through its full slow cycle and rotates")
	check(is_equal_approx(cube.pivot.rotation_degrees.x,45.0) and is_equal_approx(cube.pivot.rotation_degrees.z,45.0),"Cube keeps the requested 45-degree tilted pose")
	check(cube.find_children("*","CollisionObject3D",true,false).is_empty(),"Decorative cube does not block movement or add interaction")
	check(generator.sanctuary.get_node("InteriorSunshaftsAndDust/DustInSunlight").amount==38,"Interior floating dust is bounded and independently managed")
	await view("sanctuary_cube_and_sunshafts",Vector3(24,1.6,25.7),Vector3(24.1,0.95,22.8))
	await view("sanctuary_light_and_floor",Vector3(22.4,2.6,25.2),Vector3(24.6,1.8,22.8))
	await view("northwest_refined",Vector3(12.4,2.4,14.2),Vector3(7.0,1.1,10.7))
	await view("pool_edge_details",Vector3(27,1.8,33.0),Vector3(24.8,0.0,29.0))
	var movement := Camera3D.new()
	actor.get_parent().add_child(movement)
	actor.movement_camera = movement
	var frame: Node3D = generator.architecture.get_node("EnergyFrame_B5")
	var barrier: Area3D = frame.get_node("B5")
	check(frame.has_node("RecessedEnergySeat"),"Energy membrane is seated in continuous inset frame liners")
	check(barrier.get_node("FlowingEnergyMembrane").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()>2000,"Membrane has real local deformation geometry")
	await gate_view(frame,"barrier_inset_idle")
	await place(frame.to_global(Vector3(0,0,1.2)))
	actor.boost_remaining = 0.0
	await walk_to(frame.global_position,"Actual front-side shield contact",true)
	await ticks(8)
	check(barrier.membrane_strength>0.85,"Membrane follows a body resting in the plane instead of only playing an entry flash")
	check(actor.boost_remaining>0.0,"Contact retains original automatic boost")
	await gate_view(frame,"barrier_body_contact")
	actor.position = frame.to_global(Vector3(0.33,0,0))
	actor.velocity = Vector3.ZERO
	await ticks(8)
	check(absf(barrier.membrane_target.x-0.33)<0.05,"Contact opening follows the player's lateral position")
	var y_before: float = barrier.membrane_target.y
	key(KEY_SPACE,true)
	await ticks(8)
	key(KEY_SPACE,false)
	check(barrier.membrane_target.y>y_before+0.15,"Contact contour follows an actual jump through the energy surface")
	await gate_view(frame,"barrier_jump_contact")
	await ticks(40)
	await walk_to(frame.to_global(Vector3(0,0,-1.2)),"Actual shield passage to rear",true)
	await ticks(55)
	check(barrier.membrane_strength<0.005,"Membrane recovers and closes after the player leaves")
	check(barrier.local_light.light_energy>=barrier.idle_light_energy-0.001,"Recovery preserves constant environmental blue light")
	await gate_view(frame,"barrier_recovered")
	await walk_to(frame.global_position,"Actual reverse-side shield contact",true)
	await ticks(5)
	check(barrier.push_direction>0.0,"Membrane pushes in the correct direction on reverse passage")
	await walk_to(frame.to_global(Vector3(0,0,1.2)),"Actual reverse-side shield exit",true)
	await ticks(50)
	check(barrier.membrane_strength<0.005,"Reverse passage also recovers without a stuck hole")
	await place(Vector3(10.8,0,10.8))
	var rig: Node3D = scene.get_node("%FollowRig")
	actor.movement_camera = rig.camera
	movement.free()
	rig.manual_pitch = true
	rig.pitch = 0.12
	rig.yaw = 0.65
	rig.distance = 3.2
	rig.camera.make_current()
	quake.reset_run()
	quake.next_event = 99999.0
	quake.minor_next = quake.elapsed+0.02
	await ticks(22)
	check(quake.minor_count==1 and quake.events_started==0 and quake.strength>0.08,"Recurring small tremors are independent of the two large earthquakes")
	await shot("minor_tremor_charlie")
	quake.minor_age = 10.0
	quake.minor_next = quake.elapsed+0.02
	await ticks(22)
	check(quake.minor_count==2 and quake.events_started==0,"More than one small tremor can occur without spending a major event")
	check(quake.planned_events==2,"Every run schedules two major events")
	check(quake.trigger_event(),"Large earthquake still starts")
	await ticks(5)
	check(absf(rig.earthquake_impulse)>0.7,"Large event retains the sudden strong tilt")
	await shot("major_tilt_charlie")
	await ticks(240)
	quake.next_event = quake.elapsed+0.02
	await ticks(10)
	check(quake.events_started==2,"Second large event starts via scheduler")
	await ticks(240)
	check(not quake.trigger_event(),"A third major event is still prohibited")
	scene.reset_walk()
	await ticks(3)
	check(quake.minor_count==0 and quake.events_started==0 and quake.planned_events==2,"Reset clears both small and large event state")
	check(barrier.membrane_strength<0.005 and barrier.touching.is_empty(),"Reset clears membrane contact state")
	print("CONTACT ATMOSPHERE ","PASS" if failures==0 else "FAIL"," failures=",failures)
	scene.queue_free()
	await process_frame
	quit(failures)
func gate_view(frame: Node3D,id: String) -> void:
	var camera := Camera3D.new()
	actor.get_parent().add_child(camera)
	camera.fov = 75
	camera.far = 500
	camera.look_at_from_position(frame.to_global(Vector3(0,1.4,1.86)),frame.to_global(Vector3(0,1.35,0)))
	camera.make_current()
	await ticks(4)
	await shot(id)
	camera.free()
	scene.get_node("%FollowRig").camera.make_current()

