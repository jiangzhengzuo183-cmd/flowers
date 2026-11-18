extends SceneTree
## Run headless for equivalence/isolation; add -- --capture with native rendering.

const FIRST := preload("res://scenes/levels/maze_01_greybox.tscn")
const SECOND := preload("res://scenes/levels/Maze02.tscn")
const SELECTOR := preload("res://scenes/levels/MazeSelect.tscn")
const Plaster := preload("res://art/maze02/environment/memory_plaster.gd")
const DreamFinish := preload("res://art/maze01/maze01_dream_finish.gd")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const Ruins := preload("res://art/maze02/ruins/maze02_ruins.gd")
const RuinGenerator := preload("res://scripts/levels/maze02_generator.gd")
const LOCAL := "res://art/maze02/environment/"
var failures := 0
var resource_cache: Dictionary = {}
var graph: Dictionary = {}
var material_count := 0
var _replaced_paths: Array[NodePath] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func canonical(value: Variant) -> Variant:
	if value is Resource:
		if resource_cache.has(value):
			return resource_cache[value]
		if value is Script or value is Texture2D and not value.resource_path.is_empty():
			return value.resource_path
		var data: Dictionary = {"class": value.get_class()}
		# Cache before recursion, including next_pass and nested texture resources.
		resource_cache[value] = data
		for property: Dictionary in value.get_property_list():
			var key: String = property.name
			if property.usage & PROPERTY_USAGE_STORAGE and key not in ["resource_name", "resource_local_to_scene", "metadata/maze02_source_shader"]:
				data[key] = canonical(value.get(key))
		if value is Shader:
			data["code"] = value.code.replace(LOCAL, "res://art/environments/").replace("\r\n", "\n")
		return data
	if value is Dictionary:
		var data: Dictionary = {}
		for key: Variant in value:
			data[key] = canonical(value[key])
		return data
	if value is Array:
		var data: Array = []
		for item: Variant in value:
			data.append(canonical(item))
		return data
	return value

