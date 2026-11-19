extends "res://modules/maze03_final/check_final.gd"
func run() -> void:
	root.size = Vector2i(1600,900)
	folder = "res://../.verification/maze03-energy-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	scene = Third.instantiate()
	root.add_child(scene)
	actor = scene.get_node("%Player")
	generator = scene.get_node("%GeneratedMaze")
	await ticks(18)
	scene.play_view.set_mode(1)
	await ticks(4)
	var quake: Node3D = scene.earthquakes
	quake.next_event = 99999.0
	var roof: Node3D = generator.architecture.get_node("NorthwestCourtyard/LayeredRibbonCourt")
	check(not roof.has_node("WestWallCanopyReturn") and not roof.has_node("EastWallCanopyReturn"),"Both blue-marked rectangular roof returns removed")
	for id in ["OuterNorthwestArc","OuterNortheastArc","MiddleSouthArc","InnerNorthArc"]:
		check(roof.has_node(id),"Real curved wall exists "+id)
	check(roof.has_node("SouthCourtWallExtension"),"Yellow-marked wall has a connected extension")
	for wall: Node3D in generator.get_node("HorizontalWalls").get_children():
		if str(wall.name) in ["WallSegment_H_4_4","WallSegment_H_4_5","WallSegment_H_5_4","WallSegment_H_5_5"]:
			check(wall.get_child(0).get_aabb().size.y<1.2,"Green-marked walls do not enclose a tall chute")
	var navigation_camera := Camera3D.new()
	actor.get_parent().add_child(navigation_camera)
	actor.movement_camera = navigation_camera
	await place(Vector3(4.7,0,8.0))
	for point: Vector3 in [Vector3(3.2,0,8.0),Vector3(3.2,0,9.6),Vector3(3.6,0,10.85),Vector3(4.7,0,10.85),Vector3(4.7,0,9.6)]:
		await walk_to(point,"Three-ring inner court access "+str(point),true)
	var court_rig: Node3D = scene.get_node("%FollowRig")
	court_rig.manual_pitch = true
	court_rig.pitch = 0.16
	court_rig.distance = 2.7
	court_rig.yaw = -0.5
	court_rig.camera.make_current()
	await ticks(10)
	await shot("northwest_charlie")
	actor.movement_camera = court_rig.camera
	navigation_camera.free()
	var b5: Node3D = generator.architecture.get_node("EnergyFrame_B5")
	var g3: Node3D = generator.architecture.get_node("G3")
	check(b5.position.distance_to(g3.position)>4.0,"B5 no longer forms two consecutive doorways beside G3")
	var enclosure: Node3D = actor.get_parent().get_node("FinalTrialHorizon/WhiteMegastructureEnclosure")
	var motion: Node = enclosure.get_node("SlowMegastructureMotion")
	var ring: Node3D = enclosure.middle.get_node("NortheastCurvedMonolith")
	var disc: Node3D = enclosure.middle.get_node("NorthwestRaisedDisc")
	var before_yaw := ring.rotation.y
	var before_height := disc.position.y
	await ticks(90)
	check(absf(ring.rotation.y-before_yaw)>0.001 and absf(disc.position.y-before_height)>0.02,"Ring slowly turns and low disc subtly floats")
	var ascent: CPUParticles3D = enclosure.get_node("RingAxisLight/DenseBlueAscent")
	check(ascent.amount==256 and ascent.emitting and ascent.direction==Vector3.UP,"Dense blue particles rise beside the giant axis")
	check(ascent.find_children("*","Light3D",true,false).is_empty(),"Ascent particles add no individual lights")
	check(generator.architecture.get_node("ShortCorridorEnergyInsets").strip_count==4,"Four short architectural insets, not a continuous navigation route")
	await view("overview",Vector3(57,35,57),Vector3(23,1,23))
	await view("northwest_roof",Vector3(15,12,19),Vector3(5.3,0.7,10.2))
	for ribbon: Node3D in roof.get_children():
		if str(ribbon.name).begins_with("ContinuousRibbon"):
			ribbon.hide()
	await view("northwest_arc_layout",Vector3(12,11,16),Vector3(4.8,0.3,9.7))
	for ribbon: Node3D in roof.get_children():
		if str(ribbon.name).begins_with("ContinuousRibbon"):
			ribbon.show()
	await view("northwest_transition",Vector3(12.4,2.4,14.2),Vector3(7.0,1.1,10.7))
	await view("ring_particles",Vector3(38,3.5,12),Vector3(128,42,-109))
	for barrier: Node3D in generator.barriers:
		check(barrier.idle_light_energy>=0.8 and barrier.local_light.light_energy>=barrier.idle_light_energy-0.0001,"Barrier casts persistent light before any crossing")
		check(barrier.local_light.light_color.b>barrier.local_light.light_color.g and barrier.local_light.light_color.g>barrier.local_light.light_color.r,"Idle bounce is blue rather than pale cyan")
	var gate: Node3D = generator.architecture.get_node("EnergyFrame_B5")
	await gate_view(gate,"honeycomb_idle")
	gate.get_node("B5").local_light.visible = false
	await gate_view(gate,"blue_without_bounce")
	gate.get_node("B5").local_light.visible = true
	await gate_view(gate,"blue_with_bounce")
	gate.get_node("B5")._crossed(actor)
	await gate_view(gate,"honeycomb_crossing")
	# Actual key-driven run supplies animation poses; each snapshot freezes its own bones.
	await place(Vector3(10.8,0,10.8))
	var movement := Camera3D.new()
	actor.get_parent().add_child(movement)
	actor.movement_camera = movement
	var camera := Camera3D.new()
	actor.get_parent().add_child(camera)
	camera.far = 500
	camera.fov = 48
	camera.look_at_from_position(Vector3(11.4,3.4,13.9),Vector3(12.0,0.9,10.8))
	camera.make_current()
	actor.apply_boost()
	key(KEY_D,true)
	key(KEY_SHIFT,true)
	await ticks(24)
	await shot("charlie_afterimages")
	var trail: Node3D = actor.speed_ribbons
	check(trail.stamp_count>=2 and trail.ghosts.size()==4,"Actual boosted run produces bounded four-pose afterimages")
	check(trail.find_children("*","AnimationPlayer",true,false).is_empty(),"Afterimages contain no live animation players")
	check(not trail.skeleton_sources.is_empty(),"Afterimages use the real Charlie skeleton")
	var slot: int = (trail.cursor+3)%4
	var original: Skeleton3D = trail.skeleton_sources[0]
	var frozen: Skeleton3D = trail.ghosts[slot].skeletons[original]
	var poses: Array[Quaternion] = []
	for bone in frozen.get_bone_count():
		poses.append(frozen.get_bone_pose_rotation(bone))
	await ticks(4)
	var stable := true
	for bone in frozen.get_bone_count():
		stable = stable and poses[bone].is_equal_approx(frozen.get_bone_pose_rotation(bone))
	check(stable,"Older ghost preserves its captured running pose while Charlie continues moving")
	key(KEY_D,false)
	key(KEY_SHIFT,false)
	await ticks(40)
	var count: int = trail.stamp_count
	await ticks(20)
	check(trail.stamp_count==count,"Standing still does not spawn ghosts")
	check(trail.ghosts.all(func(g): return not g.root.visible),"All stopped afterimages fade without lingering")
	camera.free()
	movement.free()
	var rig: Node3D = scene.get_node("%FollowRig")
	actor.movement_camera = rig.camera
	rig.camera.make_current()
	await place(Vector3(10.8,0,10.8))
	rig.manual_pitch = true
	rig.pitch = 0.15
	rig.yaw = 0.8
	rig.distance = 3.3
	quake.reset_run()
	quake.planned_events = 2
	var node_count := quake.get_child_count()
	check(quake.first_delay.x>=20.0 and quake.repeat_gap.x>=50.0,"Events avoid the opening and have a long minimum separation")
	check(quake.trigger_event(),"First event starts")
	await ticks(5)
	check(absf(rig.earthquake_impulse)>0.70 and absf(rig.camera.global_basis.x.y)>0.04,"Strong onset suddenly tilts the entire gameplay view")
	await shot("quake_strong_hit")
	await ticks(40)
	check(quake.strength>0.4 and absf(rig.camera.h_offset)+absf(rig.camera.v_offset)>0.001,"Event actually trembles the gameplay camera")
	check(quake.local_emitters[0].dust.emitting or quake.event_age<3.0,"Local stone powder event is active")
	check(scene.sound.quake_audio.playing,"Independent low-frequency quake sound plays")
	await shot("quake_charlie_view")
	await ticks(48)
	await view("quake_giant_ring",Vector3(38,3.5,12),Vector3(128,42,-109))
	await view("quake_giant_disc",Vector3(7,4.5,9),Vector3(-78,13,-141))
	await ticks(190)
	check(is_zero_approx(rig.camera.h_offset) and is_zero_approx(rig.camera.v_offset) and absf(rig.earthquake_impulse)<0.00001 and absf(rig.camera.global_basis.x.y)<0.001,"Camera offsets return to zero after the event")
	quake.next_event = quake.elapsed+0.1
	await ticks(12)
	check(quake.events_started==2,"Second event starts through the gameplay scheduler")
	await ticks(230)
	check(not quake.trigger_event() and quake.events_started==2,"No third event or duplicate trigger is allowed")
	check(quake.get_child_count()==node_count,"Particle pools remain bounded across events")
	check(quake.find_children("*","CollisionObject3D",true,false).is_empty(),"Dust and debris do not add gameplay collisions")
	scene.sound.set_muted(true)
	check(not scene.sound.quake_audio.playing,"Existing mute control silences earthquake audio")
	scene.sound.set_muted(false)
	scene.reset_walk()
	check(quake.events_started==0 and quake.planned_events in [1,2],"Reset schedules a fresh one-or-two-event run")
	check(trail.ghosts.all(func(g): return not g.root.visible),"Reset clears all afterimages")
	if DisplayServer.get_name()!="headless":
		print("ENERGY DRAW SAMPLE draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("MAZE03 ENERGY ","PASS" if failures==0 else "FAIL"," failures=",failures)
	scene.queue_free()
	await process_frame
	quit(failures)


func gate_view(gate: Node3D,id: String) -> void:
	var camera := Camera3D.new()
	actor.get_parent().add_child(camera)
	camera.far = 500
	camera.fov = 75
	camera.look_at_from_position(gate.to_global(Vector3(0,1.40,1.86)),gate.to_global(Vector3(0,1.35,0)))
	camera.make_current()
	await ticks(4)
	await shot(id)
	camera.free()
	scene.get_node("%FollowRig").camera.make_current()
