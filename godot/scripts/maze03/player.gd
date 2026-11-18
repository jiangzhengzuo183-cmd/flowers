extends "res://scripts/levels/greybox_player.gd"
## Uses the existing movement modifier hook; base speeds and jump code stay intact.
signal boost_started
signal boost_ended
var boost_remaining := 0.0
var boost_factor := 1.0
var speed_motes: CPUParticles3D
func _ready() -> void:
	super()
	speed_motes = CPUParticles3D.new()
	speed_motes.name = "BlueSpeedMotes"
	speed_motes.emitting = false
	speed_motes.amount = 18
	speed_motes.lifetime = 0.38
	speed_motes.local_coords = false
	speed_motes.position.y = 0.55
	speed_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	speed_motes.emission_sphere_radius = 0.16
	speed_motes.gravity = Vector3(0, 0.16, 0)
	speed_motes.initial_velocity_min = 0.05
	speed_motes.initial_velocity_max = 0.22
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("b8edff")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	speed_motes.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, Color(0.55, 0.84, 1.0, 0.7))
	fade.set_color(1, Color(0.55, 0.84, 1.0, 0.0))
	speed_motes.color_ramp = fade
	add_child(speed_motes)
func apply_barrier_boost(multiplier: float, seconds: float) -> void:
	boost_factor = maxf(1.0, multiplier)
	boost_remaining = maxf(0.0, seconds)
	speed_motes.emitting = boost_remaining > 0.0
	boost_started.emit()
func clear_barrier_boost() -> void:
	var was_active := boost_remaining > 0.0
	boost_remaining = 0.0
	boost_factor = 1.0
	if is_instance_valid(speed_motes):
		speed_motes.emitting = false
	if was_active:
		boost_ended.emit()
func _movement_modifier() -> float:
	return super() * (boost_factor if boost_remaining > 0.0 else 1.0)
func _physics_process(delta: float) -> void:
	if boost_remaining > 0.0:
		if boost_remaining <= delta:
			clear_barrier_boost()
		else:
			boost_remaining -= delta
	super(delta)
func reset_player() -> void:
	clear_barrier_boost()
	super()
func _exit_tree() -> void:
	clear_barrier_boost()
