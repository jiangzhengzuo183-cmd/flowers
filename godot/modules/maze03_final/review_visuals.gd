extends "res://modules/maze03_final/check_final.gd"
func run() -> void:
	root.size = Vector2i(1600,900)
	folder = "res://../.verification/maze03-middle-axis"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	scene = Third.instantiate()
	root.add_child(scene)
	actor = scene.get_node("%Player")
	generator = scene.get_node("%GeneratedMaze")
	await ticks(15)
	scene.play_view.set_mode(1)
	await ticks(5)
	for i in 4:
		var offset := Vector3(34,27,34).rotated(Vector3.UP,i*PI*0.5)
		await view("global_"+str(i),Vector3(23,2,23)+offset,Vector3(23,2,23))
	await view("environment_overview",Vector3(88,24,100),Vector3(24,13,23))
	await view("hero",Vector3(28,24,79),Vector3(22,7,17))
	await view("hero_west",Vector3(72,26,52),Vector3(20,4,23))
	await view("overview",Vector3(57,36,57),Vector3(23,2,23))
	await view("restored_sunken_garden",Vector3(13,8,16),Vector3(4.5,1.1,9.6))
	await view("horizon_northeast",Vector3(38,2.8,12),Vector3(128,27,-109))
	await view("horizon_west",Vector3(8,2.7,25),Vector3(-137,23,8))
	await view("horizon_southeast",Vector3(38,3,37),Vector3(112,22,181))
	await view("horizon_southwest",Vector3(7,7,39),Vector3(-82,37,171))
	await view("ring_axis",Vector3(38,3.5,12),Vector3(128,42,-109))
	await view("middle_distance",Vector3(60,12,75),Vector3(7,25,-160))
	var enclosure: Node3D = actor.get_parent().get_node("FinalTrialHorizon/WhiteMegastructureEnclosure")
	var warm: SpotLight3D = enclosure.get_node("RingAxisLight").regional_light
	warm.visible = false
	await view("regional_warm_before",Vector3(46,9,19),Vector3(36,1,9))
	warm.visible = true
	await view("regional_warm_after",Vector3(46,9,19),Vector3(36,1,9))
	await view("raised_disc_glass",Vector3(7,4.5,9),Vector3(-78,13,-141))
	await view("high_blade_glass",Vector3(42,4,25),Vector3(157,54,48))
	await view("wind_above_maze",Vector3(12,6,42),Vector3(35,7,10))
	await ticks(45)
	await view("wind_later",Vector3(12,6,42),Vector3(35,7,10))
	await view("sky_tracks",Vector3(25,3.5,35),Vector3(105,65,-105))
	await view("mirror_pool",Vector3(32.8,2.3,32.4),Vector3(24,2,22.8))
	await view("pool_west_bank",Vector3(14.9,2.4,29.4),Vector3(16.6,0.2,18))
	var gate: Node3D = generator.barriers[0].get_parent()
	await view("barrier_idle",gate.to_global(Vector3(0,1.65,1.7)),gate.to_global(Vector3(0,1.2,0)))
	generator.barriers[0]._crossed(actor)
	await view("barrier_detail",gate.to_global(Vector3(0,1.65,1.7)),gate.to_global(Vector3(0,1.2,0)))
	for spec: Dictionary in generator.EXTRA_BARRIERS:
		var extra: Node3D = generator.architecture.get_node("EnergyFrame_"+spec.id)
		await view("barrier_"+spec.id,extra.to_global(Vector3(0,1.6,1.7)),extra.to_global(Vector3(0,1.1,0)))
	# Cardinal views use the real Charlie camera and its actual wall collision checks.
	var views := [["north",Vector3(22.8,0,1.2),0.0],["east",Vector3(44.4,0,22.8),-PI/2],["south",Vector3(22.8,0,44.4),PI],["west",Vector3(1.2,0,27.6),PI/2]]
	for spec: Array in views:
		scene.set_walk_mode(true)
		await place(spec[1])
		var rig = scene.get_node("%FollowRig")
		rig.manual_pitch = true
		rig.pitch = 0.06
		rig.yaw = spec[2]
		rig.distance = 3.0
		await ticks(40)
		await shot("charlie_"+spec[0])
	print("VISUAL REVIEW rendered")
	scene.queue_free()
	await process_frame
	quit()



