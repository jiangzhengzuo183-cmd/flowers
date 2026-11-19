extends "res://art/environments/dream_lighting.gd"
## These overrides target existing nodes. They never build players, props or geometry.

@export var node_overrides: Dictionary = {}
@export var shader_overrides: Dictionary = {}
@export var cloud_tint := Color(0.96, 0.91, 0.78)
@export var city_haze := Color(0.74, 0.68, 0.57)
@export var show_distant_city := true
const Fireflies := preload("res://art/maze01/firefly_cluster.gd")
var _cyan_glow: StandardMaterial3D

func apply(world: Node3D) -> void:
	super(world)
	var city := world.get_node_or_null("SkyMemories/DistantCity") as Node3D
	if city:
		city.visible = show_distant_city
	var old_star_field := world.get_node_or_null("SkyMemories/SparseStars") as MeshInstance3D
	if old_star_field:
		old_star_field.hide()
	for path: NodePath in node_overrides:
		var target := world.get_node_or_null(path)
		if target == null:
			push_error("Maze02 lighting target is missing: " + str(path))
			continue
		for property: String in node_overrides[path]:
			target.set(property, node_overrides[path][property])
	_apply_cyan_fireflies(world)
	# Atmosphere and horizon materials are constructed per instance by the shared
	# generators. Preserve their identity: the meteor animation holds a reference.
	var visited: Dictionary = {}
	for branch: String in ["DreamAtmosphere", "SkyMemories"]:
		var container := world.get_node_or_null(branch)
		if container == null:
			continue
		for mesh: MeshInstance3D in container.find_children("*", "MeshInstance3D", true, false):
			if mesh.get_parent().name == &"ExteriorCloudBanks":
				# The local shader raises the bank above the original mesh bounds.
				mesh.extra_cull_margin = 5.0
			_bind_material(mesh.material_override, visited)
			_bind_material(mesh.material_overlay, visited)
			if mesh.mesh:
				for surface in mesh.mesh.get_surface_count():
					_bind_material(mesh.get_active_material(surface), visited)

func _bind_material(material: Material, visited: Dictionary) -> void:
	if material == null or visited.has(material):
		return
	visited[material] = true
	if material is ShaderMaterial and material.shader:
		var source: String = material.get_meta("maze02_source_shader", material.shader.resource_path)
		if shader_overrides.has(source):
			# Do not silently mutate an external material if the shared generator changes.
			if not material.resource_path.is_empty():
				push_error("Maze02 expected an instance-owned atmosphere material: " + material.resource_path)
				return
			material.set_meta("maze02_source_shader", source)
			material.shader = shader_overrides[source]
			if source.ends_with("/cloud_sea.gdshader"):
				material.set_shader_parameter("cloud_tint", cloud_tint)
			if source.ends_with("/distant_city.gdshader"):
				material.set_shader_parameter("mist", city_haze)
				material.set_shader_parameter("shade", city_haze.darkened(0.17))
				for key: StringName in [&"zenith", &"middle", &"horizon", &"nadir", &"cloud_color", &"sky_details"]:
					var value: Variant = environment.sky.sky_material.get_shader_parameter(key)
					if value != null:
						material.set_shader_parameter(key, value)
	_bind_material(material.next_pass, visited)

func _apply_cyan_fireflies(world: Node3D) -> void:
	for cluster: Node3D in world.get_node("DreamAtmosphere").get_children():
		if cluster.get_script() != Fireflies:
			continue
		for child: Node in cluster.get_children():
			if child is MeshInstance3D:
				if _cyan_glow == null:
					_cyan_glow = _make_cyan_glow(child.get_active_material(0))
				child.material_override = _cyan_glow
			elif child is OmniLight3D:
				child.light_color = Color("52ccf2")

func _make_cyan_glow(base: StandardMaterial3D) -> StandardMaterial3D:
	var paint := base.duplicate() as StandardMaterial3D
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.20, 0.38, 0.69, 1.0])
	colors.colors = PackedColorArray([Color("e1ffff"), Color("a8fff4f0"),
		Color("5cddea94"), Color("43bfd721"), Color("42bbd300")])
	var glow := GradientTexture2D.new()
	glow.width = 32
	glow.height = 32
	glow.gradient = colors
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	paint.albedo_texture = glow
	return paint