func equivalent(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key: Variant in a:
			if not b.has(key) or not equivalent(a[key], b[key]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not equivalent(a[i], b[i]):
				return false
		return true
	if a is float:
		return is_equal_approx(a, b)
	if a is Vector2 or a is Vector3 or a is Color or a is Transform3D or a is Basis:
		return a.is_equal_approx(b)
	return a == b

func replaced_by_ruins(node: Node) -> bool:
	var parent := node.get_parent()
	if not parent:
		return false
	var label := String(node.name)
	for wall: NodePath in replaced_walls():
		if parent.name == wall.get_name(0) and node.name == wall.get_name(1):
			return true
	for site: Dictionary in Ruins.SITES + [Ruins.SOUTH_ARCH]:
		if parent.name != site.portal:
			continue
		if label.begins_with("ArchStone"):
			var index := label.trim_prefix("ArchStone").to_int()
			return index >= site.arch_gap[0] and index <= site.arch_gap[1]
		if label.begins_with("WallAboveArch"):
			var index := label.trim_prefix("WallAboveArch").to_int()
			return index >= site.infill_gap[0] and index <= site.infill_gap[1]
		return (site.pier > 0 and label == "RightPier") or (site.pier < 0 and label == "LeftPier")
	return false

func replaced_walls() -> Array[NodePath]:
	if _replaced_paths.is_empty():
		for site: Dictionary in Ruins.SITES + Ruins.WALL_CUTS:
			_replaced_paths.append(Ruins.wall_path(site.opened))
	return _replaced_paths

func changed_wall_join(node: Node) -> bool:
	var parts := String(node.name).split("_")
	if parts.size() != 4 or parts[0] != "WallSegment" or parts[1] not in ["H", "V"]:
		return false
	var start := Vector2i(int(parts[2]), int(parts[3]))
	var end := start + (Vector2i.DOWN if parts[1] == "H" else Vector2i.RIGHT)
	for wall: NodePath in replaced_walls():
		var old := String(wall.get_name(1)).split("_")
		var old_start := Vector2i(int(old[2]), int(old[3]))
		var old_end := old_start + (Vector2i.DOWN if old[1] == "H" else Vector2i.RIGHT)
		if start in [old_start, old_end] or end in [old_start, old_end]:
			return true
	return false

func snapshot(node: Node, index_path: String, result: Dictionary, atmosphere := false) -> Dictionary:
	atmosphere = atmosphere or node.name in [&"DreamAtmosphere", &"SkyMemories"]
	var data: Dictionary = {"class": node.get_class()}
	if node is Node3D:
		data.transform = node.transform
		if node.name != &"SparseStars":
			data.visible = node.visible
		if node.get_script():
			var script: Script = node.get_script()
			if script == RuinGenerator or script.resource_path == "res://scripts/levels/maze02_player.gd":
				script = script.get_base_script()
			data.script = script.resource_path
	if node is CollisionObject3D:
		data.layer = node.collision_layer
		data.mask = node.collision_mask
	if node is CollisionShape3D:
		data.shape = canonical(node.shape)
		data.disabled = node.disabled
	if node is MeshInstance3D:
		if node.name != &"PlazaGreenery":
			# Edge dressing exposes an end bevel where a neighboring full wall was removed.
			if not changed_wall_join(node.get_parent()):
				data.mesh = canonical(node.mesh)
		if not atmosphere and not Plaster.targets_wall(node) and node.name != &"PlazaMeadow" and node.get_meta("art_role", "") != "gate_glaze":
			data.material = canonical(node.material_override)
			data.overlay = canonical(node.material_overlay)
			data.surfaces = []
			if node.mesh:
				for i in node.mesh.get_surface_count():
					data.surfaces.append(canonical(node.get_active_material(i)))
	if node is Camera3D:
		for property: Dictionary in node.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["name", "owner"]:
				data[property.name] = canonical(node.get(property.name))
	result[index_path] = data
	var index := 0
	for child: Node in node.get_children():
		if child.name in [&"Maze02SandParticles", &"Maze02FloorDebris", &"LuckyRabbitFoot",
				&"Maze02FishLeaps", &"Maze02Ruins", &"Maze02ItemEffects", &"Maze02PickupBursts",
				&"CakeSpeedLines", &"Maze02GhostEvent"] or replaced_by_ruins(child):
			continue
		if child is Area3D and (String(child.name).begins_with("LuckyCoin_") or String(child.name).begins_with("LuckyHorseshoe_")
				or String(child.name).begins_with("ChocolateCake")):
			continue
		snapshot(child, index_path + "/" + str(index), result, atmosphere)
		index += 1
	return result

func audit(path: String) -> void:
	if graph.has(path):
		return
	graph[path] = []
	check(FileAccess.file_exists(path), "Dependency exists: " + path)
	if not FileAccess.file_exists(path):
		return
	var dependencies: Array[String] = []
	if ResourceLoader.exists(path):
		for dependency: String in ResourceLoader.get_dependencies(path):
			var resolved: String = dependency.split("::")[-1]
			if not resolved.contains("://"):
				resolved = path.get_base_dir().path_join(resolved).simplify_path()
			if resolved.begins_with("res://") and not dependencies.has(resolved):
				dependencies.append(resolved)
	if path.get_extension() in ["gd", "tscn", "tres", "gdshader", "gdshaderinc"]:
		var regex := RegEx.new()
		regex.compile("[\"'](res://[^\"'\\n]+)[\"']")
		for found: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			var resolved := found.get_string(1)
			if not dependencies.has(resolved):
				dependencies.append(resolved)
		regex.compile("(?:preload\\s*\\(|load\\s*\\(|extends\\s+|#include\\s+|path\\s*=)\\s*[\"']([^\"']+)[\"']")
		for found: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			var resolved := found.get_string(1)
			if resolved.get_extension().is_empty():
				continue
			if not resolved.contains("://"):
				resolved = path.get_base_dir().path_join(resolved).simplify_path()
			if resolved.begins_with("res://") and not dependencies.has(resolved):
				dependencies.append(resolved)
	graph[path] = dependencies
	for dependency: String in dependencies:
		audit(dependency)

func check_atmosphere(one: Node, two: Node) -> void:
	var before := one.get_node("%Player").get_parent() as Node3D
	var after := two.get_node("%Player").get_parent() as Node3D
	for branch: String in ["DreamAtmosphere", "SkyMemories"]:
		var old_meshes := before.get_node(branch).find_children("*", "MeshInstance3D", true, false)
		var new_meshes := after.get_node(branch).find_children("*", "MeshInstance3D", true, false)
		check(old_meshes.size() == new_meshes.size(), branch + " mesh count")
		for i in mini(old_meshes.size(), new_meshes.size()):
			var old_material: Material = old_meshes[i].material_override
			var new_material: Material = new_meshes[i].material_override
			if new_material is ShaderMaterial:
				material_count += 1
				check(old_material != new_material, "Atmosphere material is instance-owned")
				check(new_material.shader != old_material.shader and new_material.shader.resource_path.begins_with(LOCAL), "Atmosphere shader is Maze02-owned")
	# Changing a local profile, its deep environment and its sky never touches Maze01.
	var old_environment: Environment = one.get_node("%WorldEnvironment").environment
	var new_environment: Environment = two.get_node("%WorldEnvironment").environment
	check(old_environment != new_environment and old_environment.sky != new_environment.sky, "Environment and Sky are independent")
	check(old_environment.sky.sky_material != new_environment.sky.sky_material, "Sky materials are independent")
	check(old_environment.sky.sky_material.shader != new_environment.sky.sky_material.shader, "Sky shader is independent")
	check(new_environment != two.maze02_lighting.environment and new_environment.sky != two.maze02_lighting.environment.sky and new_environment.sky.sky_material != two.maze02_lighting.environment.sky.sky_material, "Runtime environment does not alias the saved preset")
	var old_energy := old_environment.ambient_light_energy
	var old_zenith: Variant = old_environment.sky.sky_material.get_shader_parameter("zenith")
	var new_zenith: Variant = new_environment.sky.sky_material.get_shader_parameter("zenith")
	var new_horizon: Color = new_environment.sky.sky_material.get_shader_parameter("horizon")
	check(new_zenith != old_zenith and new_horizon.r > new_horizon.b and new_environment.fog_enabled, "Maze02 has a warm sky and haze")
	check(not old_environment.fog_enabled and before.get_node("Sun").shadow_opacity > after.get_node("Sun").shadow_opacity, "Maze01 retains its original atmosphere and shadows")
	new_environment.ambient_light_energy = 0.123
	new_environment.sky.sky_material.set_shader_parameter("zenith", Color.RED)
	after.get_node("Sun").light_energy = 0.321
	check(old_environment.ambient_light_energy == old_energy and old_environment.sky.sky_material.get_shader_parameter("zenith") == old_zenith, "Maze02 environment edits leave Maze01 untouched")
	check(before.get_node("Sun").light_energy != 0.321, "Maze02 light edits leave Maze01 untouched")
	check(two.maze02_lighting.environment.sky.sky_material.get_shader_parameter("zenith") == new_zenith, "Runtime sky edit leaves the Maze02 preset untouched")
	two.maze02_lighting.apply(after)
	var custom: Resource = two.maze02_lighting.duplicate(true)
	# duplicate(true) does not recursively clone external .tres references.
	# Fork the external Environment explicitly before an in-memory experiment.
	custom.environment = two.maze02_lighting.environment.duplicate(true)
	var path := NodePath("DreamAtmosphere/PoolFirefliesWest")
	custom.node_overrides[path]["bounce_energy"] = 0.73
	custom.sun_energy = 0.42
	custom.environment.sky.sky_material.set_shader_parameter("horizon", Color.GREEN)
	custom.apply(after)
	check(before.get_node(path).bounce_energy != 0.73 and two.maze02_lighting.node_overrides[path]["bounce_energy"] != 0.73, "Lighting profile edits are isolated")
	check(after.get_node(path).bounce_energy == 0.73, "Animated light driver accepts Maze02 configuration")
	# Reapplying a profile must also update already-local horizon materials.
	var city: MeshInstance3D = after.get_node("SkyMemories/DistantCity").find_children("*", "MeshInstance3D", true, false)[0]
	check(city.material_override.get_shader_parameter("horizon") == Color.GREEN, "Horizon follows the local sky on reapply")
	two.maze02_lighting.apply(after)
	resource_cache.clear()
	check(equivalent(canonical(two.maze02_lighting.environment), canonical(after.get_node("WorldEnvironment").environment)), "Environment fully restored after the mutation probe")
	resource_cache.clear()

func capture(scene: Node, prefix: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await ticks(6)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(ProjectSettings.globalize_path("res://../.verification/maze02/" + prefix + "_entry.png")) == OK, "Entry screenshot")
	await sample_frame_rate(prefix + " entry")
	scene.inspect_location(17)
	await ticks(6)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.verification/maze02/" + prefix + "_overview.png")) == OK, "Overview screenshot")
	await sample_frame_rate(prefix + " overview")
	scene.reset_level()
	if prefix == "maze02":
		await capture_visual_views(scene)

func sample_frame_rate(view: String) -> void:
	var start := Time.get_ticks_usec()
	for i in 60:
		await RenderingServer.frame_post_draw
	print("NATIVE ", view, ": ", snappedf(60_000_000.0 / (Time.get_ticks_usec() - start), 0.1), " FPS over 60 rendered frames")

func capture_visual_views(scene: Node) -> void:
	var world := scene.get_node("%Player").get_parent() as Node3D
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 54.0
	camera.make_current()
	var views := [
		["cream_chapel", Vector3(22.82, 1.57, 20.13), Vector3(24.1, 1.0, 23.45)],
		["weathered_cream", Vector3(8.0, 1.49, 27.68), Vector3(10.0, 0.98, 25.60)],
		["sand_haze_bridge", Vector3(39.30, 4.18, 22.21), Vector3(39.65, 3.6, 16.2)],
		["worn_gate", Vector3(38.4, 4.09, 18.93), Vector3(39.62, 3.73, 16.82)],
		["apricot_horizon", Vector3(39.6, 4.9, 17.9), Vector3(85, 9.7, 12.0)],
		["apricot_sky", Vector3(39.6, 4.9, 17.9), Vector3(57.0, 15.0, 15.0)],
		["wilted_garden", Vector3(20.3, 1.53, 18.1), Vector3(22.8, 0.47, 15.6)],
		["ruin_g2", Vector3(7.56, 2.45, 41.20), Vector3(9.4, 1.25, 38.8)],
		["ruin_g3", Vector3(12.15, 2.08, 10.79), Vector3(15.1, 1.47, 10.8)],
		["ruin_g5", Vector3(41.50, 3.0, 6.67), Vector3(41.85, 0.92, 4.73)],
		["ruin_g5_arch", Vector3(38.72, 2.10, 8.39), Vector3(41.87, 1.63, 8.36)],
		["h1_restored", Vector3(12.30, 4.68, 41.22), Vector3(14.57, 0.94, 44.39)],
		["north_breach", Vector3(19.89, 2.05, 3.48), Vector3(21.95, 1.08, 3.56)],
		["west_breach", Vector3(9.07, 2.50, 25.21), Vector3(7.28, 1.28, 25.21)],
		["south_arch_g4", Vector3(27.59, 2.31, 35.03), Vector3(27.56, 1.65, 32.59)],
	]
	for view: Array in views:
		if view[0] == "cream_chapel":
			scene.inspect_location(10)
		elif view[0] == "sand_haze_bridge":
			scene.inspect_location(4)
			scene.get_node("%Player").position = Vector3(39.6, 2.66, 19.68)
		elif view[0] == "worn_gate":
			scene.inspect_location(4)
		else:
			scene.reset_walk()
		camera.look_at_from_position(view[1], view[2])
		camera.make_current()
		await ticks(35)
		await RenderingServer.frame_post_draw
		var path := "res://../.verification/maze02/" + str(view[0]) + ".png"
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) == OK, "Capture " + str(view[0]))
	await capture_fish(scene, camera)
	camera.queue_free()

