extends Area3D
signal crossed
@export_range(0.2,2.0,0.05) var flash_seconds := 0.8
@export_range(0.0,5.0,0.1) var crossing_light_energy := 1.8
@export_range(0.0,3.0,0.05) var idle_light_energy := 0.95
## Negative uses the shared stamina balance sheet; nonnegative overrides this barrier only.
@export var stamina_restore_override: float = -1.0
var stamina_recovery_used := false
var _entry_sides: Dictionary = {}
var _last_points: Dictionary = {}
var pulse := 0.0
var ripple_age := 10.0
var finish: ShaderMaterial
var local_light: OmniLight3D
var burst: CPUParticles3D
var frame_finish: ShaderMaterial
var touching: Array[Node3D] = []
var membrane_strength := 0.0
var membrane_target := Vector3(0,0.85,0)
var push_direction := 1.0
var recovery_age := 10.0
var was_touching := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var sensor := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.95,2.45,0.65)
	sensor.shape = box
	sensor.position.y = 1.2
	add_child(sensor)
	var surface := MeshInstance3D.new()
	surface.name = "FlowingEnergyMembrane"
	surface.mesh = _membrane_grid()
	surface.custom_aabb = AABB(Vector3(-1.05,-1.3,-0.3),Vector3(2.1,2.6,0.6))
	surface.position.y = 1.22
	finish = ShaderMaterial.new()
	finish.shader = preload("res://modules/maze03_final/energy.gdshader")
	surface.material_override = finish
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	local_light = OmniLight3D.new()
	local_light.name = "PersistentBlueBounce"
	local_light.position.y = 1.18
	local_light.omni_range = 3.6
	local_light.light_color = Color("64aaff")
	local_light.light_energy = idle_light_energy
	local_light.shadow_enabled = false
	add_child(local_light)
	_build_burst()
	_build_idle_drift()
	frame_finish = preload("res://modules/maze03_final/energy_frame_finish.gd").install(get_parent())
	body_entered.connect(_crossed)
	body_exited.connect(_left)

func _build_burst() -> void:
	burst = CPUParticles3D.new()
	burst.name = "CrossingLightFilaments"
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 18
	burst.lifetime = 0.60
	burst.explosiveness = 1.0
	burst.local_coords = false
	burst.position.y = 1.15
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	burst.emission_box_extents = Vector3(0.83,0.95,0.025)
	burst.direction = Vector3(0,0,1)
	burst.spread = 20
	burst.gravity = Vector3.ZERO
	burst.initial_velocity_min = 1.0
	burst.initial_velocity_max = 2.5
	var mesh := SphereMesh.new()
	mesh.radius = 0.009
	mesh.height = 0.030
	mesh.radial_segments = 4
	mesh.rings = 2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color("e0f4f4")
	mesh.material = material
	burst.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0,Color(0.6,0.9,1,0.9))
	fade.set_color(1,Color(0.6,0.9,1,0))
	burst.color_ramp = fade
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(burst)

func _crossed(body: Node3D) -> void:
	if body.has_method("apply_boost"):
		if body not in touching:
			touching.append(body)
		var id := body.get_instance_id()
		var local_feet := to_local(body.global_position)
		_entry_sides[id] = signf(local_feet.z) if absf(local_feet.z) > 0.08 else 0.0
		_last_points[id] = local_feet
		body.apply_boost()
		pulse = 1.0
		ripple_age = 0.0
		var contact := to_local(body.global_position+Vector3.UP*0.8)
		finish.set_shader_parameter("contact_uv",Vector2(clampf(contact.x/1.97+0.5,0.05,0.95),clampf(contact.y/2.45,0.05,0.95)))
		var forward: Vector3 = global_basis.inverse()*body.velocity
		burst.position = Vector3(contact.x,contact.y,0)
		burst.emission_box_extents = Vector3(0.32,0.60,0.025)
		burst.direction = Vector3(0,0,1 if forward.z>=0 else -1)
		burst.restart()
		burst.emitting = true
		crossed.emit()

