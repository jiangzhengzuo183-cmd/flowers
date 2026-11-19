extends Node

const COUNT := 4
const LIFETIME := 0.95
const STEP_LENGTH := 0.48
const COURT := preload("res://modules/maze03_final/sanctuary.gd").POOL

var _actor: CharacterBody3D
var _water: ShaderMaterial
var _surface: MeshInstance3D
var _drop_mesh: SphereMesh
var _drop_scale: Curve
var _level: float
var _hits := PackedVector4Array()
var _next := 0
var stamp_count := 0
var splash_count := 0
var _last := Vector3.ZERO
var _distance := 0.0
var _was_wading := false

func install(surface: MeshInstance3D, actor: CharacterBody3D, level: float) -> void:
	name = "FootstepRipples"
	_actor = actor
	_surface = surface
	_water = surface.material_override
	_level = level
	_last = actor.position
	process_physics_priority = 10
	_create_droplets()
	_hits.resize(COUNT)
	for i in COUNT:
		_hits[i] = Vector4(0.0, 0.0, LIFETIME, 0.0)
	_water.set_shader_parameter("step_ripples", _hits)
	surface.add_child(self)

func _physics_process(delta: float) -> void:
	var changed := false
	for i in COUNT:
		var hit := _hits[i]
		if hit.z < LIFETIME:
			hit.z = minf(hit.z + delta, LIFETIME)
			_hits[i] = hit
			changed = true
	var position := _actor.position
	var point := Vector2(position.x, position.z)
	var motion := position - _last
	var lateral := Vector2(motion.x, motion.z)
	var travel := lateral.length()
	var local_move := travel < 0.40 and absf(motion.y) < 0.32
	var in_court := COURT.has_point(point)
	var grounded := _actor.is_on_floor()
	var wading := in_court and grounded and position.y < _level - 0.025
	if local_move and in_court and _was_wading and not grounded and motion.y > delta * 0.8:
		_stamp(point, 1.4)
		_splash(&"SplashTakeoff", point, lateral, 10, 1.85)
		changed = true
	elif local_move and in_court and not grounded and _last.y >= _level and position.y < _level and motion.y < -delta * 0.90:
		_stamp(point, 1.9)
		_splash(&"SplashLanding", point, lateral, 15, 2.4)
		changed = true
	elif local_move and wading:
		_distance += travel
		if (not _was_wading and travel > 0.005) or _distance >= STEP_LENGTH:
			var running := travel > delta * 2.05
			_stamp(point, 1.28 if running else 0.64)
			if running:
				_splash(&"SplashRun", point, lateral, 8, 1.58)
			_distance = 0.0
			changed = true
	else:
		_distance = 0.0
	_was_wading = wading
	_last = position
	if changed:
		_water.set_shader_parameter("step_ripples", _hits)

func _stamp(point: Vector2, strength: float) -> void:
	stamp_count += 1
	_hits[_next] = Vector4(point.x, point.y, 0.0, strength)
	_next = (_next + 1) % COUNT

func _create_droplets() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b0edef")
	material.roughness = 0.27
	material.emission_enabled = true
	material.emission = Color("a0dddf")
	material.emission_energy_multiplier = 0.19
	_drop_mesh = SphereMesh.new()
	_drop_mesh.radius = 0.023
	_drop_mesh.height = 0.066
	_drop_mesh.radial_segments = 7
	_drop_mesh.rings = 3
	_drop_mesh.material = material
	_drop_scale = Curve.new()
	_drop_scale.add_point(Vector2(0.0, 0.83))
	_drop_scale.add_point(Vector2(0.20, 1.0))
	_drop_scale.add_point(Vector2(0.75, 0.75))
	_drop_scale.add_point(Vector2(1.0, 0.0))

func _splash(kind: StringName, point: Vector2, lateral: Vector2, count: int, speed: float) -> void:
	var emitter := CPUParticles3D.new()
	emitter.name = kind
	splash_count += 1
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = count
	emitter.lifetime = 0.44
	emitter.lifetime_randomness = 0.20
	emitter.explosiveness = 0.98
	emitter.mesh = _drop_mesh
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var back := lateral.normalized() * (-0.62 if kind == &"SplashRun" else -0.22)
	emitter.direction = Vector3(back.x, 1.0, back.y).normalized()
	emitter.spread = 46.0 if kind == &"SplashRun" else 61.0
	emitter.gravity = Vector3(0.0, -10.0, 0.0)
	emitter.initial_velocity_max = speed
	emitter.initial_velocity_min = speed * 0.63
	emitter.scale_amount_min = 0.58
	emitter.scale_amount_curve = _drop_scale
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.085
	emitter.position = Vector3(point.x, _level + 0.052, point.y)
	_surface.add_child(emitter, true)
	emitter.global_position = Vector3(point.x, _level + 0.052, point.y)
	emitter.finished.connect(emitter.queue_free)
	emitter.emitting = true