func capture_fish(scene: Node, camera: Camera3D) -> void:
	var courtyard: Node3D = scene.get_node("%GeneratedMaze").architecture.get_node("NorthwestCourtyard")
	var swimmers := courtyard.get_node("PoolGoldfish")
	var landing := courtyard.get_node("Maze02FishLeaps/LandingRipple") as MeshInstance3D
	var water: float = Layout.config().northwest.waterSurface
	var deadline := create_timer(7.0)
	var apex_captured := false
	while deadline.time_left > 0.0:
		await process_frame
		for fish: Node3D in swimmers.get_children():
			if not apex_captured and fish.global_position.y > water + 0.105:
				var center := fish.global_position
				var eye := Vector3(-1.06 if center.x > 2.4 else 1.06, 0.82, 0.89)
				camera.look_at_from_position(center + eye, Vector3(center.x, water + 0.10, center.z))
				camera.make_current()
				await RenderingServer.frame_post_draw
				var path := "res://../.verification/maze02/fish_jump.png"
				check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) == OK, "Capture fish above water")
				apex_captured = true
		if apex_captured and landing.visible:
			await ticks(4)
			await RenderingServer.frame_post_draw
			var path := "res://../.verification/maze02/fish_landing.png"
			check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) == OK, "Capture landing splash and rings")
			return
	check(false, "Visible fish leap and landing")

