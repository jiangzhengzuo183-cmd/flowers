extends CharacterBody3D

const SPEED := 3.6
var controls_enabled := false
var movement_camera: Camera3D
var spawn_point := Vector3.ZERO
var map_size := Vector2.ZERO
var visual: Node3D

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
	visual = Node3D.new()
	add_child(visual)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("567a64")
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.15
	body.mesh = capsule
	body.material_override = material
	body.position.y = 0.65
	visual.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	head.mesh = sphere
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("e3c8a7")
	head.material_override = skin
	head.position.y = 1.47
	visual.add_child(head)
	var nose := MeshInstance3D.new()
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.08
	nose_mesh.height = 0.16
	nose.mesh = nose_mesh
	nose.material_override = skin
	nose.position = Vector3(0, 1.45, -0.24)
	visual.add_child(nose)

func configure(entry: Array, size: float, width: float, depth: float) -> void:
	spawn_point = Vector3((entry[1] + 0.5) * size, 0.08, (entry[0] + 0.5) * size)
	map_size = Vector2(width, depth)
	reset_player()

func reset_player() -> void:
	position = spawn_point
	velocity = Vector3.ZERO
	if is_instance_valid(visual):
		visual.rotation.y = 0

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
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0
	move_and_slide()
	# Keep the prototype on its finite floor even through the boundary entry/exit.
	position.x = clampf(position.x, 0.32, map_size.x - 0.32)
	position.z = clampf(position.z, 0.32, map_size.y - 0.32)
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * 12))
	if position.y < -2:
		reset_player()
