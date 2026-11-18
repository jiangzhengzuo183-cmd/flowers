extends "res://scripts/levels/greybox_generator.gd"
const Palette := preload("res://art/maze01/sample_palette.gd")
var floor_finishes: Array[ShaderMaterial]

func build(original: Dictionary) -> void:
	super(original)
	floor_finishes = Palette.apply(self)
	for point: Dictionary in original.checkpoints:
		get_node(str(point.id)).hide()
	_hide_debug_pins()

func set_floor_color(color: Color) -> void:
	for finish in floor_finishes:
		finish.set_shader_parameter("finish_color", color)

func set_walk_cutaway(enabled: bool) -> void:
	super(enabled)
	_hide_debug_pins()

func _hide_debug_pins() -> void:
	for pin: MeshInstance3D in marker_pins:
		pin.hide()
