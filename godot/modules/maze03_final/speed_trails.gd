extends Node3D
## Four frozen skeleton poses share the original meshes; no live animation or CPU mesh baking.
@export_range(2,5,1) var maximum_ghosts := 4
@export_range(0.08,0.25,0.01) var snapshot_interval := 0.12
@export_range(0.2,0.7,0.01) var ghost_lifetime := 0.46
var actor: CharacterBody3D
var stamp_count := 0
var sources: Array[MeshInstance3D] = []
var skeleton_sources: Array[Skeleton3D] = []
var ghosts: Array[Dictionary] = []
var cursor := 0
var clock := 0.0
var previous := Vector3.ZERO
var sampled := Vector3.ZERO
func _ready() -> void:
	name = "CharliePoseAfterimages"
	top_level = true
	global_transform = Transform3D.IDENTITY
	process_priority = 80
	# Finish.apply must complete before adding decorative meshes under the player.
	_build_pool.call_deferred()
func _build_pool() -> void:
	for source: MeshInstance3D in actor.visual.find_children("*","MeshInstance3D",true,false):
		if source.mesh!=null and source.is_visible_in_tree():
			sources.append(source)
			var skeleton := source.get_node_or_null(source.skeleton) as Skeleton3D
			if skeleton!=null and skeleton not in skeleton_sources:
				skeleton_sources.append(skeleton)
	for i in maximum_ghosts:
		var group := Node3D.new()
		group.name = "FrozenPose"+str(i)
		add_child(group)
		var paint := ShaderMaterial.new()
		paint.shader = preload("res://modules/maze03_final/afterimage.gdshader")
		paint.set_shader_parameter("phase",float(i)*1.7)
		var skeletons: Dictionary = {}
		for source in skeleton_sources:
			var skeleton := Skeleton3D.new()
			skeleton.name = "FrozenSkeleton"
			group.add_child(skeleton)
			for bone in source.get_bone_count():
				skeleton.add_bone(source.get_bone_name(bone))
				skeleton.set_bone_parent(bone,source.get_bone_parent(bone))
				skeleton.set_bone_rest(bone,source.get_bone_rest(bone))
			skeletons[source] = skeleton
		var meshes: Array[MeshInstance3D] = []
		for source in sources:
			var mesh := MeshInstance3D.new()
			mesh.mesh = source.mesh
			mesh.material_override = paint
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.add_child(mesh)
			var original := source.get_node_or_null(source.skeleton) as Skeleton3D
			if skeletons.has(original):
				mesh.skeleton = mesh.get_path_to(skeletons[original])
				mesh.skin = source.skin
			meshes.append(mesh)
		group.hide()
		ghosts.append({"root":group,"material":paint,"meshes":meshes,"skeletons":skeletons,"age":ghost_lifetime})
	previous = actor.global_position
	sampled = previous
func _process(delta: float) -> void:
	if ghosts.is_empty():
		return
	for ghost in ghosts:
		ghost.age += delta
		ghost.material.set_shader_parameter("life",clampf(1.0-ghost.age/ghost_lifetime,0.0,1.0))
		ghost.root.visible = ghost.age<ghost_lifetime
	var travel := actor.global_position.distance_to(previous)
	previous = actor.global_position
	var moving: bool = actor.boost_remaining>0.0 and actor.controls_enabled and travel>0.002 and travel<1.0
	clock += delta
	if not moving:
		clock = snapshot_interval
		return
	if clock>=snapshot_interval and actor.global_position.distance_to(sampled)>0.20:
		_snapshot()
		clock = 0.0
		sampled = actor.global_position
func _snapshot() -> void:
	var ghost: Dictionary = ghosts[cursor]
	ghost.age = 0.0
	ghost.root.show()
	for source: Skeleton3D in skeleton_sources:
		var skeleton: Skeleton3D = ghost.skeletons[source]
		skeleton.global_transform = source.global_transform
		for bone in source.get_bone_count():
			skeleton.set_bone_pose_position(bone,source.get_bone_pose_position(bone))
			skeleton.set_bone_pose_rotation(bone,source.get_bone_pose_rotation(bone))
			skeleton.set_bone_pose_scale(bone,source.get_bone_pose_scale(bone))
	for i in sources.size():
		var source := sources[i]
		var mesh: MeshInstance3D = ghost.meshes[i]
		mesh.visible = source.is_visible_in_tree()
		mesh.global_transform = source.global_transform
	cursor = (cursor+1)%maximum_ghosts
	stamp_count += 1
func clear() -> void:
	for ghost in ghosts:
		ghost.age = ghost_lifetime
		ghost.root.hide()
	sampled = actor.global_position
	previous = sampled

