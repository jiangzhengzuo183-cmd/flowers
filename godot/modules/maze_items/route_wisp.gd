extends Node3D

const Glow := preload("res://modules/maze_items/item_glow.gd")
const SPEED := 3.45
const TRAIL_LIFETIME := 0.44

var fading := false
var _path := PackedVector3Array()
var _next := 1
var _heading := Vector3.ZERO
var _turn_pause := 0.0
var _next_trail := 0
var _trail_clock := 0.0
var _trail: Array[MeshInstance3D] = []
var _trail_life := PackedFloat32Array()
var _motifs: Array[MeshInstance3D] = []
var _body := Node3D.new()
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _light: OmniLight3D
var _clock := 0.0
var _strength := 1.0

func _ready() -> void:
	add_child(_body)
	_halo = Glow.sprite(_body, 1.02, Color("55cbf4b5"))
	_core = Glow.sprite(_body, 0.38, Color("d5faff"))
	_core.material_override.render_priority = 2
	for i in 5:
		_motifs.append(Glow.sprite(_body, 0.11, Color("78deff")))
	_light = OmniLight3D.new()
	_light.light_color = Color("8be4ff")
	_light.light_energy = 0.30
	_light.light_specular = 0.06
	_light.omni_range = 2.05
	_body.add_child(_light)
	for i in 8:
		var bead := Glow.sprite(self, 0.29, Color("69cdf6b5"))
		bead.top_level = true
		bead.hide()
		_trail.append(bead)
		_trail_life.append(0.0)
	_body.position.y = 0.78

func follow(path: PackedVector3Array) -> void:
	_path = path
	_next = 1

func advance(delta: float, can_step: Callable) -> bool:
	if fading or _next >= _path.size():
		return true
	if _turn_pause > 0.0:
		_turn_pause -= delta
		return true
	var target := _path[_next]
	var offset := target - position
	if offset.length_squared() < 0.0001:
		_next += 1
		return true
	var direction := offset.normalized()
	if _heading != Vector3.ZERO and _heading.dot(direction) < 0.70:
		_turn_pause = 0.10
		_heading = direction
		return true
	var corner := _next + 1 < _path.size() and direction.dot((_path[_next + 1] - target).normalized()) < 0.78
	var speed := SPEED * 0.62 if corner and offset.length() < 0.29 else SPEED
	var next_position := position.move_toward(target, speed * delta)
	if not can_step.call(position, next_position):
		return false
	position = next_position
	_heading = direction
	_trail_clock -= delta
	if _trail_clock <= 0.0:
		_trail_clock = 0.070
		var bead := _trail[_next_trail]
		bead.global_position = _body.global_position
		bead.show()
		_trail_life[_next_trail] = TRAIL_LIFETIME
		_next_trail = (_next_trail + 1) % _trail.size()
	return true

func dissolve() -> void:
	if fading:
		return
	fading = true
	var fade := create_tween()
	fade.tween_property(self, "_strength", 0.0, 0.72).set_trans(Tween.TRANS_SINE)
	fade.tween_callback(queue_free)

func _process(delta: float) -> void:
	_clock += delta
	_body.position.y = 0.78 + sin(_clock * 4.3) * 0.055
	_halo.scale = Vector3.ONE * (1.0 + 0.13 * sin(_clock * 3.1))
	_set_opacity(_core, _strength)
	_set_opacity(_halo, _strength)
	_light.light_energy = (0.27 + 0.05 * sin(_clock * 3.1)) * _strength
	for i in _motifs.size():
		var phase := _clock * (1.1 + float(i) * 0.13) + TAU * float(i) / _motifs.size()
		var radius := 0.27 + float(i) * 0.027 + (1.0 - _strength) * 0.46
		_motifs[i].position = Vector3(cos(phase) * radius, sin(phase * 1.47) * radius * 0.65, sin(phase) * radius)
		_set_opacity(_motifs[i], _strength)
	for i in _trail.size():
		if _trail_life[i] > 0.0:
			_trail_life[i] = maxf(0.0, _trail_life[i] - delta)
			var ratio := _trail_life[i] / TRAIL_LIFETIME
			_set_opacity(_trail[i], ratio * ratio * 0.65 * _strength)
			_trail[i].scale = Vector3.ONE * (0.64 + 0.48 * ratio)
			if ratio == 0.0:
				_trail[i].hide()

func _set_opacity(particle: MeshInstance3D, opacity: float) -> void:
	var material := particle.material_override as StandardMaterial3D
	material.albedo_color.a = opacity
