extends "res://modules/maze_items/rabbit_pickup.gd"
## Reuse the rabbit's Area3D, bob, approach feedback, and guarded pickup flight.

var definition: Dictionary

func _ready() -> void:
	super()
	# Replace the inherited default display before the first rendered frame.
	_display.get_child(0).free()
	var model := (definition.model as PackedScene).instantiate() as Node3D
	model.rotation.x = float(definition.get("tilt", 0.0))
	_display.add_child(model)
	var world_to_display := _display.global_transform.affine_inverse()
	var bounds := AABB()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := world_to_display * mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(part) if bounds.has_volume() else part
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var factor: float = definition.size / bounds.size.y
	model.scale *= factor
	model.position -= bounds.get_center() * factor
	_ground_half_height = float(definition.size) * 0.5
	while _sparkles.size() > int(definition.sparkles):
		_sparkles.pop_back().free()
	_update_glow(0.0)

func _update_glow(delta: float) -> void:
	super(delta)
	_display.scale = Vector3.ONE * (1.0 + 0.07 * _near)
	if ground_display:
		_display.position.y = _ground_half_height * _display.scale.y + 0.015
	(_halo.material_override as StandardMaterial3D).albedo_color.a = 0.52 + 0.23 * _near
	(_pool.material_override as StandardMaterial3D).albedo_color.a = 0.72 + 0.18 * _near + 0.08 * sin(_time * 1.85)

func _on_body_entered(body: Node3D) -> void:
	if claimed or body != actor or not actor.controls_enabled:
		return
	super(body)
	if claimed:
		create_tween().tween_property(_pool.material_override, "albedo_color:a", 0.0, 0.31)
