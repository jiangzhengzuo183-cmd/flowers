extends "res://scripts/levels/wall_occlusion.gd"
## Register the scene-local opaque plaster shader without changing shared Maze01/02 code.
func _register_wall(mesh: MeshInstance3D, generator: Node3D, player_occluder: bool, plaster_fade: Shader = null) -> void:
	var original: Material = mesh.material_override
	if not original is ShaderMaterial or original.shader!=preload("res://modules/maze03_final/wall_finish.gdshader"):
		super(mesh,generator,player_occluder,plaster_fade)
		return
	var id := _group_id(mesh,generator)
	if not groups.has(id):
		groups[id] = {"entries":[],"opacity":1.0,"last_seen":-1000.0}
	var faded := original.duplicate() as ShaderMaterial
	faded.shader = preload("res://modules/maze03_final/wall_fade.gdshader")
	faded.set_shader_parameter("opacity",1.0)
	for uniform: StringName in [&"stone_color",&"grain",&"legacy_winding"]:
		faded.set_shader_parameter(uniform,original.get_shader_parameter(uniform))
	groups[id].entries.append({"mesh":mesh,"original":original,"alpha":faded})
	var collider := mesh.get_parent()
	while collider!=generator and not collider is StaticBody3D:
		collider = collider.get_parent()
	if player_occluder:
		materials.append(faded)
		faded_mesh_count += 1
		if collider is StaticBody3D:
			_collider_groups[collider.get_instance_id()] = id
			collider.set_collision_layer_value(3,false)

func sight_blockers(camera_position: Vector3) -> Dictionary:
	var blocked := super(camera_position)
	# A soffit immediately in front of the lens must not sweep a tinted
	# transparent face over Charlie as the nine body rays change coverage.
	var query := PhysicsRayQueryParameters3D.create(camera_position, player.global_position+Vector3.UP*1.05, 1, [player.get_rid()])
	query.hit_from_inside = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and camera_position.distance_to(hit.position)<1.4:
		var id: String = _collider_groups.get(hit.collider.get_instance_id(), "")
		if not id.is_empty():
			blocked[id] = true
	return blocked
