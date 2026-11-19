extends SceneTree
const Base := preload("res://scenes/maze_runs/Maze01_Base.tscn")
const Sample := preload("res://scenes/art_samples/Maze01_ArtSample.tscn")
const Plaster := preload("res://art/maze01/materials/plaster_cream.tres")
var failures := 0
var scene
var held: Array[int] = []

func key(code: int,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	if pressed and not held.has(code):
		held.append(code)
	elif not pressed:
		held.erase(code)

func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func ticks(count: int = 6) -> void:
	for i in count:
		await physics_frame
		for code: int in held:
			var event := InputEventKey.new()
			event.physical_keycode = code
			event.pressed = true
			Input.parse_input_event(event)
		await process_frame

func path_key(root_node: Node,node: Node) -> String:
	var parts: Array[String] = []
	while node!=root_node:
		parts.push_front(str(node.get_index()))
		node = node.get_parent()
	return "/".join(parts)

func digest(faces: PackedVector3Array) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(faces))
	return hash.finish().hex_encode()

func geometry(node: Node) -> Dictionary:
	var result: Dictionary = {}
	var gen := node.get_node("%GeneratedMaze")
	for mesh: MeshInstance3D in gen.find_children("*","MeshInstance3D",true,false):
		if not mesh.get_meta("art_addition",false):
			var base_mesh: Mesh = mesh.get_meta("art_source_mesh", mesh.mesh)
			result["mesh/"+path_key(gen,mesh)] = [mesh.transform,digest(base_mesh.get_faces())]
	for shape: CollisionShape3D in gen.find_children("*","CollisionShape3D",true,false):
		result["collision/"+path_key(gen,shape)] = [shape.transform,shape.disabled,digest(shape.shape.get_debug_mesh().get_faces()),shape.get_parent().collision_layer]
	return result

