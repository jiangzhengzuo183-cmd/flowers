extends Node3D
## Independent horizon scenery. It is rendered over the existing sky and lights nothing.

const City := preload("res://art/environments/sky_memories/distant_city.tscn")
const Starlight := preload("res://art/environments/sky_memories/star_glow.gdshader")
const Moonlight := preload("res://art/environments/sky_memories/moon_disk.gdshader")
const MeteorTrail := preload("res://art/environments/meteor_trace.gdshader")
const UPPER_STAR_COUNT := 28
const STAR_COUNT := 48
const MOON_ANGLE := -2.36
const METEOR_SECONDS := 1.82

var _random := RandomNumberGenerator.new()
var _meteor_timer: Timer
var _meteor: MeshInstance3D
var _meteor_material: ShaderMaterial
var _flight: Tween

func install(world: Node3D, center: Vector3) -> void:
	name = "SkyMemories"
	position = center
	world.add_child(self)
	add_child(City.instantiate())
	_build_stars()
	var moon := _quad("FadingMoon", Vector2(62.0, 62.0), _finish(Moonlight, -8))
	moon.position = _radial(MOON_ANGLE, 154.0, 5.5)
	moon.rotation.y = MOON_ANGLE + PI
	_meteor_material = _finish(MeteorTrail, -5)
	_meteor = _quad("CyanMeteor", Vector2(14.6, 1.85), _meteor_material)
	_meteor.hide()
	_random.randomize()
	_meteor_timer = Timer.new()
	_meteor_timer.name = "MeteorInterval"
	_meteor_timer.one_shot = true
	add_child(_meteor_timer)
	_meteor_timer.timeout.connect(_on_meteor_time)
	_meteor_timer.start(_random.randf_range(21.0, 34.0))

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71084
	var altitudes := [0.09, 0.15, 0.27, 0.38, 0.19, 0.33]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STAR_COUNT:
		var low := i >= UPPER_STAR_COUNT
		var ring_index := i-UPPER_STAR_COUNT if low else i
		var ring_count := STAR_COUNT-UPPER_STAR_COUNT if low else UPPER_STAR_COUNT
		var azimuth := -PI + TAU*ring_index/ring_count + rng.randf_range(-0.10,0.10)
		var radius := rng.randf_range(113.0,143.0)
		var elevation: float = altitudes[i % altitudes.size()]
		if low:
			var horizon_heights := [0.086,0.125,0.172,0.112,0.205]
			elevation = horizon_heights[ring_index%horizon_heights.size()]
			radius = rng.randf_range(94.0,113.0)
			if absf(angle_difference(MOON_ANGLE,azimuth)) < 0.21:
				elevation = maxf(elevation,0.22)
		if i == 3:
			azimuth = -2.29
			elevation = 0.30
		var point := _radial(azimuth,radius,radius*elevation + rng.randf_range(-2.4,2.4))
		var forward := point.normalized()
		var right := Vector3.UP.cross(forward).normalized()
		var up := forward.cross(right).normalized()
		var style := 0.54 if i % 5 == 0 or i == 3 else (0.94 if i % 8 == 0 else 0.0)
		var size := rng.randf_range(0.64,1.10) if style == 0.0 else rng.randf_range(1.62,2.05)
		if low:
			style = 0.54 if ring_index%3 != 1 else 0.0
			size = rng.randf_range(2.25,3.15) if style > 0.0 else rng.randf_range(1.05,1.53)
			if ring_index%5 == 2:
				style = 0.54
				size = 3.8
		if i == 3:
			size = 2.45
		var data := Color(style,rng.randf(),1.0 if low or i % 5 == 0 else 0.0,rng.randf_range(0.81,1.0) if low else rng.randf_range(0.58,0.94))
		surface.set_color(data)
		for uv: Vector2 in [Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]:
			surface.set_uv(uv)
			surface.add_vertex(point + (right*(uv.x-0.5) + up*(uv.y-0.5))*size)
	var stars := MeshInstance3D.new()
	stars.name = "SparseStars"
	stars.mesh = surface.commit()
	stars.material_override = _finish(Starlight,-7)
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)

func _on_meteor_time() -> void:
	var angle := _random.randf_range(-PI,PI)
	var camera := get_viewport().get_camera_3d()
	if camera:
		var bearing := -camera.global_basis.z
		if Vector2(bearing.x,bearing.z).length_squared() > 0.15:
			angle = atan2(bearing.x,bearing.z) + _random.randf_range(-0.42,0.42)
	play_meteor(angle,_random.randf_range(0.145,0.31),_random.randf() < 0.5)
	_meteor_timer.start(_random.randf_range(36.0,63.0))

func play_meteor(azimuth: float, elevation: float, to_right: bool) -> void:
	if is_instance_valid(_flight):
		_flight.kill()
	var distance := _random.randf_range(124.0,146.0)
	var start := _radial(azimuth,distance,distance*elevation)
	_meteor.look_at_from_position(to_global(start),to_global(Vector3.UP*2.0))
	var lean := _random.randf_range(0.21,0.37)
	_meteor.rotate_object_local(Vector3.BACK,-lean if to_right else PI+lean)
	var travel := _meteor.basis.x.normalized() * _random.randf_range(12.6,16.4)
	_meteor.scale.x = _random.randf_range(0.78,1.19)
	_set_meteor_strength(0.0)
	_meteor.show()
	_flight = create_tween().set_parallel(true)
	_flight.tween_property(_meteor,"position",start+travel,METEOR_SECONDS).from(start)
	_flight.tween_method(_set_meteor_strength,0.0,0.91,0.24)
	_flight.tween_method(_set_meteor_strength,0.91,0.0,METEOR_SECONDS-0.33).set_delay(0.33)
	_flight.chain().tween_callback(_meteor.hide)

func _set_meteor_strength(value: float) -> void:
	_meteor_material.set_shader_parameter("opacity",value)

func _quad(id: String, size: Vector2, material: ShaderMaterial) -> MeshInstance3D:
	var plane := QuadMesh.new()
	plane.size = size
	var node := MeshInstance3D.new()
	node.name = id
	node.mesh = plane
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _finish(shader: Shader, priority: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = priority
	return material

func _radial(angle: float, distance: float, height: float) -> Vector3:
	return Vector3(sin(angle)*distance,height,cos(angle)*distance)