func _process(delta: float) -> void:
	var proximity := 0.0
	var closest := INF
	for body: Node3D in touching.duplicate():
		if not is_instance_valid(body):
			touching.erase(body)
			continue
		var local := to_local(body.global_position+Vector3.UP*0.85)
		if absf(local.z)<closest and absf(local.x)<1.35:
			closest = absf(local.z)
			membrane_target = local
			proximity = 1.0-smoothstep(0.12,0.64,closest)
			var velocity: Vector3 = global_basis.inverse()*body.velocity
			if absf(velocity.z)>0.04:
				push_direction = signf(velocity.z)
	var contact_now := proximity>0.01
	if was_touching and not contact_now:
		recovery_age = 0.0
	was_touching = contact_now
	recovery_age += delta
	membrane_strength = lerpf(membrane_strength,proximity,1.0-exp(-delta*(18.0 if contact_now else 8.0)))
	pulse = move_toward(pulse,0.0,delta/maxf(0.1,flash_seconds))
	ripple_age += delta
	finish.set_shader_parameter("pulse",pulse)
	finish.set_shader_parameter("ripple_age",ripple_age)
	finish.set_shader_parameter("actor_center",Vector2(membrane_target.x,membrane_target.y))
	finish.set_shader_parameter("actor_strength",membrane_strength)
	finish.set_shader_parameter("push_direction",push_direction)
	finish.set_shader_parameter("recovery_age",recovery_age)
	local_light.light_energy = idle_light_energy+crossing_light_energy*pulse*pulse+membrane_strength*0.55
	frame_finish.set_shader_parameter("power",maxf(pulse,membrane_strength))

func _left(body: Node3D) -> void:
	_track_stamina_crossing(body)
	touching.erase(body)
	_entry_sides.erase(body.get_instance_id())
	_last_points.erase(body.get_instance_id())

func reset_contact() -> void:
	touching.clear()
	_entry_sides.clear()
	_last_points.clear()
	stamina_recovery_used = false
	membrane_strength = 0.0
	was_touching = false
	pulse = 0.0
	recovery_age = 10.0

func _membrane_grid() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.BACK)
	var columns := 48
	var rows := 60
	for y in rows:
		for x in columns:
			for corner: Vector2i in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				var uv := Vector2(x+corner.x,y+corner.y)/Vector2(columns,rows)
				st.set_uv(uv)
				st.add_vertex(Vector3((uv.x-0.5)*1.97,(uv.y-0.5)*2.45,0))
	st.index()
	return st.commit()

func _build_idle_drift() -> void:
	var motes := CPUParticles3D.new()
	motes.name = "QuietEnergyDrift"
	motes.amount = 8
	motes.lifetime = 2.8
	motes.preprocess = 2.8
	motes.local_coords = true
	motes.position.y = 1.1
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(0.90,0.75,0.025)
	motes.direction = Vector3.UP
	motes.spread = 5.0
	motes.gravity = Vector3.ZERO
	motes.initial_velocity_min = 0.12
	motes.initial_velocity_max = 0.24
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	mesh.radial_segments = 4
	mesh.rings = 1
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.vertex_color_use_as_albedo = true
	paint.albedo_color = Color("b1e9ff")
	paint.emission_enabled = true
	paint.emission = Color("6ac8f4")
	mesh.material = paint
	motes.mesh = mesh
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,0.2,0.7,1.0])
	fade.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.8),Color(1,1,1,0.5),Color(1,1,1,0)])
	motes.color_ramp = fade
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)



func _physics_process(_delta: float) -> void:
	for body: Node3D in touching:
		if is_instance_valid(body):
			_track_stamina_crossing(body)

func _track_stamina_crossing(body: Node3D) -> void:
	var id := body.get_instance_id()
	if stamina_recovery_used or not _entry_sides.has(id):
		return
	var point := to_local(body.global_position)
	var previous: Vector3 = _last_points.get(id, point)
	_last_points[id] = point
	if point.distance_to(previous) > 1.0:
		# Inspection teleports are not physical crossings.
		_entry_sides[id] = signf(point.z)
		return
	if absf(point.z) < 0.08:
		return
	var side := signf(point.z)
	if is_zero_approx(float(_entry_sides[id])):
		_entry_sides[id] = side
		return
	if side == float(_entry_sides[id]) or absf(point.x) > 1.08 or absf(point.z) > 0.85:
		return
	stamina_recovery_used = true
	var amount: float = body.stamina.settings.barrier_restore if stamina_restore_override < 0.0 else stamina_restore_override
	body.stamina.restore(amount, &"barrier")
