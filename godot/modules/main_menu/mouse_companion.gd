extends Node2D
signal gnaw_started(at: Vector2)
signal gnaw_bite
signal gnaw_stopped
const Planner := preload("res://modules/main_menu/companion_path.gd")
const LAYOUT := preload("res://modules/main_menu/assets/layout.gd")
enum State { IDLE, FOLLOW, INSPECT, CLICK_REACTION, GNAW }
var state := State.IDLE
var enabled := false
var velocity := Vector2.ZERO
var mouse_position := Vector2.ZERO
var last_mouse_position := Vector2.ZERO
var motion_direction := Vector2.RIGHT
var still_time := 0.0
var total_time := 0.0
var response_delay := 0.0
var reaction_time := 0.0
var gnaw_time := 0.0
var bites := 0
var gnaw_completed := false
var safe_bounds := Rect2()
var obstacles: Array[Rect2] = []
var menu_rects: Array[Rect2] = []
var path := PackedVector2Array()
var replan_time := 0.0
var unit := 1.0
var sprite: Sprite2D
var shadow: Sprite2D
var body_pivot := Vector2.ZERO
var nose_local := Vector2.ZERO
var base_scale := 1.0
var body_angle := 0.0
var protected_radius := 86.0
var _placed := false

func _ready() -> void:
	var data: Dictionary = LAYOUT.DATA
	body_pivot = Vector2(data.mouse_body[0], data.mouse_body[1])
	var nose := Vector2(data.mouse_nose[0], data.mouse_nose[1])
	var texture: Texture2D = load("res://modules/main_menu/assets/mouse.png")
	base_scale = 190.0 / texture.get_height()
	nose_local = (nose - body_pivot) * base_scale
	shadow = Sprite2D.new()
	shadow.texture = texture
	shadow.centered = false
	shadow.offset = -body_pivot
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shadow.material = ShaderMaterial.new()
	shadow.material.shader = preload("res://modules/main_menu/contact_shadow.gdshader")
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.material = ShaderMaterial.new()
	sprite.material.shader = preload("res://modules/main_menu/mouse_ink.gdshader")
	sprite.centered = false
	sprite.offset = -body_pivot
	sprite.scale = Vector2.ONE * base_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	visible = false

func configure(paper: Rect2, protected_ink: Array[Rect2], menus: Array[Rect2], logical_scale: float, tall: float) -> void:
	unit = logical_scale
	protected_radius = 104.0 * unit
	var inset := Vector2(180.0, lerpf(154.0, 153.0, tall)) * unit
	safe_bounds = Rect2(paper.position + inset, paper.size - inset * 2.0)
	menu_rects = menus
	obstacles.clear()
	for rect in protected_ink:
		obstacles.append(rect.grow(protected_radius))
	# Merge only overlapping exclusion rectangles, so graph corners remain reachable.
	var merged := true
	while merged:
		merged = false
		for i in obstacles.size():
			for j in range(i + 1, obstacles.size()):
				if obstacles[i].intersects(obstacles[j]):
					obstacles[i] = obstacles[i].merge(obstacles[j])
					obstacles.remove_at(j)
					merged = true
					break
			if merged: break
	if not _placed:
		position = paper.position + paper.size * Vector2(0.24, 0.78)
		_placed = true
	position = Planner.nearest_free(position, safe_bounds, obstacles)
	path.clear()
	replan_time = 0.0

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	velocity = Vector2.ZERO
	still_time = 0.0
	mouse_position = get_viewport().get_mouse_position()
	last_mouse_position = mouse_position
	if not value: _stop_gnaw()

func click_reaction() -> void:
	if not enabled: return
	_stop_gnaw()
	reaction_time = 0.23
	state = State.CLICK_REACTION

func _stop_gnaw() -> void:
	if state == State.GNAW: gnaw_stopped.emit()
	gnaw_time = 0.0
	bites = 0
	if state == State.GNAW: state = State.IDLE