func check_visuals(scene: Node) -> void:
	var world := scene.get_node("%Player").get_parent() as Node3D
	var sand := world.get_node("Maze02SandParticles")
	var chips := world.get_node("Maze02FloorDebris")
	check(chips.piece_count >= 105 and chips.piece_count <= 210 and chips.occupied_cells == 42,
		"Ordinary debris occupies 42 wall-side tiles, slightly above 10% of the maze")
	check(chips.find_children("*", "CollisionObject3D", true, false).is_empty(), "Floor debris is visual only")
	check(sand.occupied_cells >= 310 and sand.gust_count >= 50, "Sand covers the map and has localized gusts")
	check(sand.height_range.y < 5.8 and sand.height_range.y > 3.7, "Sand reaches the mid and upper air below the chapel eaves")
	check(not world.has_node("Maze02MemoryEchoes") and world.has_node("LuckyRabbitFoot"), "The marked rabbit is back and legacy ghosts remain disabled")
	var inventory: Control = scene._key_items.inventory
	check(inventory.get_node("LuckyRabbitFoot").visible and inventory.get_node("UseItem").visible
		and inventory.get_node("LuckyCoin").visible and inventory.get_node("LuckyHorseshoe").visible, "Rabbit and gate items appear in the inventory")
	check(scene._key_items.key_pickups.size() == 4, "Four gate pickups still spawn")
	check(not world.get_node("SkyMemories/SparseStars").visible and world.get_node("SkyMemories/DistantCity").visible, "Sky has sparse glints and still uses the skyline")
	check(not world.has_node("Maze02Gust") and not scene.get_node("%ViewportContainer").has_node("Maze02Gust"),
		"The orange gust and screen overlay are gone")
	var haze := world.get_node("DreamAtmosphere").find_child("MazeFloorHaze", true, false) as MeshInstance3D
	check(haze != null and haze.material_override.shader.resource_path.begins_with(LOCAL), "Continuous haze uses Maze02's local shader")
	print("MAZE02 SAND: ", sand.multimesh.instance_count, " flecks; ", sand.occupied_cells, " cells; ", sand.gust_count, " gust flecks; height=", sand.height_range)
	print("MAZE02 DEBRIS: ", chips.piece_count, " pieces across ", chips.occupied_cells, " cells")

