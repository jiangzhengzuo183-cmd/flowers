extends SceneTree
## Run headless for equivalence/isolation; add -- --capture with native rendering.

const FIRST := preload("res://scenes/levels/maze_01_greybox.tscn")
const SECOND := preload("res://scenes/levels/Maze02.tscn")
const LOCAL := "res://art/maze02/environment/"
var failures := 0
var resource_cache: Dictionary = {}
var graph: Dictionary = {}
var material_count := 0

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

func snapshot(node: Node, index_path: String = "", result: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {"class": node.get_class()}
	if node is Node3D:
		data.transform = node.transform
		data.visible = node.visible
		if node.get_script():
			data.script = node.get_script().resource_path
	if node is CollisionObject3D:
		data.layer = node.collision_layer
		data.mask = node.collision_mask
	if node is CollisionShape3D:
		data.shape = canonical(node.shape)
		data.disabled = node.disabled
	if node is MeshInstance3D:
		data.mesh = canonical(node.mesh)
		data.material = canonical(node.material_override)
		data.overlay = canonical(node.material_overlay)
		data.surfaces = []
		if node.mesh:
			for i in node.mesh.get_surface_count():
				data.surfaces.append(canonical(node.get_active_material(i)))
	if node is Light3D or node is Camera3D or node is WorldEnvironment:
		for property: Dictionary in node.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["name", "owner"]:
				data[property.name] = canonical(node.get(property.name))
	result[index_path] = data
	for i in node.get_child_count():
		snapshot(node.get_child(i), index_path + "/" + str(i), result)
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
	new_environment.ambient_light_energy = 0.123
	new_environment.sky.sky_material.set_shader_parameter("zenith", Color.RED)
	after.get_node("Sun").light_energy = 0.321
	check(old_environment.ambient_light_energy == old_energy and old_environment.sky.sky_material.get_shader_parameter("zenith") == old_zenith, "Maze02 environment edits leave Maze01 untouched")
	check(before.get_node("Sun").light_energy != 0.321, "Maze02 light edits leave Maze01 untouched")
	check(two.maze02_lighting.environment.sky.sky_material.get_shader_parameter("zenith") == old_zenith, "Runtime sky edit leaves the Maze02 preset untouched")
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
	check(equivalent(canonical(before.get_node("WorldEnvironment").environment), canonical(after.get_node("WorldEnvironment").environment)), "Environment fully restored after the mutation probe")
	resource_cache.clear()

func capture(scene: Node, prefix: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await ticks(6)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(ProjectSettings.globalize_path("res://../.verification/maze02/" + prefix + "_entry.png")) == OK, "Entry screenshot")
	scene.inspect_location(17)
	await ticks(6)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.verification/maze02/" + prefix + "_overview.png")) == OK, "Overview screenshot")
	scene.reset_level()

func run() -> void:
	root.size = Vector2i(1280, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../.verification/maze02"))
	audit(FIRST.resource_path)
	audit(SECOND.resource_path)
	var report := FileAccess.open("res://../.verification/maze02/dependencies.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(graph, "\t"))
	report.close()
	var one = FIRST.instantiate()
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
		check(second_state.has(path) and equivalent(first_state[path], second_state[path]), "Identical geometry/collision/material/light/camera: " + path)
	check(one.maze_data == two.maze_data, "Identical map and routes")
	for path: String in ["%Player", "%FollowRig", "%CameraRig", "%GeneratedMaze"]:
		check(one.get_node(path).get_script() == two.get_node(path).get_script(), "Shared implementation " + path)
	check(one._items.get_script() == two._items.get_script(), "Shared item system")
	check_atmosphere(one, two)
	await ticks(8)
	check(one.get_node("%Player").is_on_floor() and two.get_node("%Player").is_on_floor(), "Both players have working floor collision")
	two.try_activate_gate("D1")
	await ticks(150)
	check(two.get_node("%GeneratedMaze").gates.D1.is_open and not one.get_node("%GeneratedMaze").gates.D1.is_open, "Mechanism state is independent")
	two.reset_level()
	check(not two.get_node("%GeneratedMaze").gates.D1.is_open, "Maze02 mechanism reset works")
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
	print("MAZE02 ISOLATION: dependencies=", graph.size(), "; atmosphere materials=", material_count, "; failures=", failures)
	quit(0 if failures == 0 else 1)
