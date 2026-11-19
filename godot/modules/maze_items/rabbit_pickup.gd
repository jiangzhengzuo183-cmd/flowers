extends Area3D

signal collected

const Model := preload("res://modules/maze_items/lucky_rabbit_foot.glb")
const Glow := preload("res://modules/maze_items/item_glow.gd")
const Sparkle := preload("res://modules/maze_items/rabbit_sparkle.svg")

var actor: CharacterBody3D
var claimed := false
var can_collect: Callable
var ground_display := false
var _ground_half_height := 0.46
var _display := Node3D.new()
var _sparkles: Array[Sprite3D] = []
var _pool: MeshInstance3D
var _halo: MeshInstance3D
var _light: OmniLight3D
var _time := 0.0
var _near := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = actor.collision_layer
	monitorable = false
	var sensor := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.70
	sensor.shape = sphere
	sensor.position.y = 0.79
	add_child(sensor)
	body_entered.connect(_on_body_entered)
	add_child(_display)
	var model := Model.instantiate() as Node3D
	_display.add_child(model)
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var bounds := _display.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
	var size := 0.92 / bounds.size.y
	model.scale *= size
	model.position -= bounds.get_center() * size
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pool = Glow.sprite(self, 1.90, Color("ffe6aac7"), false)
	_pool.rotation.x = -PI * 0.5
	_pool.position.y = 0.024
	_halo = Glow.sprite(_display, 1.06, Color("ffe8b057"))
	_light = OmniLight3D.new()
	_light.light_color = Color("ffe4b0")
	_light.omni_range = 1.85
	_light.light_specular = 0.05
	add_child(_light)
	_light.position.y = 0.51
	for i in 8:
		var star := Sprite3D.new()
		star.texture = Sparkle
		star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		star.render_priority = 1
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.modulate = Color("fff9ed") if i % 2 == 0 else Color("ffdda6")
		_display.add_child(star)
		_sparkles.append(star)
	_update_glow(0.0)

func _physics_process(_delta: float) -> void:
	if not claimed and actor.controls_enabled and overlaps_body(actor):
		_on_body_entered(actor)

func _process(delta: float) -> void:
	if not claimed:
		_update_glow(delta)

func _update_glow(delta: float) -> void:
	var attention := 1.0 - smoothstep(0.78, 2.65, actor.global_position.distance_to(global_position))
	_near = move_toward(_near, attention, delta * 2.6)
	_time += delta * (1.0 + 0.48 * _near)
	_display.position.y = _ground_half_height + 0.015 if ground_display else 0.99 + sin(_time * 1.85) * 0.135
	_display.rotation.y = _time * 0.63
	_pool.transparency = 0.28 - 0.22 * _near + 0.08 * sin(_time * 1.85)
	_pool.scale = Vector3.ONE * (1.0 + 0.17 * _near + 0.06 * sin(_time * 1.85))
	_halo.transparency = 0.44 - 0.24 * _near
	_light.light_energy = 0.14 + 0.16 * _near
	for i in _sparkles.size():
		var star := _sparkles[i]
		var offset := float(i) / _sparkles.size()
		var life := fposmod(_time * 0.46 + offset, 1.0)
		var angle := offset * TAU + life * 0.65
		var radius := 0.39 + 0.045 * (i % 3) + 0.09 * life + 0.08 * _near
		star.position = Vector3(cos(angle) * radius, -0.43 + 0.07 * (i % 3) + 0.77 * life, sin(angle) * radius)
		var glow := smoothstep(0.05, 0.30, life) * (1.0 - smoothstep(0.53, 0.95, life))
		var diameter := (0.14 + 0.04 * (i % 3)) * (0.60 + 0.40 * glow + 0.17 * _near)
		star.pixel_size = diameter / Sparkle.get_width()
		star.modulate.a = glow * (0.84 + 0.16 * _near)

func _on_body_entered(body: Node3D) -> void:
	if claimed or body != actor or not actor.controls_enabled:
		return
	if can_collect.is_valid() and not can_collect.call():
		return
	claimed = true
	set_deferred("monitoring", false)
	collected.emit()
	var flight := create_tween().set_parallel()
	flight.tween_method(_pull_to_actor.bind(_display.global_position), 0.0, 1.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_property(_display, "scale", Vector3.ONE * 0.06, 0.36)
	flight.tween_property(_pool, "transparency", 1.0, 0.31)
	flight.tween_property(_light, "light_energy", 0.0, 0.32)
	for star in _sparkles:
		flight.tween_property(star, "position", Vector3.ZERO, 0.27)
		flight.tween_property(star, "modulate:a", 0.0, 0.28)
	flight.finished.connect(queue_free)

func _pull_to_actor(weight: float, from: Vector3) -> void:
	var to := actor.global_position + Vector3.UP * 0.99
	_display.global_position = from.lerp(to, weight) + Vector3.UP * (sin(weight * PI) * 0.14)
