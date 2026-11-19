extends Node3D
## A bounded pool of transient marks and dust. Contact events come from actual travel.

const Footprint := preload("res://art/maze01/footprint.gdshader")
const KEEP_SECONDS := 2.45
const MARK_COUNT := 12
const DUST_COUNT := 3

var _marks: Array[MeshInstance3D] = []
var _lifetimes := PackedFloat32Array()
var _dust: Array[CPUParticles3D] = []
var _next_mark := 0
var _next_dust := 0

func install(world: Node3D) -> void:
	name = "StoneFootsteps"
	world.add_child(self)
	var sole := PlaneMesh.new()
	sole.size = Vector2(0.181, 0.300)
	for i in MARK_COUNT:
		var mark := MeshInstance3D.new()
		mark.name = "Shoeprint%d" % i
		mark.mesh = sole
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = Footprint
		material.render_priority = 1
		mark.material_override = material
		mark.hide()
		add_child(mark)
		_marks.append(mark)
		_lifetimes.append(0.0)
	var dust_mesh := _dust_mesh()
	for i in DUST_COUNT:
		var emitter := CPUParticles3D.new()
		emitter.name = "RunningDust%d" % i
		emitter.mesh = dust_mesh
		emitter.emitting = false
		emitter.one_shot = true
		emitter.amount = 5
		emitter.lifetime = 0.42
		emitter.lifetime_randomness = 0.16
		emitter.explosiveness = 1.0
		emitter.spread = 46.0
		emitter.gravity = Vector3(0, -0.30, 0)
		emitter.initial_velocity_min = 0.29
		emitter.initial_velocity_max = 0.66
		emitter.scale_amount_min = 0.57
		emitter.scale_amount_max = 1.21
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		emitter.emission_sphere_radius = 0.058
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.20, 0.64, 1.0])
		fade.colors = PackedColorArray([Color(1,1,1,0.27), Color.WHITE, Color(1,1,1,0.44), Color(1,1,1,0.0)])
		emitter.color_ramp = fade
		add_child(emitter)
		_dust.append(emitter)

func step(point: Vector3, forward: Vector3, running: bool, wet: bool, foot_side: float) -> void:
	if wet:
		return
	var right := forward.cross(Vector3.UP)
	var contact := point - forward * 0.092 + right * (foot_side * 0.10)
	var ray := PhysicsRayQueryParameters3D.create(contact+Vector3.UP*0.14, contact+Vector3.DOWN*0.22, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return
	var normal: Vector3 = hit.normal
	if normal.y < 0.985:
		return # Ramp collision lies below visible stair treads.
	var base: Vector3 = hit.position
	var back := (-forward).slide(normal).normalized()
	var mark := _marks[_next_mark]
	mark.position = base + normal * 0.008
	mark.basis = Basis(normal.cross(back), normal, back).rotated(normal, -foot_side * 0.10)
	mark.material_override.set_shader_parameter("foot_side", foot_side)
	mark.material_override.set_shader_parameter("fade", 0.92)
	_lifetimes[_next_mark] = KEEP_SECONDS
	_next_mark = (_next_mark + 1) % MARK_COUNT
	mark.show()
	if running:
		var dust := _dust[_next_dust]
		_next_dust = (_next_dust + 1) % DUST_COUNT
		dust.position = base + normal * 0.043
		dust.direction = (normal - forward * 0.55).normalized()
		dust.show()
		dust.restart()
		dust.emitting = true

func clear() -> void:
	for mark: MeshInstance3D in _marks:
		mark.hide()
	for dust: CPUParticles3D in _dust:
		dust.emitting = false
		dust.hide()

func _process(delta: float) -> void:
	for i in _marks.size():
		var mark := _marks[i]
		if not mark.visible:
			continue
		_lifetimes[i] -= delta
		if _lifetimes[i] <= 0.0:
			mark.hide()
		else:
			mark.material_override.set_shader_parameter("fade", 0.92 * smoothstep(0.0, 1.55, _lifetimes[i]))

func _dust_mesh() -> QuadMesh:
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.34, 0.70, 1.0])
	colors.colors = PackedColorArray([Color("ceb09192"), Color("cfb49868"), Color("d7bfa630"), Color("ddc3aa00")])
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1.0,0.5)
	texture.gradient = colors
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.vertex_color_use_as_albedo = true
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.122,0.122)
	mesh.material = material
	return mesh
