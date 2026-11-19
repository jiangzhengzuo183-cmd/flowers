extends "res://tests/art_samples/check_art_sample.gd"

const Level := preload("res://scenes/levels/maze_01_greybox.tscn")
const Lighting := preload("res://art/environments/maze01_formal_lighting.tres")
const Memories := preload("res://art/environments/sky_memories/sky_memories.gd")

func run() -> void:
	root.size = Vector2i(1440,1000)
	scene = Level.instantiate()
	root.add_child(scene)
	await ticks(15)
	var actor: CharacterBody3D = scene.get_node("%Player")
	var world: Node3D = actor.get_parent()
	var sky: Memories = world.get_node("SkyMemories")
	var env: Environment = scene.get_node("%WorldEnvironment").environment
	for color: String in ["zenith","middle","horizon","nadir"]:
		check(env.sky.sky_material.get_shader_parameter(color) == Lighting.environment.sky.sky_material.get_shader_parameter(color),"Keep base sky " + color)
	check(env.ambient_light_color == Lighting.environment.ambient_light_color and is_equal_approx(env.ambient_light_energy,Lighting.environment.ambient_light_energy),"Keep existing ambient lighting")
	check(is_equal_approx(world.get_node("Sun").light_energy,Lighting.sun_energy),"Keep the directional key light")
	check(sky.find_children("*","CollisionObject3D",true,false).is_empty() and sky.find_children("*","Light3D",true,false).is_empty(),"Sky props have no collisions or lamps")
	var city := sky.get_node("DistantCity")
	check(city.scene_file_path.ends_with("/distant_city.tscn") and not sky.has_node("CityPanorama"),"The horizon uses an independent three-dimensional city scene")
	for layer: Node3D in city.get_children():
		check(layer.get_child_count()>=8,"Each distance layer has multiple composed districts")
		for district: Node3D in layer.get_children():
			var architecture: MeshInstance3D = district.get_node("Architecture")
			var aabb := architecture.get_aabb()
			check(aabb.size.z>12.0 and aabb.size.y>32.0,"District has real depth and varied architecture")
			check(not architecture.material_override.shader.code.contains("ALPHA"),"Districts remain depth-writing, opaque geometry")
			check(district.has_node("WarmWindows"),"Sparse window inlays are separate geometry")
	var distant: Vector3 = city.get_node("FarDistricts/WestHangingTowers").position
	var near: Vector3 = city.get_node("NearDistricts/WestBelfries").position
	check(distant.length()-near.length()>30.0,"The city layers occupy different world distances")
	check(sky.get_node("SparseStars").mesh.get_faces().size()==Memories.STAR_COUNT*6,"All stars share one mesh")
	var moon: MeshInstance3D = sky.get_node("FadingMoon")
	check(moon.position.length()>120 and moon.mesh.size.x>=60 and moon.position.y<8.0,"The ivory moon sits close to the horizon")
	check(not sky.get_node("CyanMeteor").visible and sky.get_node("MeteorInterval").time_left>19.0,"Meteor starts inactive with a sparse schedule")

	scene.set_walk_mode(false)
	var overview = scene.get_node("%CameraRig")
	overview.yaw = PI/4.0
	overview.pitch = 0.34
	overview.zoom = 0.92
	overview._update_camera()
	await ticks(8)
	await snap("18_sky_overview")
	overview.yaw = -3.0 * PI/4.0
	overview._update_camera()
	await ticks(5)
	await snap("23_sky_opposite_side")

	var probe := Camera3D.new()
	world.add_child(probe)
	probe.far = 260.0
	probe.fov = 46.0
	var eye := Vector3(0.85,4.1,40.5)
	probe.look_at_from_position(eye, sky.to_global(sky._radial(-1.88,108.0,5.1)))
	probe.make_current()
	await ticks(8)
	await snap("19_distant_city")

	probe.look_at_from_position(eye,sky.to_global(sky._radial(Memories.MOON_ANGLE,139.0,14.0)))
	await ticks(8)
	await snap("20_moon_and_stars")
	sky.play_meteor(-1.91,0.225,true)
	await ticks(23)
	check(sky.get_node("CyanMeteor").visible and float(sky.get_node("CyanMeteor").material_override.get_shader_parameter("opacity"))>0.5,"Cyan trail appears then fades")
	await snap("21_cyan_meteor")
	await ticks(95)
	check(not sky.get_node("CyanMeteor").visible,"Meteor cleans up after its pass")
	probe.queue_free()

	scene.reset_walk()
	scene.set_walk_mode(true)
	var follow = scene.get_node("%FollowRig")
	actor.position = Vector3(14.4,1.24,44.4)
	actor.visual.rotation.y = 0.97
	follow.reset_view()
	follow.yaw = 0.97
	follow.pitch = 0.04
	follow.distance = 3.60
	await ticks(30)
	await snap("22_sky_during_play")
	scene.queue_free()
	await ticks(6)
	print("MAZE 01 SKY: ","PASS" if failures == 0 else "FAIL"," (",failures," failures)")
	quit(failures)

func snap(id: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../.verification/maze01-final")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(id+".png"))==OK,"Screenshot " + id)
