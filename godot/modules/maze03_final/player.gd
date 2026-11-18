extends "res://scripts/levels/greybox_player.gd"

signal boost_started
@export var boost_multiplier := 1.35
@export var boost_seconds := 3.0
var boost_remaining := 0.0
var speed_motes: CPUParticles3D
var speed_ribbons: Node3D

func _ready() -> void:
	super()
	speed_motes = CPUParticles3D.new()
	speed_motes.name = "BarrierSpeedMotes"
	speed_motes.amount = 16
	speed_motes.lifetime = 0.35
	speed_motes.local_coords = false
	speed_motes.emitting = false
	speed_motes.position.y = 0.65
	speed_motes.gravity = Vector3(0, 0.07, 0)
	speed_motes.initial_velocity_min = 0.08
	speed_motes.initial_velocity_max = 0.25
	speed_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	speed_motes.emission_sphere_radius = 0.24
	var mesh := SphereMesh.new()
	mesh.radius = 0.016
	mesh.height = 0.032
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d8f6ff")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	speed_motes.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, Color(0.62, 0.89, 1.0, 0.8))
	fade.set_color(1, Color(0.62, 0.89, 1.0, 0.0))
	speed_motes.color_ramp = fade
	add_child(speed_motes)
	speed_ribbons = preload("res://modules/maze03_final/speed_trails.gd").new()
	speed_ribbons.actor = self
	add_child(speed_ribbons)

func apply_boost() -> void:
	boost_remaining = boost_seconds
	boost_started.emit()

func _has_free_sprint() -> bool:
	# The barrier grants the same running speed without Shift or stamina cost.
	return super() or boost_remaining > 0.0

func _movement_modifier() -> float:
	return maxf(super(),boost_multiplier if boost_remaining > 0.0 else 1.0)

func _physics_process(delta: float) -> void:
	boost_remaining = maxf(0.0, boost_remaining - delta)
	super(delta)
	speed_motes.emitting = boost_remaining > 0.0 and Vector2(velocity.x, velocity.z).length() > 0.2

func reset_player() -> void:
	boost_remaining = 0.0
	if is_instance_valid(speed_ribbons):
		speed_ribbons.clear()
	super()

