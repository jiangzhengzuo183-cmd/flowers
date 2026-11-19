extends "res://modules/maze_keys/gate_key_pickup.gd"

@export_enum("Cake", "Flour") var effect: int
@export var model: PackedScene
@export var display_size := 0.67

func _ready() -> void:
	definition = {"model": model, "size": display_size, "sparkles": 5}
	super()
	if effect == 1:
		var sensor := get_child(0) as CollisionShape3D
		var passage := BoxShape3D.new()
		passage.size = Vector3(2.36, 2.0, 0.80)
		sensor.shape = passage
		_light.light_color = Color("fff5e9")
		for sparkle: Sprite3D in _sparkles:
			sparkle.modulate = Color("fff8ef")

func _on_body_entered(body: Node3D) -> void:
	if body != actor:
		return
	# A reset can respawn an Area3D before the physics server drops the old overlap.
	var offset := actor.global_position - global_position
	var outside := Vector2(offset.x, offset.z).length_squared() > 1.02 * 1.02
	if effect == 1:
		outside = absf(offset.x) > 1.50 or absf(offset.z) > 0.72
	if outside or absf(offset.y) > 1.6:
		return
	super(body)
