extends Node3D
## Reusable visual asset. Root marks the foot placement anchor, local +Z faces forward.

enum State { IDLE, WALK, LOOK_AROUND, SOB }
@export var initial_state: State = State.IDLE
@export_range(0.1, 0.7) var opacity: float = 0.24
@export_range(0.2, 0.7) var garment_opacity: float = 0.48
@export_range(0.2, 0.7) var hair_opacity: float = 0.38
@export_range(0.0, 0.02) var float_amplitude: float = 0.006
@export_range(0.0, 0.025) var hem_sway: float = 0.014
@export var effects_enabled: bool = true
@export var particles_enabled: bool = true

var state: State = State.IDLE
var effect_time: float = 0.0
var player: AnimationPlayer
var skeleton: Skeleton3D
var model: Node3D
var surface_material: ShaderMaterial
var depth_material: ShaderMaterial
var arm_clearance: SkeletonModifier3D
var _visual: Node3D
var _motes: CPUParticles3D
var _halos: Array[ShaderMaterial] = []
var _mesh_nodes: Array[MeshInstance3D] = []

func _ready() -> void:
	_visual = $Visual
	model = $Visual/Model
	_motes = $MemoryMotes
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for child in model.find_children("*", "Skeleton3D", true, false):
		skeleton = child as Skeleton3D
	var folder := (get_script() as Script).resource_path.get_base_dir()
	if skeleton:
		arm_clearance = (load(folder.path_join("arm_clearance.gd")) as Script).new()
		arm_clearance.name = "ArmClearance"
		skeleton.add_child(arm_clearance)
		$MotionMotes.configure(skeleton, arm_clearance)
		arm_clearance.modification_processed.connect(_update_cloth_clearance)
	surface_material = (load(folder.path_join("MemoryShadeMaterial.tres")) as ShaderMaterial).duplicate()
	depth_material = ShaderMaterial.new()
	depth_material.shader = load(folder.path_join("shade_depth.gdshader"))
	depth_material.next_pass = surface_material
	depth_material.render_priority = -2
	surface_material.render_priority = -1
	var previous := surface_material
	for settings in [Vector2(0.003, 0.12), Vector2(0.006, 0.065), Vector2(0.010, 0.035), Vector2(0.016, 0.02)]:
		var halo := ShaderMaterial.new()
		halo.shader = load(folder.path_join("shade_halo.gdshader"))
		halo.set_shader_parameter("expansion", settings.x)
		halo.set_shader_parameter("strength", settings.y)
		halo.render_priority = _halos.size()
		previous.next_pass = halo
		previous = halo
		_halos.append(halo)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		mesh_node.material_override = depth_material
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mesh_nodes.append(mesh_node)
	if player:
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		# Match the source's 24 FPS time interval. Names in the GLB stay unchanged.
		for animation_name in player.get_animation_list():
			var clip := player.get_animation(animation_name)
			if animation_name.begins_with("walk") or animation_name.begins_with("look_around"):
				var loop_clip := clip.duplicate() as Animation
				loop_clip.loop_mode = Animation.LOOP_LINEAR
				player.get_animation_library("").remove_animation(animation_name)
				player.get_animation_library("").add_animation(animation_name, loop_clip)
	set_state(initial_state)
	_update_effects()

func set_state(next_state: State) -> void:
	state = next_state
	if player == null:
		return
	var prefix := "look_around"
	if state == State.WALK:
		prefix = "walk"
	elif state == State.SOB:
		prefix = "sob"
	for animation_name in player.get_animation_list():
		if animation_name.begins_with(prefix):
			player.speed_scale = 0.65 if state == State.LOOK_AROUND else 1.0
			player.play(animation_name, 0.25)
			if state == State.IDLE:
				player.seek(0.05, true)
				player.pause()
			return

func _process(delta: float) -> void:
	if effects_enabled:
		effect_time += delta
	_update_effects()

func _update_effects() -> void:
	if surface_material == null:
		return
	var visual_time := effect_time if effects_enabled else 0.0
	_visual.position.y = 0.012 + sin(visual_time * 1.24) * float_amplitude
	for material in [surface_material, depth_material] + _halos:
		material.set_shader_parameter("effect_time", visual_time)
		material.set_shader_parameter("hair_motion", 0.0015 if effects_enabled else 0.0)
		material.set_shader_parameter("hem_motion", hem_sway if effects_enabled else 0.0)
	surface_material.set_shader_parameter("opacity", opacity)
	surface_material.set_shader_parameter("garment_opacity", garment_opacity)
	surface_material.set_shader_parameter("hair_opacity", hair_opacity)
	surface_material.set_shader_parameter("breath_amount", 0.025 if effects_enabled else 0.0)
	_motes.emitting = particles_enabled
	_motes.visible = particles_enabled
	$MotionMotes.enabled = particles_enabled
	_motes.rotation.y = visual_time * 0.07

func _update_cloth_clearance() -> void:
	if surface_material == null or _mesh_nodes.is_empty():
		return
	var mesh_node := _mesh_nodes[0]
	var center := mesh_node.to_local(skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Spine01")).origin))
	for material in [surface_material, depth_material] + _halos:
		material.set_shader_parameter("torso_center", center)
	for side in ["L", "R"]:
		var elbow := mesh_node.to_local(skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(side + "_Forearm")).origin))
		var hand := mesh_node.to_local(skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(side + "_Hand")).origin))
		var tip := hand + (hand - elbow).normalized() * 0.055
		var prefix := "left_" if side == "L" else "right_"
		for material in [surface_material, depth_material] + _halos:
			material.set_shader_parameter(prefix + "elbow", elbow)
			material.set_shader_parameter(prefix + "hand", hand)
			material.set_shader_parameter(prefix + "tip", tip)
