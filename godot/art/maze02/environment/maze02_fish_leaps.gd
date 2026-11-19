extends Node3D
## Adds occasional leaps to the existing swimmers after their swim animation runs.

const RippleShader := preload("res://art/maze02/environment/fish_ripple.gdshader")
const LEAP_SECONDS := 0.48
const SETTLE_SECONDS := 0.28
const RIPPLE_SECONDS := 0.83
var _water: float
var _fish: Array[Node3D] = []
var _sprays: Array[CPUParticles3D] = []
var _rings: Array[MeshInstance3D] = []
var _ring_age := PackedFloat32Array([1.0, 1.0])
var _random := RandomNumberGenerator.new()
var _until_leap := 2.8
var _leap_age := LEAP_SECONDS + SETTLE_SECONDS
var _leaping := -1
var _above_water := false

func install(courtyard: Node3D, water_level: float) -> void:
	name = "Maze02FishLeaps"
	_water = water_level
	_random.seed = 57139
	process_priority = 12
	for fish: Node in courtyard.get_node("PoolGoldfish").get_children():
		if fish is Node3D and String(fish.name).begins_with("Goldfish"):
			_fish.append(fish)
	if _fish.is_empty():
		queue_free()
		return
	courtyard.add_child(self)
	_build_splashes()

func _process(delta: float) -> void:
	for i in _rings.size():
		if _ring_age[i] >= 1.0:
			continue
		_ring_age[i] = minf(1.0, _ring_age[i] + delta / RIPPLE_SECONDS)
		_rings[i].material_override.set_shader_parameter("age", _ring_age[i])
		_rings[i].visible = _ring_age[i] < 1.0

	_until_leap -= delta
	if _until_leap <= 0.0:
		_leaping = (_leaping + 1) % _fish.size()
		_leap_age = 0.0
		_above_water = false
		_until_leap = _random.randf_range(3.2, 5.7)
	if _leap_age >= LEAP_SECONDS + SETTLE_SECONDS:
		return
	_leap_age = minf(_leap_age + delta, LEAP_SECONDS + SETTLE_SECONDS)
	var progress := minf(_leap_age / LEAP_SECONDS, 1.0)
	var swimmer := _fish[_leaping]
	var forward := -swimmer.basis.z
	var heading := Vector3(forward.x, 0.0, forward.z).normalized()
	var settle := 1.0 - smoothstep(LEAP_SECONDS, LEAP_SECONDS + SETTLE_SECONDS, _leap_age)
	swimmer.position += heading * (0.25 * progress * settle)
	swimmer.position.y += 0.32 * 4.0 * progress * (1.0 - progress)
	swimmer.rotation.x = (1.0 - 2.0 * progress) * 0.69 * sin(PI * progress)
	var above := swimmer.global_position.y >= _water
	if above != _above_water:
		_splash(0 if above else 1, swimmer.global_position)
		_above_water = above

func _splash(index: int, point: Vector3) -> void:
	var position := Vector3(point.x, _water + 0.020, point.z)
	var spray := _sprays[index]
	spray.global_position = position
	spray.restart()
	spray.emitting = true
	_rings[index].global_position = position
	_ring_age[index] = 0.0
	_rings[index].material_override.set_shader_parameter("age", 0.0)
	_rings[index].show()

func _build_splashes() -> void:
	var water_drop := StandardMaterial3D.new()
	water_drop.albedo_color = Color("b5e8e5")
	water_drop.roughness = 0.25
	water_drop.emission_enabled = true
	water_drop.emission = Color("c1ede7")
	water_drop.emission_energy_multiplier = 0.13
	var droplet := SphereMesh.new()
	droplet.radius = 0.011
	droplet.height = 0.033
	droplet.radial_segments = 6
	droplet.rings = 3
	droplet.material = water_drop
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.95))
	shrink.add_point(Vector2(0.64, 0.78))
	shrink.add_point(Vector2(1.0, 0.0))
	for i in 2:
		var spray := CPUParticles3D.new()
		spray.name = "LeapSpray" if i == 0 else "LandingSpray"
		spray.emitting = false
		spray.one_shot = true
		spray.amount = 5 if i == 0 else 11
		spray.explosiveness = 1.0
		spray.lifetime = 0.43
		spray.lifetime_randomness = 0.19
		spray.direction = Vector3.UP
		spray.spread = 53.0 if i == 0 else 68.0
		spray.gravity = Vector3(0, -8.6, 0)
		spray.initial_velocity_min = 0.72 if i == 0 else 0.98
		spray.initial_velocity_max = 1.55 if i == 0 else 1.95
		spray.scale_amount_curve = shrink
		spray.mesh = droplet
		spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spray)
		_sprays.append(spray)

		var ripple := MeshInstance3D.new()
		ripple.name = "LeapRipple" if i == 0 else "LandingRipple"
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * (0.57 if i == 0 else 0.78)
		ripple.mesh = plane
		var surface := ShaderMaterial.new()
		surface.shader = RippleShader
		surface.render_priority = 4
		surface.set_shader_parameter("strength", 0.38 if i == 0 else 0.53)
		ripple.material_override = surface
		ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ripple.hide()
		add_child(ripple)
		_rings.append(ripple)
