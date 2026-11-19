extends Node2D
signal gnaw_started(at: Vector2)
signal gnaw_bite
signal gnaw_stopped
const LAYOUT := preload("res://modules/main_menu/assets/mouse_cartoon_layout.gd")
const POSE_FPS := 10.0
const IDLE_GNAW_SECONDS := 3.0
const FOLLOW_DISTANCE := 132.0
const MAX_SPEED := 420.0
enum State { IDLE, FOLLOW, INSPECT, CLICK_REACTION, GNAW }
var state := State.IDLE
var enabled := false
var velocity := Vector2.ZERO
var mouse_position := Vector2.ZERO
var last_mouse_position := Vector2.ZERO
var motion_direction := Vector2.RIGHT
var still_time := 0.0
var total_time := 0.0
var reaction_time := 0.0
var gnaw_time := 0.0
var bites := 0
var gnaw_completed := false
var safe_bounds := Rect2()
var obstacles: Array[Rect2] = []
var menu_rects: Array[Rect2] = []
var unit := 1.0
var sprite: Sprite2D
var shadow: Sprite2D
var body_pivot := Vector2.ZERO
var nose_local := Vector2.ZERO
var base_scale := 1.0
var body_angle := 0.0
var turn_speed := 0.0
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
	ink_rects = protected_ink
	paper_surface = Rect2(paper.position+Vector2(76,42)*unit,paper.size-Vector2(144,90)*unit)
	# A conservative silhouette radius keeps every turn on the sheet, without text obstacles.
	var radius := 0.0
	for point in outline: radius=maxf(radius,point.length()*base_scale*unit)
	safe_bounds=paper_surface.grow(-(radius*1.035+4.0*unit))
	menu_rects=menus
	obstacles.clear()
	if not _placed:
		position = paper.position + paper.size * Vector2(0.24, 0.78)
		_placed = true
	position = position.clamp(safe_bounds.position,safe_bounds.end)
	_display_world = position
	_pose_age = 1.0

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	velocity = Vector2.ZERO
	turn_speed = 0.0
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
	var difference := mouse_position - last_mouse_position
	if difference.length() > 2.0 * unit:
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
		if still_time >= IDLE_GNAW_SECONDS and velocity.length() < 4.0 * unit and not gnaw_completed:
			_start_gnaw()
	_update_art(delta)

func _update_follow(delta: float) -> void:
	var to_pointer:=mouse_position-position
	var distance:=to_pointer.length()
	var wanted_speed:=0.0
	if distance>FOLLOW_DISTANCE*unit:
		wanted_speed=minf(MAX_SPEED*unit,(distance-FOLLOW_DISTANCE*unit)*5.2)
	if distance>8.0*unit:
		var target_angle:=to_pointer.angle()+PI/2.0
		var error:=angle_difference(body_angle,target_angle)
		var wanted_turn:=clampf(error*18.0,-10.5,10.5)
		turn_speed=lerpf(turn_speed,wanted_turn,1.0-exp(-delta*22.0))
		var turn:=turn_speed*delta
		if absf(turn)>absf(error):
			body_angle=target_angle
			turn_speed=0.0
		else: body_angle+=turn
	# Heading steers locomotion, so a changing target produces a continuous arc.
	var forward:=Vector2.UP.rotated(body_angle)
	var alignment:=maxf(0.0,forward.dot(to_pointer.normalized())) if distance>0.1 else 1.0
	var desired:=forward*wanted_speed*lerpf(0.20,1.0,alignment)
	velocity=velocity.lerp(desired,1.0-exp(-delta*14.0))
	if wanted_speed<0.5*unit and velocity.length()<0.7*unit: velocity=Vector2.ZERO
	var next:=position+velocity*delta
	position=next.clamp(safe_bounds.position,safe_bounds.end)
	if position.x!=next.x: velocity.x=0.0
	if position.y!=next.y: velocity.y=0.0
	state=State.FOLLOW if velocity.length()>8.0*unit else State.IDLE

func _start_gnaw() -> void:
	state = State.GNAW
	gnaw_time = 0.0
	bites = 0
	velocity = Vector2.ZERO
	# Anchor the bite to the actual continuously drawn nose position.
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
	_pose_age+=delta
	var moving:=clampf(velocity.length()/(MAX_SPEED*unit),0.0,1.0)
	if _pose_age>=1.0/POSE_FPS:
		_pose_age=fmod(_pose_age,1.0/POSE_FPS)
		pose_frame+=1
	var step:=pose_frame%4
	var pulse: float=[0.0,1.0,0.0,-0.7][step]
	var squash:=Vector2(1.0+0.007*pulse*moving,1.0-0.006*pulse*moving)
	var tilt:=deg_to_rad([0.0,-0.28,0.0,0.22][step])*moving
	var bob: float=-0.45*pulse*moving*unit
	if reaction_time>0.0:
		var surprise:=sin(reaction_time/0.23*PI)
		squash*=Vector2(1.0+surprise*0.025,1.0-surprise*0.035)
	if state==State.GNAW:
		tilt=[0.0,-0.012,0.005,0.010][step]
		bob=[0.0,-0.7,0.2,0.6][step]*unit
	_display_world=position+Vector2(0,bob)
	_display_angle=body_angle+tilt
	_display_scale=squash
	sprite.position=Vector2(0,bob)
	sprite.rotation=_display_angle
	sprite.scale=Vector2.ONE*base_scale*unit*squash
	shadow.position=sprite.position+Vector2(0.4,0.55)*unit
	shadow.rotation=sprite.rotation
	shadow.scale=sprite.scale
	shadow.material.set_shader_parameter("movement",moving)
	shadow.material.set_shader_parameter("indentation",1.0-moving)

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
	return true

func display_is_safe() -> bool:
	return _art_clear(_display_world,_display_angle,_display_scale)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_position = event.position
