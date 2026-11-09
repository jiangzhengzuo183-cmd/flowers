extends "res://art/environments/dream_lighting.gd"
## These overrides target existing nodes. They never build players, props or geometry.

@export var node_overrides: Dictionary = {}
@export var shader_overrides: Dictionary = {}

func apply(world: Node3D) -> void:
	super(world)
	for path: NodePath in node_overrides:
		var target := world.get_node_or_null(path)
		if target == null:
			push_error("Maze02 lighting target is missing: " + str(path))
			continue
		for property: String in node_overrides[path]:
			target.set(property, node_overrides[path][property])
	# Atmosphere and horizon materials are constructed per instance by the shared
	# generators. Preserve their identity: the meteor animation holds a reference.
	var visited: Dictionary = {}
	for branch: String in ["DreamAtmosphere", "SkyMemories"]:
		var container := world.get_node_or_null(branch)
		if container == null:
			continue
		for mesh: MeshInstance3D in container.find_children("*", "MeshInstance3D", true, false):
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
			if source.ends_with("/distant_city.gdshader"):
				for key: StringName in [&"zenith", &"middle", &"horizon", &"nadir", &"cloud_color", &"sky_details"]:
					var value: Variant = environment.sky.sky_material.get_shader_parameter(key)
					if value != null:
						material.set_shader_parameter(key, value)
	_bind_material(material.next_pass, visited)
