extends Node3D

@export var phase := 0.0
@export var bounce_energy := 0.19
@export var dot_count := 5
@export var spark_size := 0.18
@export var bounce_range := 1.85

var _dots: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _time := 0.0

func _ready() -> void:
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.20, 0.37, 0.69, 1.0])
	colors.colors = PackedColorArray([Color("fff0b7"), Color("ffdb8df0"), Color("ffd47470"), Color("ffc96f1a"), Color("ffc96f00")])
	var glow := GradientTexture2D.new()
	glow.width = 32
	glow.height = 32
	glow.gradient = colors
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.albedo_texture = glow
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 1
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * spark_size
	quad.material = material
	for i in dot_count:
		var dot := MeshInstance3D.new()
		dot.mesh = quad
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.set_meta("art_addition", true)
		add_child(dot)
		_dots.append(dot)
	if bounce_energy > 0.0:
		_light = OmniLight3D.new()
		_light.name = "SoftAmberBounce"
		_light.position.y = -0.15
		_light.light_color = Color("ffce80")
		_light.light_energy = bounce_energy
		_light.light_specular = 0.22
		_light.omni_range = bounce_range
		_light.omni_attenuation = 1.15
		add_child(_light)
	_process(0.0)

func _process(delta: float) -> void:
	_time += delta
	for i in _dots.size():
		var f := float(i)
		var t := _time * (0.40 + 0.04 * f) + phase + f * 2.39996
		_dots[i].position = Vector3(cos(t) * (0.40 + 0.048 * f), sin(t * 1.13 + f) * 0.24 + (f - 2.0) * 0.075, sin(t) * (0.30 + 0.056 * f))
		var pulse := 0.74 + 0.18 * sin(t * 3.1 + f)
		_dots[i].scale = Vector3.ONE * pulse
	if _light:
		_light.light_energy = bounce_energy * (1.0 + 0.13 * sin(_time * 0.85 + phase))
