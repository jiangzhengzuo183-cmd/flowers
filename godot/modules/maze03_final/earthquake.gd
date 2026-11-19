extends Node3D
## A bounded scene-local event. Decorations have no collision and never alter masonry.
@export_range(1,2,1) var minimum_events := 2
@export_range(1,2,1) var maximum_events := 2
@export var first_delay := Vector2(24.0,38.0)
@export var repeat_gap := Vector2(55.0,88.0)
@export_range(1.5,5.0,0.1) var shake_seconds := 3.4
var actor: CharacterBody3D
var rig: Node3D
var sound: Node
var generator: Node3D
var enclosure: Node3D
var elapsed := 0.0
var event_age := 10.0
var planned_events := 1
var events_started := 0
var next_event := 0.0
@export_range(0.0,6.0,0.1) var comet_quake_delay := 2.0
var linked_comet: MeshInstance3D
@export var minor_interval := Vector2(15.0,24.0)
var minor_next := 12.0
var minor_age := 10.0
var minor_count := 0
var strength := 0.0
var impact := 0.0
var impact_sign := 1.0
var local_emitters: Array[Dictionary] = []
var remote_emitters: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func install(map: Node3D,player: CharacterBody3D,camera_rig: Node3D,audio: Node,horizon: Node3D) -> void:
	name = "OccasionalSpaceResonance"
	actor = player
	generator = map
	rig = camera_rig
	sound = audio
	enclosure = horizon
	player.get_parent().add_child(self)
	process_priority = 40
	rng.randomize()
	for i in 4:
		local_emitters.append(_emitter(false,i))
	for i in 3:
		remote_emitters.append(_emitter(true,i))
	sound.prepare_quake()
	reset_run()

func reset_run() -> void:
	elapsed = 0.0
	minor_age = 10.0
	minor_count = 0
	minor_next = rng.randf_range(9.0,15.0)
	events_started = 0
	planned_events = rng.randi_range(minimum_events,maximum_events)
	next_event = INF if is_instance_valid(linked_comet) else rng.randf_range(first_delay.x,first_delay.y)
	if is_instance_valid(linked_comet):
		linked_comet.reset_run()
	event_age = shake_seconds+8.0
	strength = 0.0
	impact = 0.0
	if is_instance_valid(enclosure):
		enclosure.get_node("SlowMegastructureMotion").shock = 0.0
		enclosure.get_node("SlowMegastructureMotion").resonance = 0.0
	if is_instance_valid(rig):
		rig.earthquake_strength = 0.0
		rig.earthquake_impulse = 0.0
	for effect in local_emitters+remote_emitters:
		effect.dust.emitting = false
		effect.chips.emitting = false
		effect.root.hide()

func _emitter(remote: bool,index: int) -> Dictionary:
	var group := Node3D.new()
	group.name = ("GiantDustFall" if remote else "WallDustFall")+str(index)
	add_child(group)
	var dust := CPUParticles3D.new()
	dust.name = "FallingStonePowder"
	dust.emitting = false
	dust.one_shot = true
	dust.explosiveness = 0.25
	dust.amount = 96 if remote else 22
	dust.lifetime = 6.0 if remote else 3.2
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(12,0.5,2) if remote else Vector3(0.9,0.08,0.15)
	dust.direction = Vector3.DOWN
	dust.spread = 35.0
	dust.gravity = Vector3(0,-0.7 if remote else -0.13,0)
	dust.initial_velocity_min = 5.0 if remote else 0.25
	dust.initial_velocity_max = 8.0 if remote else 0.7
	dust.scale_amount_min = 3.8 if remote else 0.14
	dust.scale_amount_max = 7.5 if remote else 0.38
	dust.layers = 8 if remote else 1
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://modules/maze03_final/stone_powder.gdshader")
	paint.set_shader_parameter("powder_tint",Color(0.57,0.67,0.75,0.48) if remote else Color(0.64,0.66,0.63,0.30))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = paint
	dust.mesh = quad
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,0.12,0.60,1.0])
	fade.colors = PackedColorArray([Color(1,1,1,0),Color.WHITE,Color(1,1,1,0.6),Color(1,1,1,0)])
	dust.color_ramp = fade
	group.add_child(dust)
	var chips := CPUParticles3D.new()
	chips.name = "SmallFallingChips"
	chips.emitting = false
	chips.one_shot = true
	chips.explosiveness = 0.50
	chips.amount = 24 if remote else 12
	chips.lifetime = 4.2 if remote else 1.4
	chips.local_coords = false
	chips.emission_shape = dust.emission_shape
	chips.emission_box_extents = dust.emission_box_extents
	chips.direction = Vector3.DOWN
	chips.spread = 50.0
	chips.gravity = Vector3(0,-7,0)
	chips.initial_velocity_min = 0.15
	chips.initial_velocity_max = 1.2
	chips.angular_velocity_min = -110.0
	chips.angular_velocity_max = 160.0
	chips.scale_amount_min = 0.4
	chips.scale_amount_max = 1.3
	chips.layers = dust.layers
	chips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var chip := SphereMesh.new()
	chip.radius = 0.42 if remote else 0.045
	chip.height = 0.90 if remote else 0.11
	chip.radial_segments = 5
	chip.rings = 1
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("f6f5ef") if remote else Color("f0eee5")
	stone.roughness = 0.95
	stone.emission_enabled = true
	stone.emission = Color(0.08,0.08,0.075)
	chip.material = stone
	chips.mesh = chip
	var shrink := Curve.new()
	shrink.add_point(Vector2(0,1))
	shrink.add_point(Vector2(0.7,0.8))
	shrink.add_point(Vector2(1,0))
	chips.scale_amount_curve = shrink
	group.add_child(chips)
	return {"root":group,"dust":dust,"chips":chips}

