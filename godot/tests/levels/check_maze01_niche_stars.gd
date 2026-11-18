extends SceneTree

const Scene := preload("res://scenes/levels/maze_01_greybox.tscn")
const Star := preload("res://scripts/levels/niche_star.gd")
const Corridor := preload("res://scripts/levels/sunken_corridor.gd")
const CAPTURES := "res://../.verification/maze01-h6-stars"
var failures := 0
var capture_enabled := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440, 900)
	Input.use_accumulated_input = false
	capture_enabled = OS.get_cmdline_user_args().has("--capture")
	var scene := Scene.instantiate()
	root.add_child(scene)
	await process_frame
	scene.inspect_location(21)
	var actor: CharacterBody3D = scene.get_node("%Player")
	var rig: Node3D = scene.get_node("%FollowRig")
	var corridor: Node3D = scene.get_node("%GeneratedMaze/LevelArchitecture/SunkenCorridor")
	var stars: Array[Node3D] = []
	for name: String in ["StarMi", "StarRe", "StarDo"]:
		var star: Node3D = corridor.get_node_or_null(name)
		check(star != null, "Missing " + name)
		if star != null:
			stars.append(star)
	if stars.size() != 3:
		quit(1)
		return
	for star in stars:
		check_spin_clearance(star)
		var chime: AudioStreamPlayer3D = star.get_node("Chime")
		check(chime.stream != null and chime.stream.get_length() > 0.5, "Playable chime on " + str(star.name))
		check(not star._materials.is_empty(), "Imported surface on " + str(star.name))
		for material: BaseMaterial3D in star._materials:
			check(material.albedo_texture != null and material.emission_texture == material.albedo_texture, "Preserves textured color in the glow")
			check(is_equal_approx(material.emission_energy_multiplier, Star.REST_EMISSION), "Idle emission")
	await ticks(30)
	check(stars.all(func(star: Node3D) -> bool: return star._animation == null), "Inspect spawn does not activate a chime")
	var space := actor.get_world_3d().direct_space_state
	for star in stars:
		var z := star.position.z
		var into_niche := PhysicsRayQueryParameters3D.create(Vector3(3.6, 0.0, z), Vector3(5.5, 0.0, z), 1)
		var back := space.intersect_ray(into_niche)
		check(not back.is_empty() and is_equal_approx(back.position.x, Corridor.NICHE_BACK), "Deep pocket is clear of the adjacent floor slab")
		var next_lane := PhysicsRayQueryParameters3D.create(Vector3(5.65, 0.5, z), Vector3(5.65, -0.2, z), 1)
		var floor_hit := space.intersect_ray(next_lane)
		check(not floor_hit.is_empty() and is_zero_approx(floor_hit.position.y), "The floor of the next lane is intact")
	await capture("01_approach")
	var notes: Array[String] = []
	var seen := {}
	var boosted := {}
	var turning := {}
	var peak_captured := false
	key(KEY_W, true)
	for i in 245:
		await ticks(1, KEY_W)
		for star in stars:
			if star._animation == null:
				continue
			if not seen.has(star.name):
				seen[star.name] = star._animation
				notes.append(star._audio.stream.resource_path.get_file().get_basename())
				check(star._audio.playing, str(star.name) + " plays its chime on entry")
			if star._light.light_energy > 0.29:
				boosted[star.name] = true
			if absf(star._pivot.rotation.y) > 0.2:
				turning[star.name] = true
		if capture_enabled and not peak_captured and stars[0]._light.light_energy > 0.31 and stars[0]._pivot.rotation.y > 0.55:
			peak_captured = true
			await capture("02_charlie_triggers_mi")
		if boosted.size() == 3 and turning.size() == 3:
			break
	key(KEY_W, false)
	await ticks(90)
	check(notes == ["mi", "re", "do"], "North to south plays Mi, Re, Do in order: " + str(notes))
	check(actor.position.z > 22.5 and actor.is_on_floor(), "Charlie walks through the corridor without obstacles")
	for star in stars:
		check(star._animation == seen.get(star.name), "Standing still does not retrigger " + str(star.name))
		check(is_zero_approx(star._pivot.rotation.y) and is_equal_approx(star._light.light_energy, Star.REST_LIGHT), "Returns to resting state")
	check(boosted.size() == 3, "All three stars brighten")
	check(turning.size() == 3, "All three stars turn")
	var last_star: Node3D = stars[2]
	key(KEY_W, true)
	await ticks(60, KEY_W)
	key(KEY_W, false)
	await ticks(5)
	key(KEY_S, true)
	key(KEY_SHIFT, true)
	await ticks(45, KEY_S)
	key(KEY_SHIFT, false)
	key(KEY_S, false)
	check(last_star._animation != seen.get(last_star.name), "Leaving the trigger and running back through it plays the note again")
	if capture_enabled:
		await ticks(70)
		actor.position = Vector3(3.76, -0.56, 20.9)
		rig.reset_view()
		rig.yaw = -1.39
		rig.pitch = 0.78
		rig.distance = 4.0
		await ticks(100)
		await capture("03_three_niches")
	# Fixed-fps mode advances simulation faster than the audio mixing thread.
	# Give the real audio driver time to finish the last chime before shutdown.
	var audio_end := Time.get_ticks_msec() + 750
	while Time.get_ticks_msec() < audio_end:
		await process_frame
	scene.queue_free()
	await ticks(4)
	print("H6 NICHE STARS: ", "PASS" if failures == 0 else "FAIL", " / ", notes)
	quit(failures)

func check_spin_clearance(star: Node3D) -> void:
	var pivot: Node3D = star.get_node("SpinPivot")
	var radius := 0.0
	for mesh: MeshInstance3D in pivot.find_children("*", "MeshInstance3D", true, false):
		var to_pivot := pivot.global_transform.affine_inverse() * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point := to_pivot * vertex
				radius = maxf(radius, Vector2(point.x, point.z).length())
	check(radius > 0.0 and star.position.x - radius > Corridor.NICHE_FRONT and star.position.x + radius < Corridor.NICHE_BACK, str(star.name) + " stays completely inside during a full spin")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func ticks(count: int, held: int = 0) -> void:
	for i in count:
		await physics_frame
		if held != 0:
			key(held, true)
		await process_frame

func capture(id: String) -> void:
	if not capture_enabled:
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path(CAPTURES)
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(id + ".png")) == OK, "Saved " + id)