func check_fish(scene: Node) -> void:
	var courtyard: Node3D = scene.get_node("%GeneratedMaze").architecture.get_node("NorthwestCourtyard")
	var swimmers := courtyard.get_node("PoolGoldfish")
	var ripple := courtyard.get_node("Maze02FishLeaps/LandingRipple") as MeshInstance3D
	var water: float = Layout.config().northwest.waterSurface
	var deadline := create_timer(15.0)
	var fish_above_water: Dictionary = {}
	var landings := 0
	var was_visible := false
	while deadline.time_left > 0.0 and (landings < 3 or fish_above_water.size() < 3):
		await process_frame
		for fish: Node3D in swimmers.get_children():
			if fish.global_position.y > water + 0.10:
				fish_above_water[fish.name] = true
		if ripple.visible and not was_visible:
			landings += 1
		was_visible = ripple.visible
	check(landings == 3 and fish_above_water.size() == 3, "All three fish alternate visible leaps and landing ripples")
	print("MAZE02 FISH: ", fish_above_water.size(), " fish jumped; ", landings, " landing ripples")

func check_palette(one: Node, two: Node) -> void:
	var has_accent := func(mesh: Node) -> bool:
		return mesh.has_meta("accent_tint") and not replaced_by_ruins(mesh.get_parent())
	var old_meshes := one.get_node("%GeneratedMaze").find_children("*", "MeshInstance3D", true, false).filter(has_accent)
	var new_meshes := two.get_node("%GeneratedMaze").find_children("*", "MeshInstance3D", true, false).filter(has_accent)
	check(old_meshes.size() == new_meshes.size(), "Accent surface count is stable")
	var replaced := 0
	var teal := 0
	for i in mini(old_meshes.size(), new_meshes.size()):
		var old_mesh: MeshInstance3D = old_meshes[i]
		var new_mesh: MeshInstance3D = new_meshes[i]
		var accent: Color = old_mesh.get_meta("accent_tint", Color.TRANSPARENT)
		if accent == DreamFinish.CREAM_VIOLET:
			replaced += 1
			check(new_mesh.get_meta("accent_tint", Color.TRANSPARENT) == DreamFinish.PLASTER_COLOR
				and new_mesh.material_override != old_mesh.material_override, "Violet wall gets its own cream finish")
		elif accent == DreamFinish.TEAL_WALL:
			teal += 1
			check(new_mesh.get_meta("accent_tint", Color.TRANSPARENT) == accent, "Teal accent retains its original color")
	var fades := 0
	for group: Dictionary in two.wall_occlusion.groups.values():
		for entry: Dictionary in group.entries:
			if entry.mesh.has_meta("maze02_plaster"):
				fades += 1
				check(entry.original == entry.mesh.material_override and entry.alpha.shader == Plaster.Fade, "Wall occlusion restores the local cream finish")
	check(replaced > 0 and teal > 0 and fades > 0, "Violet, teal and fade surfaces were all covered")
	var generator: Node = two.get_node("%GeneratedMaze")
	for id: String in generator.gates:
		var gate: Node3D = generator.gates[id]
		var other: Node3D = one.get_node("%GeneratedMaze").gates[id]
		check(gate.panel.get_meta("maze02_chipped_glaze", false) and gate.panel.material_override.albedo_texture != null
			and gate.panel.material_override == gate.get_node("DreamGateFinish").glaze
			and not other.panel.has_meta("maze02_chipped_glaze"), "Weathered paint is on the original Maze02 mechanism " + id)
	var wall_count := 0
	var aged_count := 0
	var grades: Dictionary = {}
	for mesh: Node in generator.find_children("*", "MeshInstance3D", true, false):
		if mesh.has_meta("maze02_plaster"):
			wall_count += 1
			aged_count += int(mesh.get_meta("maze02_aged", false))
			grades[mesh.get_meta("maze02_weather_strength")] = true
	check(aged_count >= wall_count * 0.50 and aged_count <= wall_count * 0.60, "50–60% of plaster has the subtle sand finish")
	check(grades.has(0.0) and grades.has(1.0) and grades.size() >= 4, "Wall wear grades from clean to aged through intermediate finishes")
	for portal: String in ["G6", "G7", "G8"]:
		var finished := 0
		for mesh: MeshInstance3D in generator.get_node("LevelArchitecture/" + portal).find_children("*", "MeshInstance3D", true, false):
			if mesh.has_meta("maze02_chapel_finish"):
				finished += 1
				var finish := mesh.material_override as StandardMaterial3D
				check(finish != null and finish.albedo_texture != null, portal + " uses a plaster texture")
		check(finished == 26, portal + " has all 26 masonry pieces textured")
	var bounce_path := "DreamAtmosphere/EntryMistFireflies/SoftAmberBounce"
	var amber: OmniLight3D = one.get_node("%Player").get_parent().find_child("DreamAtmosphere", true, false).get_node("EntryMistFireflies/SoftAmberBounce")
	var cyan: OmniLight3D = two.get_node("%Player").get_parent().find_child("DreamAtmosphere", true, false).get_node("EntryMistFireflies/SoftAmberBounce")
	check(amber.light_color.r > amber.light_color.b and cyan.light_color.b > cyan.light_color.r, bounce_path + " is cyan only in Maze02")
	print("MAZE02 AGING: ", aged_count, "/", wall_count)
	print("MAZE02 PALETTE: ", replaced, " cream replacements; ", teal, " teal surfaces kept; ", fades, " local fades")

