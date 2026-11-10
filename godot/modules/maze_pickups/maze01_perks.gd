extends Node

const Glow := preload("res://modules/maze_items/item_glow.gd")
const Chime := preload("res://modules/maze_items/rabbit_pickup.wav")
const Dust := preload("res://modules/maze_pickups/flour_puff.gdshader")
const Inventory := preload("res://modules/maze_items/maze_inventory.gd")
const Player := preload("res://scripts/maze/walk_player.gd")
const CAKE_PATH := "res://modules/maze_pickups/chocolate_cake.tscn"
const FLOUR_PATH := "res://modules/maze_pickups/flour.tscn"
const CAKES := [Vector3(13.2, 0, 8.4), Vector3(37.2, 0, 25.2)]
const FLOUR := [Vector3(32.4, 0, 20.4), Vector3(13.2, 0, 34.8)]
const TRAIL_INTERVAL := 0.025
const TRAIL_LIFETIME := 0.48
const TRAIL_COLORS := [Color("ffca38"), Color("ffde64")]

var boost_multiplier := 1.3
var boost_seconds := 8.0
var flour_seconds := 3.0
var boost_remaining := 0.0
var flour_remaining := 0.0
var pickups: Array = []
var _actor: Player
var _world: Node3D
var _inventory: Inventory
var _sound: Callable
var _screen: ColorRect
var _flour_material: ShaderMaterial
var _bursts: Node3D
var _trail_mesh := ImmediateMesh.new()
var _trail: MeshInstance3D
var _trail_points: Array[Vector3] = []
var _trail_sides: Array[Vector3] = []
var _trail_times: Array[float] = []
var _trail_clock := 0.0
var _trail_delay := 0.0
var _trail_previous := Vector3.ZERO

func install(actor: Player, viewport_frame: Control, inventory: Inventory, sound: Callable) -> void:
	_actor = actor
	_world = actor.get_parent()
	_inventory = inventory
	_sound = sound
	_screen = ColorRect.new()
	_screen.name = "FlourScreen"
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flour_material = ShaderMaterial.new()
	_flour_material.shader = Dust
	_screen.material = _flour_material
	viewport_frame.add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bursts = Node3D.new()
	_world.add_child(_bursts)
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail_material.vertex_color_use_as_albedo = true
	_trail = MeshInstance3D.new()
	_trail.name = "CakeSpeedLines"
	_trail.mesh = _trail_mesh
	_trail.material_override = trail_material
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_trail)
	reset()

func reset() -> void:
	boost_remaining = 0.0
	flour_remaining = 0.0
	_actor.move_speed_multiplier = 1.0
	_screen.hide()
	_trail_previous = _actor.global_position
	_trail_clock = 0.0
	_trail_delay = 0.0
	_clear_trail()
	for burst in _bursts.get_children():
		burst.queue_free()
	for pickup in pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	pickups.clear()
	_spawn(load(CAKE_PATH), CAKES)
	_spawn(load(FLOUR_PATH), FLOUR)

func _spawn(scene: PackedScene, points: Array) -> void:
	for point: Vector3 in points:
		var pickup = scene.instantiate()
		pickup.actor = _actor
		pickup.position = point
		pickup.collected.connect(_apply.bind(pickup.effect, point))
		_world.add_child(pickup, true)
		pickups.append(pickup)

func _apply(effect: int, point: Vector3) -> void:
	_sound.call(Chime)
	if effect == 0:
		boost_remaining = boost_seconds
		_actor.move_speed_multiplier = boost_multiplier
		_inventory.show_notice("巧克力蛋糕 · 移动加速！")
	else:
		flour_remaining = flour_seconds
		_inventory.show_notice("视线受到干扰！")
	_burst(point, Color("ffe1a8d0") if effect == 0 else Color("fff9eae8"))
	_update_visuals()

