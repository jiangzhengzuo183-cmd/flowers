extends Node3D
## Dress the original gate with glazed stone and an inset floor slot.

const Gate := preload("res://scripts/levels/greybox_gate.gd")
const Geometry := preload("res://scripts/levels/greybox_geometry.gd")
const Roof := preload("res://art/maze01/materials/roof_lake.tres")
const Trace := preload("res://art/maze01/gate_trace.gdshader")
const Relief := preload("res://art/maze01/gate_celestial_inlay.gd")
const Inlay := preload("res://art/maze01/gate_celestial_inlay.gdshader")
const CHARGE_TIME := 1.22
const RELEASE_TIME := 0.99
const DESCENT_TIME := 1.04
const IDLE_EDGE := Color("86b9b7")
const LIT_EDGE := Color("e8fff9")

signal power_released

var gate: Gate
var glaze: StandardMaterial3D
var frame_light: StandardMaterial3D
var trace: ShaderMaterial
var inlay: ShaderMaterial
var glyphs: Node3D
var dust: Array[CPUParticles3D] = []
var sparks: Array[CPUParticles3D] = []
var bounces: Array[OmniLight3D] = []
var pulse: Tween

func install(target: Gate, plaster: StandardMaterial3D, moulding: StandardMaterial3D) -> void:
	gate = target
	name = "DreamGateFinish"
	gate.add_child(self)
	glaze = Roof.duplicate()
	glaze.roughness = 0.44
	glaze.metallic_specular = 0.28
	glaze.emission_enabled = true
	glaze.emission = Roof.albedo_color
	gate.panel.material_override = glaze
	gate.panel.set_meta("art_role", "gate_glaze")
	frame_light = StandardMaterial3D.new()
	frame_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trace = ShaderMaterial.new()
	trace.shader = Trace
	trace.set_shader_parameter("floor_height", gate.global_position.y + 0.005)
	inlay = ShaderMaterial.new()
	inlay.shader = Inlay
	inlay.set_shader_parameter("floor_height", gate.global_position.y + 0.005)
	glyphs = Node3D.new()
	glyphs.name = "CelestialRelief"
	gate.leaf.add_child(glyphs)
	var carving := Relief.build()
	var slot := moulding.duplicate() as StandardMaterial3D
	slot.albedo_color = plaster.albedo_color.darkened(0.32)
	Geometry.box(self, "FloorSlot", Vector3(1.81,0.005,0.184), Vector3(0,0.003,0), slot, false)
	for side: float in [-1.0, 1.0]:
		var plane := QuadMesh.new()
		plane.size = Vector2(1.80,Gate.PANEL_HEIGHT)
		var pattern := MeshInstance3D.new()
		pattern.name = "GateInlay"
		pattern.mesh = plane
		pattern.material_override = trace
		pattern.set_meta("art_addition", true)
		pattern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gate.leaf.add_child(pattern)
		pattern.position = Vector3(0,Gate.PANEL_HEIGHT*0.5,side*0.084)
		pattern.rotation.y = PI if side < 0 else 0.0
		var symbol := MeshInstance3D.new()
		symbol.name = "InlayFront" if side > 0 else "InlayBack"
		symbol.mesh = carving
		symbol.material_override = inlay
		symbol.position.z = side * 0.0815
		symbol.rotation.y = pattern.rotation.y
		symbol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		symbol.set_meta("art_addition",true)
		glyphs.add_child(symbol)
	for side: float in [-1.0, 1.0]:
		Geometry.box(self, "LuminousJamb", Vector3(0.018,2.45,0.026), Vector3(side*0.895,1.26,0), frame_light, false)
	Geometry.box(self, "LuminousHeader", Vector3(1.79,0.018,0.026), Vector3(0,2.475,0), frame_light, false)
	for mesh: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		mesh.set_meta("art_addition", true)
		if mesh.material_override == frame_light:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.opening_lead_time = CHARGE_TIME
	gate.descent_duration = DESCENT_TIME
	gate.opened.connect(_on_unlock)
	gate.descent_started.connect(_on_descent)
	gate.state_applied.connect(_sync)
	_build_threshold_dust()
	_build_release_effects()
	_sync(gate.is_open)

func _on_unlock() -> void:
	pulse = create_tween()
	pulse.tween_method(_prime,0.0,RELEASE_TIME,RELEASE_TIME)
	pulse.tween_callback(_release_power)
	pulse.tween_method(_prime,RELEASE_TIME,CHARGE_TIME,CHARGE_TIME-RELEASE_TIME)
	pulse.tween_method(_settle,0.0,1.0,DESCENT_TIME)
	pulse.parallel().tween_callback(_burst.bind(dust)).set_delay(0.70)

func _prime(elapsed: float) -> void:
	var authored_time := elapsed * (0.60 / RELEASE_TIME)
	inlay.set_shader_parameter("elapsed",authored_time)
	var flash := sin(PI * clampf((elapsed-RELEASE_TIME)/(CHARGE_TIME-RELEASE_TIME),0.0,1.0))
	inlay.set_shader_parameter("pulse",flash)
	var glow := smoothstep(0.26,0.60,authored_time)
	_set_charge(0.76 * glow + 0.24*flash)
	_light_the_threshold(0.21 * glow + flash * 0.80,1.36)
	var shake := sin(elapsed*176.0) * flash * 0.014
	gate.panel.position.x = shake
	glyphs.position.x = shake