func check_selection() -> void:
	var selector := SELECTOR.instantiate()
	root.add_child(selector)
	if OS.get_cmdline_user_args().has("--capture"):
		await ticks(3)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.verification/maze02/maze_select.png")) == OK, "Selector screenshot")
	var host := selector.get_node("%LevelHost")
	for i in [0, 1, 0]:
		var button := selector.get_node("%Maze01" if i == 0 else "%Maze02") as Button
		button.pressed.emit()
		await ticks(3)
		var level := host.get_child(0)
		var world := level.get_node("%Player").get_parent()
		check(host.get_child_count() == 1 and level.loaded_ok, "Selector runs exactly one maze")
		check(level.scene_file_path == (FIRST.resource_path if i == 0 else SECOND.resource_path), "Selector opens the requested scene")
		check(world.find_children("*", "WorldEnvironment", true, false).size() == 1 and world.has_node("Maze02SandParticles") == (i == 1), "Correct environment and particles after switching")
		check(world.find_children("*", "Camera3D", true, false).size() == 2 and world.find_children("Player", "CharacterBody3D", true, false).size() == 1, "Only the shared player and its two normal camera modes are present")
		check(level.get_node("%WorldEnvironment").environment.fog_enabled == (i == 1), "Selector applies the chosen maze's environment")
		await check_play_view(level, selector, i)
		var old: WeakRef = weakref(level)
		var old_world: WeakRef = weakref(world)
		(selector.get_node("%Back") as Button).pressed.emit()
		await ticks(3)
		check(host.get_child_count() == 0 and old.get_ref() == null and old_world.get_ref() == null, "Returning frees the maze, including its cameras, particles and audio")
	selector.queue_free()
	await ticks(2)