func _process(delta: float) -> void:
	_update_trail(delta)
	if boost_remaining <= 0.0 and flour_remaining <= 0.0:
		return
	boost_remaining = maxf(0.0, boost_remaining - delta)
	flour_remaining = maxf(0.0, flour_remaining - delta)
	if boost_remaining == 0.0:
		_actor.move_speed_multiplier = 1.0
	_update_visuals()

func _update_visuals() -> void:
	_screen.visible = flour_remaining > 0.0
	if not _screen.visible:
		return
	_flour_material.set_shader_parameter("age", flour_seconds - flour_remaining)
	_flour_material.set_shader_parameter("opacity", smoothstep(0.0, 0.64, flour_remaining))

func _update_trail(delta: float) -> void:
	var position := _actor.global_position
	var motion := position - _trail_previous
	_trail_previous = position
	if motion.length_squared() > 0.75 * 0.75:
		_clear_trail()
		return
	if boost_remaining <= 0.0 and _trail_points.is_empty():
		return
	motion.y = 0.0
	_trail_clock += delta
	_trail_delay = maxf(0.0, _trail_delay - delta)
	var distance := motion.length()
	if boost_remaining > 0.0 and _trail_delay == 0.0 and distance > delta * 0.3:
		var direction := motion / distance
		_trail_points.append(position - direction * 0.24 + Vector3.UP * 0.48)
		_trail_sides.append(direction.cross(Vector3.UP))
		_trail_times.append(_trail_clock)
		_trail_delay = TRAIL_INTERVAL
	while not _trail_times.is_empty() and _trail_clock - _trail_times[0] >= TRAIL_LIFETIME:
		_trail_times.pop_front()
		_trail_sides.pop_front()
		_trail_points.pop_front()
	_draw_trail()

func _clear_trail() -> void:
	_trail_points.clear()
	_trail_sides.clear()
	_trail_times.clear()
	_trail_mesh.clear_surfaces()

func _draw_trail() -> void:
	_trail_mesh.clear_surfaces()
	var count := _trail_points.size()
	var camera := _actor.get_viewport().get_camera_3d()
	if count < 2 or camera == null:
		return
	for lane in TRAIL_COLORS.size():
		var color: Color = TRAIL_COLORS[lane]
		var offset := -0.29 if lane == 0 else 0.29
		_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in count:
			var point := _trail_points[i] + _trail_sides[i] * offset + Vector3.UP * 0.08 * lane
			var before := _trail_points[maxi(0, i - 1)]
			var after := _trail_points[mini(count - 1, i + 1)]
			var width_direction := (after - before).cross(camera.global_position - point).normalized()
			var life := 1.0 - (_trail_clock - _trail_times[i]) / TRAIL_LIFETIME
			var head_taper := smoothstep(0.0, 3.0, float(count - 1 - i))
			var width := (0.026 if lane == 0 else 0.019) * smoothstep(0.0, 0.68, life) * lerpf(0.42, 1.0, head_taper)
			var alpha := 0.93 * smoothstep(0.0, 0.85, life) * lerpf(0.58, 1.0, head_taper)
			_trail_mesh.surface_set_color(Color(color, alpha))
			_trail_mesh.surface_add_vertex(_trail.to_local(point - width_direction * width))
			_trail_mesh.surface_add_vertex(_trail.to_local(point + width_direction * width))
		_trail_mesh.surface_end()

func _burst(point: Vector3, tint: Color) -> void:
	var burst := Node3D.new()
	_bursts.add_child(burst)
	burst.position = point + Vector3.UP * 0.99
	var flight := burst.create_tween().set_parallel()
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var mote := Glow.sprite(burst, 0.15 + float(i % 3) * 0.047, tint)
		var destination := Vector3(cos(angle) * 0.46, 0.14 + float(i % 3) * 0.15, sin(angle) * 0.46)
		flight.tween_property(mote, "position", destination, 0.43).set_ease(Tween.EASE_OUT)
		flight.tween_property(mote.material_override, "albedo_color:a", 0.0, 0.43)
	flight.finished.connect(burst.queue_free)