func trigger_event() -> bool:
	if events_started>=planned_events or event_age<shake_seconds:
		return false
	events_started += 1
	minor_age = 10.0
	minor_next = elapsed+rng.randf_range(minor_interval.x,minor_interval.y)
	next_event = INF if is_instance_valid(linked_comet) else elapsed+rng.randf_range(repeat_gap.x,repeat_gap.y)
	event_age = 0.0
	impact_sign = -1.0 if rng.randf()<0.5 else 1.0
	sound.play_quake()
	var walls: Array[Node3D] = []
	for group_name in ["VerticalWalls","HorizontalWalls"]:
		for wall: Node3D in generator.get_node(group_name).get_children():
			walls.append(wall)
	walls.sort_custom(func(a: Node3D,b: Node3D): return a.global_position.distance_squared_to(actor.global_position)<b.global_position.distance_squared_to(actor.global_position))
	for i in local_emitters.size():
		var wall := walls[mini(i,walls.size()-1)]
		var mesh := wall.get_child(0) as MeshInstance3D
		var p := mesh.to_global(mesh.get_aabb().get_center())
		p.y = mesh.to_global(Vector3(0,mesh.get_aabb().end.y,0)).y
		_release(local_emitters[i],p+Vector3(0,0.04,0))
	var ids := ["NortheastCurvedMonolith","NorthwestRaisedDisc","SouthwestConnectedTwins"]
	for i in ids.size():
		var giant: Node3D = enclosure.middle.get_node(ids[i])
		var bounds: AABB = giant.get_node("ContinuousWhiteVolume").get_aabb()
		var lip := Vector3(42.0,100.0,28.0) if i==0 else (Vector3(0,27.0,44.0) if i==1 else Vector3(15.0,132.0,9.7))
		var p := giant.to_global(lip)
		var effect: Dictionary = remote_emitters[i]
		effect.root.global_basis = giant.global_basis
		effect.dust.emission_box_extents = Vector3(5.0 if i==0 else (15.0 if i==1 else 4.0),0.3,1.0)
		effect.chips.emission_box_extents = effect.dust.emission_box_extents
		_release(effect,p)
	return true

func _release(effect: Dictionary,point: Vector3) -> void:
	effect.root.global_position = point
	effect.root.show()
	effect.dust.restart()
	effect.chips.restart()
	effect.dust.emitting = true
	effect.chips.emitting = true

func _process(delta: float) -> void:
	if actor.controls_enabled and rig.enabled and not actor.visual.celebrating:
		elapsed += delta
		if elapsed>=next_event and events_started<planned_events:
			trigger_event()
		elif elapsed>=minor_next and event_age>6.0:
			trigger_minor()
	event_age += delta
	minor_age += delta
	var u := event_age/shake_seconds
	strength = smoothstep(0.0,0.16,u)*(1.0-smoothstep(0.42,1.0,u)) if u<1.0 else 0.0
	var small := sin(clampf(minor_age/1.25,0.0,1.0)*PI)*0.17 if minor_age<1.25 else 0.0
	strength = maxf(strength,small)
	# A fast attack, then one smaller opposite rebound before the existing tremor.
	var attack := smoothstep(0.0,0.045,event_age)*(1.0-smoothstep(0.08,0.22,event_age))
	var rebound := sin(clampf((event_age-0.18)/0.55,0.0,1.0)*PI)*0.25
	impact = (attack-rebound)*impact_sign
	rig.earthquake_impulse = impact
	rig.earthquake_strength = strength
	enclosure.get_node("SlowMegastructureMotion").resonance = strength
	enclosure.get_node("SlowMegastructureMotion").shock = impact
	if event_age>6.0:
		for effect in local_emitters+remote_emitters:
			effect.root.hide()

func _exit_tree() -> void:
	if is_instance_valid(rig):
		rig.earthquake_strength = 0.0



func trigger_minor() -> bool:
	if event_age<6.0 or minor_age<2.0:
		return false
	minor_count += 1
	minor_age = 0.0
	minor_next = elapsed+rng.randf_range(minor_interval.x,minor_interval.y)
	sound.play_minor_quake()
	return true



func bind_comet(comet: MeshInstance3D) -> void:
	linked_comet=comet
	comet.flight_finished.connect(_after_comet)
	next_event=INF
func _after_comet() -> void:
	if events_started<planned_events and is_inf(next_event):
		next_event=elapsed+comet_quake_delay