func check_play_view(level: Control, selector: Control, index: int) -> void:
	var window_mode := root.mode
	var viewport := level.get_node("%ViewportContainer") as Control
	var walk_controls := level.get_node("WalkControls") as Control
	var back := selector.get_node("%Back") as Button
	level.get_node("Toolbar/PlayOnlyButton").pressed.emit()
	await ticks(4)
	check(viewport.is_visible_in_tree() and not walk_controls.visible and not back.visible
		and not level.get_node("Heading").visible and not level.get_node("Toolbar").visible
		and not level._key_items.inventory.visible, "Play-only mode hides all the non-game controls")
	check(viewport.size.is_equal_approx(selector.size) and level.get_node("%Player").controls_enabled,
		"The original player and viewport fill the selector window")
	if DisplayServer.get_name() != "headless":
		await view_key(KEY_F11)
		check(root.mode == Window.MODE_FULLSCREEN and not walk_controls.visible, "F11 enters native play-only fullscreen")
	await view_key(KEY_ESCAPE)
	check(root.mode == window_mode and walk_controls.visible and back.visible and level._key_items.inventory.visible,
		"Esc restores the previous window and interface")
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await view_key(KEY_F10)
		await RenderingServer.frame_post_draw
		var path := "res://../.verification/maze02/play_only_%d.png" % (index + 1)
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) == OK, "Play-only screenshot")
		await view_key(KEY_ESCAPE)

func view_key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(3)
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)