func _process(delta: float) -> void:
	if not enabled: return
	total_time += delta
	replan_time -= delta
	var difference := mouse_position - last_mouse_position
	if difference.length() > 2.0 * unit:
		if still_time > 0.25 and velocity.length() < 4.0: response_delay = 0.10
		motion_direction = difference.normalized()
		last_mouse_position = mouse_position
		still_time = 0.0
		gnaw_completed = false
		_stop_gnaw()
	else:
		still_time += delta
	if reaction_time > 0.0:
		reaction_time = maxf(0, reaction_time - delta)
		state = State.CLICK_REACTION
		velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * unit * delta)
	elif state == State.GNAW:
		_update_gnaw(delta)
	else:
		_update_follow(delta)
		if still_time >= 5.0 and velocity.length() < 4.0 * unit and not gnaw_completed:
			_start_gnaw()
	_update_art(delta)

func _update_follow(delta: float) -> void:
	if replan_time <= 0.0:
		var target := mouse_position - motion_direction * 100.0 * unit
		path = Planner.route(position, target, safe_bounds, obstacles)
		replan_time = 0.14
	response_delay = maxf(0.0, response_delay - delta)
	var desired := Vector2.ZERO
	if not path.is_empty() and response_delay <= 0.0:
		var to_goal := path[0] - position
		if to_goal.length() < 6.0 * unit:
			path.remove_at(0)
		elif to_goal.length() > 1.5 * unit:
			desired = to_goal.normalized() * minf(270.0 * unit, to_goal.length() * 5.0)
	velocity = velocity.move_toward(desired, 850.0 * unit * delta)
	var next := position + velocity * delta
	if Planner.segment_clear(position, next, obstacles):
		position = next.clamp(safe_bounds.position, safe_bounds.end)
	else:
		velocity = Vector2.ZERO
		replan_time = 0.0
	state = State.FOLLOW if velocity.length() > 8.0 * unit else State.IDLE
	if state == State.IDLE:
		for rect in menu_rects:
			if rect.grow(145.0 * unit).has_point(mouse_position) and position.distance_to(rect.get_center()) < 320.0 * unit:
				state = State.INSPECT
				var look := rect.get_center() - position
				body_angle = lerp_angle(body_angle, look.angle() + PI / 2.0, 1.0 - exp(-delta * 4.0))
				break
	if velocity.length() > 12.0 * unit:
		body_angle = lerp_angle(body_angle, velocity.angle() + PI / 2.0, 1.0 - exp(-delta * 6.0))

func _start_gnaw() -> void:
	state = State.GNAW
	gnaw_time = 0.0
	bites = 0
	velocity = Vector2.ZERO
	# The nose already points into a protected blank region, away from readable ink.
	gnaw_started.emit(position + (nose_local * unit).rotated(body_angle))

func _update_gnaw(delta: float) -> void:
	gnaw_time += delta
	var expected := mini(4, int(maxf(0.0, gnaw_time - 0.2) / 0.62))
	if expected > bites:
		bites = expected
		gnaw_bite.emit()
	if gnaw_time > 3.15:
		gnaw_stopped.emit()
		state = State.IDLE
		gnaw_completed = true

func _update_art(_delta: float) -> void:
	var moving := clampf(velocity.length() / (270.0 * unit), 0.0, 1.0)
	var breathing := (sin(total_time * 1.7) + sin(total_time * 2.31) * 0.28) * 0.003
	var tilt := 0.0
	var squash := Vector2.ONE * (1.0 + breathing)
	var bob := sin(total_time * 15.0) * 0.9 * moving
	if reaction_time > 0.0:
		var pulse := sin(reaction_time / 0.23 * PI)
		squash *= Vector2(1.0 + pulse * 0.035, 1.0 - pulse * 0.04)
	if state == State.GNAW:
		tilt = sin(gnaw_time * 19.0) * 0.018 * (0.7 + sin(gnaw_time * 2.0) * 0.3)
		bob = sin(gnaw_time * 19.0) * 0.7
		squash.y *= 0.99
	sprite.rotation = body_angle + tilt
	sprite.scale = Vector2.ONE * base_scale * unit * squash
	sprite.position = Vector2(0, bob * unit)
	shadow.position = sprite.position + Vector2(0.45 + moving * 0.12, 0.65) * unit
	shadow.rotation = sprite.rotation
	shadow.scale = sprite.scale
	shadow.material.set_shader_parameter("movement", moving)
	shadow.material.set_shader_parameter("indentation", 1.0 - moving)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_position = event.position