func _release_power() -> void:
	_burst(sparks)
	power_released.emit()

func _settle(progress: float) -> void:
	var falloff := 1.0 - smoothstep(0.02,0.84,progress)
	_set_charge(0.12+0.64*falloff)
	inlay.set_shader_parameter("pulse",falloff * 0.26)
	_light_the_threshold(falloff * 0.60,lerpf(1.36,0.32,progress))

func _light_the_threshold(energy: float, height: float) -> void:
	for lamp: OmniLight3D in bounces:
		lamp.visible = energy > 0.004
		lamp.light_energy = energy
		lamp.position.y = height

func _on_descent() -> void:
	gate.panel.position.x = 0.0
	glyphs.position.x = 0.0
	_burst(dust)

func _burst(emitters: Array[CPUParticles3D]) -> void:
	for emitter: CPUParticles3D in emitters:
		emitter.show()
		emitter.restart()
		emitter.emitting = true

func _sync(open: bool) -> void:
	if is_instance_valid(pulse):
		pulse.kill()
	inlay.set_shader_parameter("elapsed",-1.0)
	inlay.set_shader_parameter("pulse",0.0)
	gate.panel.position.x = 0.0
	glyphs.position.x = 0.0
	for emitter: CPUParticles3D in dust + sparks:
		emitter.emitting = false
		emitter.hide()
	_light_the_threshold(0.0,1.36)
	_set_charge(0.12 if open else 0.0)

func _process(_delta: float) -> void:
	glyphs.visible = gate.panel.visible and gate.panel.material_override == glaze

func _set_charge(strength: float) -> void:
	trace.set_shader_parameter("charge", strength)
	var rim_strength := 0.18 * strength + 0.82 * smoothstep(0.35, 1.0, strength)
	frame_light.albedo_color = IDLE_EDGE.lerp(LIT_EDGE, rim_strength)
	glaze.emission_energy_multiplier = lerpf(0.018, 0.042, strength)

func _build_threshold_dust() -> void:
	var quad := _particle_mesh(Color("ddc6a7c8"),0.29,false)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,0.11,0.47,1.0])
	fade.colors = PackedColorArray([Color(1,1,1,0.22),Color(1,1,1,0.95),Color(1,1,1,0.62),Color(1,1,1,0)])
	for side: float in [-1.0,1.0]:
		var emitter := _emitter("ThresholdDustLeft" if side < 0.0 else "ThresholdDustRight",quad,fade,16,0.94)
		emitter.position = Vector3(0.34*side,0.073,0.0)
		emitter.direction = Vector3(side,0.32,0.32).normalized()
		emitter.spread = 55.0
		emitter.initial_velocity_min = 0.44
		emitter.initial_velocity_max = 1.06
		emitter.gravity = Vector3(0,-0.12,0)
		emitter.scale_amount_min = 0.52
		emitter.scale_amount_max = 1.38
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		emitter.emission_box_extents = Vector3(0.27,0.025,0.20)
		dust.append(emitter)

func _build_release_effects() -> void:
	var quad := _particle_mesh(Color("72ead9"),0.105,true)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,0.12,0.57,1.0])
	fade.colors = PackedColorArray([Color("e8fff9"),Color.WHITE,Color("affffa85"),Color(1,1,1,0)])
	for side: float in [-1.0,1.0]:
		var lamp := OmniLight3D.new()
		lamp.name = "ReleaseLightFront" if side > 0.0 else "ReleaseLightBack"
		lamp.position = Vector3(0,1.36,side*0.56)
		lamp.light_color = Color("83f5e6")
		lamp.omni_range = 2.75
		lamp.omni_attenuation = 1.29
		lamp.light_specular = 0.22
		add_child(lamp)
		bounces.append(lamp)
		var emitter := _emitter("ReleaseSparksFront" if side > 0.0 else "ReleaseSparksBack",quad,fade,18,1.10)
		emitter.position = Vector3(0,1.29,side*0.115)
		emitter.direction = Vector3(0,0.28,side).normalized()
		emitter.spread = 60.0
		emitter.initial_velocity_min = 0.46
		emitter.initial_velocity_max = 1.43
		emitter.gravity = Vector3(0,0.19,0)
		emitter.scale_amount_min = 0.32
		emitter.scale_amount_max = 1.28
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		emitter.emission_box_extents = Vector3(0.46,0.51,0.014)
		sparks.append(emitter)

func _particle_mesh(tint: Color, size: float, additive: bool) -> QuadMesh:
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,0.28,0.67,1.0])
	fade.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0.67),Color(1,1,1,0.18),Color(1,1,1,0)])
	var stamp := GradientTexture2D.new()
	stamp.width = 32
	stamp.height = 32
	stamp.fill = GradientTexture2D.FILL_RADIAL
	stamp.fill_from = Vector2(0.5,0.5)
	stamp.fill_to = Vector2(1.0,0.5)
	stamp.gradient = fade
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = stamp
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*size
	quad.material = material
	return quad

func _emitter(label: String, quad: QuadMesh, fade: Gradient, count: int, lifetime: float) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.name = label
	emitter.mesh = quad
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = count
	emitter.lifetime = lifetime
	emitter.explosiveness = 0.83
	emitter.color_ramp = fade
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emitter)
	return emitter
