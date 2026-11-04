extends CharacterBody3D

const CHARLIE_SCENE := preload("res://scenes/characters/charlie_visual.tscn")
const WALK_SPEED := 1.6
const RUN_SPEED := 2.7
const GRAVITY := 18.0
const JUMP_SPEED := 3.9
var controls_enabled := false
var movement_camera: Camera3D
var spawn_point := Vector3.ZERO
var map_size := Vector2.ZERO
var visual: Node3D
var _jump_requested := false
var _jump_key_down := false
var _physics_jumping := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.8
	add_child(collider)
	visual = CHARLIE_SCENE.instantiate()
	add_child(visual)

func configure(entry: Array, size: float, width: float, depth: float) -> void:
	spawn_point = Vector3((entry[1] + 0.5) * size, 0.08, (entry[0] + 0.5) * size)
	map_size = Vector2(width, depth)
	reset_player()

func reset_player() -> void:
	position = spawn_point
	velocity = Vector3.ZERO
	_jump_requested = false
	_jump_key_down = Input.is_physical_key_pressed(KEY_SPACE)
	_physics_jumping = false
	if is_instance_valid(visual):
		visual.rotation.y = 0
		visual.cancel_jump()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	if event.physical_keycode!=KEY_SPACE and event.keycode!=KEY_SPACE:
		return
	if not event.pressed:
		_jump_key_down = false
	elif controls_enabled and not _jump_key_down:
		_jump_key_down = true
		_jump_requested = true
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if controls_enabled and is_instance_valid(movement_camera):
		var horizontal := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		var forward_input := float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		var forward := -movement_camera.global_basis.z
		forward.y = 0
		direction = movement_camera.global_basis.x * horizontal + forward.normalized() * forward_input
	direction.y = 0
	direction = direction.limit_length(1)
	var speed := RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if _jump_requested and controls_enabled and is_on_floor():
		velocity.y = JUMP_SPEED
		_physics_jumping = true
		visual.begin_physics_jump()
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0
	_jump_requested = false
	if not Input.is_physical_key_pressed(KEY_SPACE):
		_jump_key_down = false
	var previous_position := position
	move_and_slide()
	# Keep the prototype on its finite floor even through the boundary entry/exit.
	position.x = clampf(position.x, 0.32, map_size.x - 0.32)
	position.z = clampf(position.z, 0.32, map_size.y - 0.32)
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * 12))
	if position.y < -2:
		reset_player()
		return
	# Use actual travel after collision and boundary clamping, so pushing into a
	# wall does not keep the walk/run animation playing on a stationary body.
	var travel := position - previous_position
	if _physics_jumping:
		if is_on_floor():
			_physics_jumping = false
			visual.end_physics_jump()
		else:
			visual.update_physics_jump(velocity.y,JUMP_SPEED)
	visual.set_locomotion(Vector2(travel.x, travel.z).length() / maxf(delta, 0.0001))
