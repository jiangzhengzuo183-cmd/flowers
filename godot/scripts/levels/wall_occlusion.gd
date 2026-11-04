extends Node
## Real camera-to-character ray hits select whole wall segments for alpha blending.

const FADE_SHADER := preload("res://scripts/levels/wall_occlusion.gdshader")
var player: CharacterBody3D
var rig: Node3D
var materials: Array[ShaderMaterial] = []
var faded_mesh_count := 0
var strength := 0.0
var groups: Dictionary = {}
var _collider_groups: Dictionary = {}
var _clock := 0.0
var last_blockers: Dictionary = {}
var target_opacity := 0.22
var restore_delay := 0.10
var hidden_fraction := 0.85
var release_fraction := 0.80
var last_hidden_fraction := 0.0

func configure(generator: Node3D,actor: CharacterBody3D,camera_rig: Node3D,settings: Dictionary = {}) -> void:
	player = actor
	rig = camera_rig
	target_opacity = clampf(float(settings.get("opacity",0.22)),0.05,0.8)
	restore_delay = clampf(float(settings.get("restore_delay",0.10)),0.0,0.3)
	hidden_fraction = clampf(float(settings.get("hidden_fraction",0.85)),0.5,1.0)
	release_fraction = minf(hidden_fraction,float(settings.get("release_fraction",0.80)))
	process_priority = 20
	for mesh: MeshInstance3D in generator.find_children("*","MeshInstance3D",true,false):
		if _is_building(mesh,generator):
			continue
		var part := str(mesh.get_meta("greybox_part",mesh.name))
		if not _can_fade(part):
			continue
		var original: Material = mesh.material_override
		if original==null:
			original = mesh.mesh.surface_get_material(0)
		if not original is StandardMaterial3D:
			continue
		var id := _group_id(mesh,generator)
		if not groups.has(id):
			groups[id] = {"entries":[],"opacity":1.0,"last_seen":-1000.0}
		var material := ShaderMaterial.new()
		material.shader = FADE_SHADER
		material.set_shader_parameter("stone_color",original.albedo_color)
		material.set_shader_parameter("stone_roughness",original.roughness)
		material.set_shader_parameter("opacity",1.0)
		materials.append(material)
		groups[id].entries.append({"mesh":mesh,"original":original,"alpha":material})
		faded_mesh_count += 1
		var parent: Node = mesh.get_parent()
		while parent!=generator and not parent is StaticBody3D:
			parent = parent.get_parent()
		if parent is StaticBody3D:
			_collider_groups[parent.get_instance_id()] = id
			# Walking/visibility physics remain on layer 1. These walls no
			# longer force camera motion: only true ceilings still do that.
			parent.set_collision_layer_value(3,false)

func _is_building(mesh: Node,generator: Node) -> bool:
	var parent := mesh.get_parent()
	while parent!=generator:
		if str(parent.name) in ["CentralRoundHall","G6","G7","G8"]:
			return true
		parent = parent.get_parent()
	return false

func _group_id(mesh: MeshInstance3D,generator: Node3D) -> String:
	var parent: Node = mesh.get_parent()
	while parent!=generator:
		var label := str(parent.name)
		if parent.has_meta("occlusion_group"):
			return str(parent.get_instance_id())
		if label in ["G1","G2","G3","G4","G5","G6","G7","G8","D1","D2","D3","D4"]:
			return str(parent.get_instance_id())
		parent = parent.get_parent()
	parent = mesh.get_parent()
	while parent!=generator and not parent is StaticBody3D:
		parent = parent.get_parent()
	return str(parent.get_instance_id()) if parent is StaticBody3D else str(mesh.get_instance_id())

func _can_fade(part: String) -> bool:
	for prefix: String in ["WallSegment_","CurvedWall","PorchWall","LeftPier","RightPier","Lintel","ArchStone","WallAboveArch","Window","Pilaster","Capital","Base","Plinth","Cornice","ArchFrame","RetainingWall","TunnelEnd","UnderpassBeam","Bar","Crossbar"]:
		if part.begins_with(prefix):
			return true
	return false

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(rig):
		return
	_clock += delta
	last_blockers = sight_blockers(rig.camera.global_position) if rig.enabled else {}
	if not rig.enabled:
		last_hidden_fraction = 0.0
	for id: String in last_blockers:
		groups[id].last_seen = _clock
	strength = 0.0
	for id: String in groups:
		var group: Dictionary = groups[id]
		var blocked: bool = rig.enabled and _clock-float(group.last_seen)<=restore_delay
		var desired := target_opacity if blocked else 1.0
		var previous := float(group.opacity)
		group.opacity = move_toward(float(group.opacity),desired,delta*(5.0 if blocked else 3.5))
		strength = maxf(strength,1.0-float(group.opacity))
		if is_equal_approx(previous,float(group.opacity)):
			continue
		for entry: Dictionary in group.entries:
			if float(group.opacity)>=0.999:
				entry.mesh.material_override = entry.original
			else:
				entry.alpha.set_shader_parameter("opacity",group.opacity)
				entry.mesh.material_override = entry.alpha

func sight_blockers(camera_position: Vector3) -> Dictionary:
	var blocked: Dictionary = {}
	var right: Vector3 = rig.camera.global_basis.x
	var hidden_rays := 0
	# These nine rays hit the actual wall collision shapes in front of the
	# visible body, rather than fading things because Charlie is nearby.
	for height: float in [0.40,0.95,1.50]:
		for offset: float in [-0.25,0.0,0.25]:
			var end := player.global_position+Vector3(0,height,0)+right*offset
			var excluded: Array[RID] = [player.get_rid()]
			var ray_hidden := false
			for layer in 16:
				var query := PhysicsRayQueryParameters3D.create(camera_position,end,1,excluded)
				query.hit_from_inside = true
				var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty():
					break
				var collider: Object = hit.collider
				# Gate bars use one full movement box; that box is not an
				# opaque visual surface, since Charlie is visible through its gaps.
				if str(collider.name)=="MovingGate":
					excluded.append(hit.rid)
					continue
				if not _collider_groups.has(collider.get_instance_id()):
					break
				blocked[_collider_groups[collider.get_instance_id()]] = true
				ray_hidden = true
				excluded.append(hit.rid)
			if ray_hidden:
				hidden_rays += 1
	last_hidden_fraction = hidden_rays/9.0
	var threshold := release_fraction if strength>0.01 else hidden_fraction
	return blocked if last_hidden_fraction>=threshold else {}
