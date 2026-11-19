extends Area3D
## Each former door is now a non-blocking trigger. No gate/switch/key dependency.
signal crossed(actor: Node3D)
@export_range(1.0, 2.5, 0.05) var speed_multiplier := 1.35
@export_range(0.1, 8.0, 0.1) var duration_seconds := 2.0
@export var opening_width := 1.8
@export var opening_height := 2.5
var surface: MeshInstance3D
var energy: ShaderMaterial
var ripple_age := 10.0
var pulse := 0.0
var _entry_sides: Dictionary = {}
func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var box := BoxShape3D.new()
	box.size = Vector3(opening_width, opening_height, 0.5)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.position.y = opening_height * 0.5
	add_child(collider)
	energy = ShaderMaterial.new()
	energy.shader = preload("res://art/maze03/energy.gdshader")
	surface = MeshInstance3D.new()
	surface.name = "EnergySurface"
	var quad := QuadMesh.new()
	quad.size = Vector2(opening_width, opening_height)
	surface.mesh = quad
	surface.position.y = opening_height * 0.5
	surface.material_override = energy
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	body_entered.connect(_entered)
	body_exited.connect(_exited)
func _entered(body: Node3D) -> void:
	if body.has_method("apply_barrier_boost"):
		_entry_sides[body.get_instance_id()] = signf(to_local(body.global_position).z)
func _exited(body: Node3D) -> void:
	_entry_sides.erase(body.get_instance_id())
func _physics_process(_delta: float) -> void:
	# Trigger on crossing the center plane, including turns made while overlapping.
	for body: Node3D in get_overlapping_bodies():
		if not body.has_method("apply_barrier_boost"):
			continue
		var id := body.get_instance_id()
		var z := to_local(body.global_position).z
		var side := signf(z)
		var previous: float = _entry_sides.get(id, side)
		if absf(z) > 0.015 and side != previous:
			body.apply_barrier_boost(speed_multiplier, duration_seconds)
			pulse = 1.0
			ripple_age = 0.0
			crossed.emit(body)
			_entry_sides[id] = side
func _process(delta: float) -> void:
	ripple_age += delta
	pulse = move_toward(pulse, 0.0, delta * 2.0)
	energy.set_shader_parameter("pulse", pulse)
	energy.set_shader_parameter("ripple_age", ripple_age)