func run() -> void:
	root.size = Vector2i(1280, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../.verification/maze02"))
	audit(FIRST.resource_path)
	audit(SECOND.resource_path)
	audit(SELECTOR.resource_path)
	var one = FIRST.instantiate()
	# Compare the shared layout with the same pickup and doctor options as Maze 02.
	one.use_marked_pickups = false
	one.finish_doctor_enabled = false
	root.add_child(one)
	var first_state := snapshot(one.get_node("%Player").get_parent(), "", {})
	resource_cache.clear()
	var two = SECOND.instantiate()
	root.add_child(two)
	var second_state := snapshot(two.get_node("%Player").get_parent(), "", {})
	resource_cache.clear()
	check(one.loaded_ok and two.loaded_ok, "Both scenes load")
	check(first_state.size() == second_state.size(), "Runtime node count")
	print("MAZE02 compared ", first_state.size(), " runtime world nodes")
	for path: String in first_state:
		check(second_state.has(path) and equivalent(first_state[path], second_state[path]), "Identical geometry, collision, building materials and cameras: " + path)
	check(one.maze_data == two.maze_data, "Identical map and routes")
	check(two.get_node("%Player").get_script().get_base_script() == one.get_node("%Player").get_script(), "Maze02 player keeps the shared movement implementation")
	for path: String in ["%FollowRig", "%CameraRig"]:
		check(one.get_node(path).get_script() == two.get_node(path).get_script(), "Shared implementation " + path)
	check(two.get_node("%GeneratedMaze").get_script().get_base_script() == one.get_node("%GeneratedMaze").get_script(), "Maze02 reuses the shared generator")
	check(not is_instance_valid(two._doctor), "Maze02 does not spawn the doctor")
	var first_music: AudioStreamPlayer = one.sound.get_node("Music")
	var second_music: AudioStreamPlayer = two.sound.get_node("Music")
	var loop := second_music.stream as AudioStreamWAV
	check(first_music.stream == one.sound.Music and loop == two.maze02_music
		and loop.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Each maze has its own looping soundtrack")
	check(two.sound.find_children("Music", "AudioStreamPlayer", false, false).size() == 1, "Maze02 reuses one music player")
	two.sound.set_muted(true)
	two._update_wind_audio(0.0, false)
	check(not second_music.playing, "Mute stops Maze02 music")
	check(not two._wind_audio.playing and not one.sound.has_node("SandWindBed"), "The sound toggle stops the Maze02-only wind bed")
	two.sound.set_muted(false)
	two._update_wind_audio(1.0, false)
	check(second_music.playing, "Unmute resumes Maze02 music")
	var wind: AudioStreamWAV = two._wind_audio.stream
	check(two._wind_audio.playing and wind.loop_mode == AudioStreamWAV.LOOP_FORWARD and two._wind_audio.volume_db <= -26.0,
		"Wind resumes as a quiet continuous loop")
	check(one._items.get_script() == two._items.get_script().get_base_script() and is_instance_valid(one._items._pickup), "Maze01 keeps its rabbit and Maze02 reuses the shared gate inventory")
	check_palette(one, two)
	check_atmosphere(one, two)
	await ticks(8)
	check_visuals(two)
	if DisplayServer.get_name() == "headless":
		await check_fish(two)
	var environment: Environment = two.get_node("%WorldEnvironment").environment
	var outdoor_fog := environment.fog_density
	two.inspect_location(10)
	await ticks(40)
	check(environment.fog_density < outdoor_fog * 0.2 and environment.ambient_light_energy < 0.42, "Chapel settles into cooler, clearer shade")
	check(two._wind_audio.volume_db < -34.0, "The chapel muffles the wind bed")
	two.reset_walk()
	await ticks(40)
	check(is_equal_approx(environment.fog_density, outdoor_fog), "Outdoor haze returns after leaving the chapel")
	var report := FileAccess.open("res://../.verification/maze02/dependencies.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(graph, "\t"))
	report.close()
	check(one.get_node("%Player").is_on_floor() and two.get_node("%Player").is_on_floor(), "Both players have working floor collision")
	two.get_node("%GeneratedMaze").gates.D1.set_open_state(true)
	check(not one.get_node("%GeneratedMaze").gates.D1.is_open, "Mechanism state is independent")
	two.reset_level()
	check(not two.get_node("%GeneratedMaze").gates.D1.is_open, "Maze02 mechanism reset works")
	check(is_instance_valid(two._items._pickup), "Reset respawns the marked rabbit")
	# Release node snapshots before freeing scenes; they contain canonical resources.
	first_state.clear()
	second_state.clear()
	two.free()
	await capture(one, "maze01")
	one.free()
	two = SECOND.instantiate()
	root.add_child(two)
	await capture(two, "maze02")
	two.free()
	await ticks(3)
	await check_selection()
	print("MAZE02 ISOLATION: dependencies=", graph.size(), "; atmosphere materials=", material_count, "; failures=", failures)
	quit(0 if failures == 0 else 1)
