extends Node2D
signal gnaw_started(at: Vector2)
signal gnaw_bite
signal gnaw_stopped
const Planner := preload("res://modules/main_menu/companion_path.gd")
const LAYOUT := preload("res://modules/main_menu/assets/mouse_cartoon_layout.gd")
const POSE_FPS := 10.0
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
var ink_rects: Array[Rect2] = []
var paper_surface := Rect2()
var outline := PackedVector2Array()
var pose_frame := 0
var _pose_age := 1.0
var _display_world := Vector2.ZERO
var _display_angle := 0.0
var _display_scale := Vector2.ONE

func _ready() -> void:
	var data: Dictionary = LAYOUT.DATA
	body_pivot = Vector2(data.pivot[0], data.pivot[1])
	var nose := Vector2(data.nose[0], data.nose[1])
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://modules/main_menu/assets/mouse_cartoon.png")
	var region: Array = data.rect
	texture.region = Rect2(region[0],region[1],region[2],region[3])
	texture.filter_clip = true
	base_scale = float(data.height) / texture.get_height()
	for point: Array in data.outline: outline.append(Vector2(point[0],point[1]))
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

func configure(paper: Rect2, protected_ink: Array[Rect2], menus: Array[Rect2], logical_scale: float, _tall: float) -> void:
	unit = logical_scale
	protected_radius = 108.0 * unit
	ink_rects = protected_ink
	paper_surface = Rect2(paper.position+Vector2(76,42)*unit,paper.size-Vector2(144,90)*unit)
	var inset := Vector2(190.0, 148.0) * unit
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
	_display_world = position
	_pose_age = 1.0

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	velocity = Vector2.ZERO
	still_time = 0.0
	mouse_position = get_viewport().get_mouse_position()
	last_mouse_position = mouse_position
	_pose_age = 1.0
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
		var target := mouse_position - motion_direction * 180.0 * unit
		path = Planner.route(position, target, safe_bounds, obstacles)
		replan_time = 0.14
	if response_delay > 0.0 and not path.is_empty():
		var look := path[0]-position
		body_angle = lerp_angle(body_angle,look.angle()+PI/2.0,1.0-exp(-delta*8.0))
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
	gnaw_started.emit(_display_world + (nose_local * unit * _display_scale).rotated(_display_angle))

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

func _update_art(delta: float) -> void:
	_pose_age += delta
	var moving := clampf(velocity.length()/(270.0*unit),0.0,1.0)
	if _pose_age >= 1.0/POSE_FPS:
		_pose_age = fmod(_pose_age,1.0/POSE_FPS)
		pose_frame += 1
		var step := pose_frame % 4
		var pulse := [0.0,1.0,0.0,-0.7][step] as float
		var squash := Vector2(1.0+0.014*pulse*moving,1.0-0.012*pulse*moving)
		var tilt := deg_to_rad([0.0,-0.8,0.0,0.65][step])*moving
		var bob := -1.1*pulse*moving*unit
		if reaction_time > 0.0:
			var surprise := sin(reaction_time/0.23*PI)
			squash *= Vector2(1.0+surprise*0.025,1.0-surprise*0.035)
		if state == State.GNAW:
			tilt = [0.0,-0.018,0.007,0.015][step]
			bob = [0.0,-0.6,0.2,0.5][step]*unit
		var candidate := position+Vector2(0,bob)
		var angle := body_angle+tilt
		# Check the whole silhouette, including tail, before showing a new held frame.
		if _art_clear(candidate,angle,squash):
			_display_world = candidate
			_display_angle = angle
			_display_scale = squash
		else:
			for turn: float in [0.0,0.26,-0.26,0.52,-0.52,0.78,-0.78]:
				if _art_clear(position,body_angle+turn,Vector2.ONE):
					_display_world = position
					_display_angle = body_angle+turn
					_display_scale = Vector2.ONE
					break
		sprite.rotation = _display_angle
		sprite.scale = Vector2.ONE*base_scale*unit*_display_scale
		shadow.rotation = sprite.rotation
		shadow.scale = sprite.scale
		shadow.material.set_shader_parameter("movement",moving)
		shadow.material.set_shader_parameter("indentation",1.0-moving)
	# Compensate the smooth navigation root so the artwork itself advances at 10 fps.
	sprite.position = _display_world-position
	shadow.position = sprite.position+Vector2(0.4,0.55)*unit

func display_polygon(at: Vector2,angle: float,squash: Vector2) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point in outline:
		polygon.append(at+(point*base_scale*unit*squash).rotated(angle))
	return polygon

func _art_clear(at: Vector2,angle: float,squash: Vector2) -> bool:
	var polygon := display_polygon(at,angle,squash)
	var safe := paper_surface.grow(-2.5*unit)
	for point in polygon:
		if not safe.has_point(point): return false
	for rect in ink_rects:
		var r := rect.grow(3.0*unit)
		var box := PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
		if not Geometry2D.intersect_polygons(polygon,box).is_empty(): return false
	return true

func display_is_safe() -> bool:
	return _art_clear(_display_world,_display_angle,_display_scale)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_position = event.position