func snap(id: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await ticks(12)
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../.verification/art-sample-round2")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(id+".png"))==OK,"Capture "+id)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440,1000)
	var baseline = Base.instantiate()
	baseline.dream_art_enabled = false
	root.add_child(baseline)
	await ticks()
	var original := geometry(baseline)
	var old_environment: Environment = baseline.get_node("%WorldEnvironment").environment
	var old_color := old_environment.background_color
	baseline.set_walk_mode(false)
	var base_rig = baseline.get_node("%CameraRig")
	base_rig.center = Vector3(25,4.1,23.2)
	base_rig.world_size = Vector3(23,14,23)
	base_rig.extent = 23
	base_rig.yaw = -0.72
	base_rig.pitch = 0.43
	base_rig.zoom = 1.65
	base_rig._update_camera()
	await ticks(12)
	if OS.get_cmdline_user_args().has("--capture"):
		print("ART BASELINE OVERVIEW: draw calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	scene = Sample.instantiate()
	root.add_child(scene)
	await ticks(30)
	check(scene.loaded_ok,"Art sample loads final structure")
	check(geometry(scene)==original,"Every original mesh vertex, transform, collision shape/layer and state is preserved")
	check(baseline.get_node("%WorldEnvironment").environment.background_color==old_color,"Environment does not leak to original scene")
	var gen = scene.get_node("%GeneratedMaze")
	var roof_count := 0
	var wall_count := 0
	var rail_count := 0
	for mesh: MeshInstance3D in gen.find_children("*","MeshInstance3D",true,false):
		if mesh.get_meta("art_role","")=="roof":
			roof_count += 1
			check(mesh.material_override==load("res://art/maze01/materials/roof_lake.tres"),"All roof pieces share the lake material")
		elif mesh.get_meta("art_role","")=="plaster":
			wall_count += 1
		elif mesh.get_meta("art_role", "") == "rail_plaster":
			rail_count += 1
			check(mesh.material_override.get_shader_parameter("finish_color") == Plaster.albedo_color, "Rails and walls share the warm plaster color")
	check(roof_count>10 and wall_count>200,"Chapel roof, flat roofs, trims and wall sample are bound")
	check(rail_count > 0, "Sample railings receive the plaster finish")
	for point: Dictionary in scene.maze_data.checkpoints:
		check(not gen.get_node(str(point.id)).visible,"Checkpoint discs are hidden without deleting detection data")
	for pin: MeshInstance3D in gen.marker_pins:
		check(not pin.visible,"Overview never re-enables floating debug pins")
	for mesh: MeshInstance3D in gen.architecture.get_node("SunkenCorridor").find_children("*","MeshInstance3D",true,false):
		if mesh.get_meta("art_role","") == "niche_star":
			continue
		check(not mesh.has_meta("art_role"),"Dry corridor and all three niches remain untouched")
	check(scene.get_node("%Player").get_parent().get_node("SoftFill").visible==false,"Only one directional key light")
	var chapel_lights: Array[Node] = gen.find_children("InteriorWarmFill","OmniLight3D",true,false)
	check(chapel_lights.size()==1,"One local light for three pendants")
	for light: OmniLight3D in chapel_lights:
		check(not light.shadow_enabled,"Pendant does not add realtime point shadows")
	check(is_equal_approx(scene.wall_occlusion.hidden_fraction,0.85),"Existing near-total occlusion threshold preserved")
	var adapted := 0
	for group: Dictionary in scene.wall_occlusion.groups.values():
		for entry: Dictionary in group.entries:
			if entry.mesh.get_meta("art_role","")=="plaster":
				adapted += 1
				check(entry.alpha.shader==load("res://art/maze01/plaster_fade.gdshader"),"Sample plaster retains its paired fade material")
	check(adapted>10,"Sample exterior walls are registered for original fading")
	root.remove_child(baseline)
	baseline.queue_free()
	await ticks()
	await snap("01_chapel_overview")
	if OS.get_cmdline_user_args().has("--capture"):
		print("ART SAMPLE OVERVIEW: draw calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	scene.show_player()
	await ticks(45)
	check(scene.get_node("%Player").controls_enabled,"Character walking remains available")
	await snap("02_player_view")
	scene.show_interior()
	await ticks(45)
	check(scene.get_node("%FollowRig").inside_building,"Existing indoor camera detects the chapel")
	await snap("03_interior")
	var floor_colors: Array[Color] = []
	for index in scene.floor_picker.item_count:
		scene.floor_picker.item_selected.emit(index)
		var color: Color = gen.floor_finishes[0].get_shader_parameter("finish_color")
		check(not floor_colors.has(color), "Floor picker selects a distinct stone color")
		floor_colors.append(color)
		for finish: ShaderMaterial in gen.floor_finishes:
			check(finish.get_shader_parameter("finish_color") == color, "Indoor floor, court and deck use the selected color")
			check(finish.get_shader_parameter("finish_side_color") == Plaster.albedo_color, "Deck sides keep the plaster color")
		await snap("floor_%d_player" % (index + 1))
	check(floor_colors.size() == 3, "Three floor options available")
	scene.set_floor_style(0)
	scene.show_chapel()
	# A separate render-only camera inspects glass and both light-facing sides.
	var probe := Camera3D.new()
	scene.get_node("%Player").get_parent().add_child(probe)
	probe.fov = 48
	probe.position = Vector3(10,11,12)
	probe.look_at(Vector3(24,5.3,22.8),Vector3.UP)
	probe.current = true
	await snap("04_west_facade")
	probe.position = Vector3(37,10,33)
	probe.look_at(Vector3(24,5.3,22.8),Vector3.UP)
	await snap("05_east_facade")
	probe.queue_free()
	scene.show_chapel()
	for index in scene.floor_picker.item_count:
		scene.set_floor_style(index)
		await snap("floor_%d_overview" % (index + 1))
	scene.set_floor_style(0)
	var rig = scene.get_node("%CameraRig")
	rig.center = Vector3(22.8,3,22.8)
	rig.world_size = Vector3(47,14,47)
	rig.extent = 45.6
	rig.zoom = 1.0
	rig._update_camera()
	await snap("06_global_pink_background")
	# Real input and collisions inside the art scene, not only the gray baseline.
	scene.reset_level()
	var player = scene.get_node("%Player")
	var input_camera := Camera3D.new()
	player.get_parent().add_child(input_camera)
	player.movement_camera = input_camera
	await ticks(12)
	root.gui_release_focus()
	var start: Vector3 = player.position
	key(KEY_W,true)
	key(KEY_SHIFT,true)
	key(KEY_SPACE,true)
	await ticks(12)
	check(player.position.y-start.y>0.25 and player.position.z<start.z,"Sample supports real running and jumping")
	for code: int in held.duplicate():
		key(code,false)
	await ticks(35)
	check(player.is_on_floor(),"Sample jump lands on original collision")
	player.position = Vector3(3.6,0.04,39.6)
	await ticks(8)
	check(scene.closest_switch==gen.switches.D1,"Sample keeps the original nearest-switch detection")
	key(KEY_E,true)
	await ticks(1)
	key(KEY_E,false)
	await ticks(45)
	check(gen.gates.D1.is_open and gen.gates.D1.leaf.get_node("GateCollision").disabled,"Sample E interaction opens the real door")
	for id: String in ["D3","D4"]:
		scene.try_activate_gate(id)
	player.position = Vector3(44.4,0.08,1.2)
	await ticks(8)
	check(scene.completed,"Sample preserves the real exit condition")
	scene.reset_level()
	await ticks(3)
	check(not scene.completed and not gen.gates.D1.is_open,"Sample reset restores original gate and completion state")
	# Native capture diagnostics; not a cross-device FPS guarantee.
	if OS.get_cmdline_user_args().has("--capture"):
		print("ART SAMPLE RENDER: draw calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	scene.queue_free()
	await ticks()
	print("ART SAMPLE: ","PASS" if failures==0 else "FAIL"," (",failures," failures), original geometry entries=",original.size(),", styled walls=",wall_count,", roof pieces=",roof_count)
	quit(failures)
