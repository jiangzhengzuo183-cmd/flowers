extends Node3D
## Draws navigational cues in a separate world so the maze can be graded independently.

const FocusAudio := preload("res://modules/maze02_items/focus_audio.gd")
const Screen := preload("res://modules/maze02_items/vision_screen.gdshader")
const Motes := preload("res://modules/maze02_items/vision_motes.gdshader")
const Silhouette := preload("res://modules/maze02_items/vision_pickup.gdshader")
const DURATION := 7.0
const FADE := 0.72
const ATTACK := 0.78
const CUE_DELAY := 0.16
const BLUE := Color("58c9ff")
const EXIT := Color("c4f4ff")

var remaining := 0.0
var _elapsed := 0.0
var _focus_audio: FocusAudio
var _refresh_in := 0.0
var _screen: ColorRect
var _screen_material: ShaderMaterial
var _source: SubViewport
var _cue_pass: SubViewport
var _camera: Camera3D
var _mesh := ImmediateMesh.new()
var _view: MeshInstance3D
var _paint := StandardMaterial3D.new()
var _trail := MultiMesh.new()
var _pickups: Node3D
var _silhouette := ShaderMaterial.new()
var _marks: Callable
var _route: Callable
var _occlusion: Node
var _route_samples := PackedVector3Array()
var _occlusion_refresh := 0.0

func install(viewport: Control, occlusion: Node, mark_targets: Callable, route: Callable,
		audio_root: Node, sound_enabled: Callable) -> void:
	_occlusion = occlusion
	_marks = mark_targets
	_route = route
	_source = get_viewport() as SubViewport
	process_priority = 100
	_screen = ColorRect.new()
	_screen.name = "CapsuleVisionScreen"
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = Screen
	_screen.material = _screen_material
	viewport.add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_cue_pass = SubViewport.new()
	_cue_pass.name = "ThroughWallCues"
	_cue_pass.own_world_3d = true
	_cue_pass.transparent_bg = true
	_cue_pass.msaa_3d = Viewport.MSAA_2X
	_cue_pass.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_screen.add_child(_cue_pass)
	_screen_material.set_shader_parameter("scene_view", _source.get_texture())
	_screen_material.set_shader_parameter("cue_view", _cue_pass.get_texture())
	_camera = Camera3D.new()
	_cue_pass.add_child(_camera)
	_camera.make_current()

	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_paint.no_depth_test = true
	_paint.vertex_color_use_as_albedo = true
	_view = MeshInstance3D.new()
	_view.name = "GateAndExitOutlines"
	_view.mesh = _mesh
	_view.material_override = _paint
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cue_pass.add_child(_view)

	var motes := MultiMeshInstance3D.new()
	motes.name = "RouteMotes"
	_trail.transform_format = MultiMesh.TRANSFORM_3D
	_trail.use_custom_data = true
	_trail.mesh = QuadMesh.new()
	motes.multimesh = _trail
	var motes_material := ShaderMaterial.new()
	motes_material.shader = Motes
	motes.material_override = motes_material
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cue_pass.add_child(motes)

	_pickups = Node3D.new()
	_pickups.name = "PickupSilhouettes"
	_cue_pass.add_child(_pickups)
	_silhouette.shader = Silhouette
	_focus_audio = FocusAudio.new()
	_focus_audio.name = "FocusAudio"
	add_child(_focus_audio)
	_focus_audio.install(audio_root, sound_enabled)
	clear()

func activate() -> void:
	if remaining <= 0.0:
		_elapsed = 0.0
		_apply_strength(0.0, 0.0)
	remaining = DURATION
	_focus_audio.start()
	_rebuild()
	_sync_camera()
	_refresh_occluders()
	_cue_pass.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)

func clear() -> void:
	remaining = 0.0
	_elapsed = 0.0
	_focus_audio.stop()
	_cue_pass.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_mesh.clear_surfaces()
	_trail.instance_count = 0
	_clear_pickups()
	_occlusion.guide_blockers.clear()
	_apply_strength(0.0)
	set_process(false)

func _process(delta: float) -> void:
	_elapsed += delta
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		clear()
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_rebuild()
	_sync_camera()
	_occlusion_refresh -= delta
	if _occlusion_refresh <= 0.0:
		_refresh_occluders()
	var release := smoothstep(0.0, FADE, remaining)
	var entry := smoothstep(0.0, ATTACK, _elapsed)
	var cues := smoothstep(CUE_DELAY, ATTACK, _elapsed)
	_screen_material.set_shader_parameter("entry_progress", clampf(_elapsed / ATTACK, 0.0, 1.0))
	_apply_strength(entry * release, cues * release)

func _sync_camera() -> void:
	var source_camera := _source.get_camera_3d()
	if source_camera == null:
		return
	_cue_pass.size = _source.size
	_camera.global_transform = source_camera.global_transform
	_camera.projection = source_camera.projection
	_camera.keep_aspect = source_camera.keep_aspect
	_camera.fov = source_camera.fov
	_camera.size = source_camera.size
	_camera.frustum_offset = source_camera.frustum_offset
	_camera.h_offset = source_camera.h_offset
	_camera.v_offset = source_camera.v_offset
	_camera.near = source_camera.near
	_camera.far = source_camera.far

func _apply_strength(strength: float, cues: float = 0.0) -> void:
	_screen.visible = strength > 0.0 or cues > 0.0
	_view.visible = cues > 0.0
	_screen_material.set_shader_parameter("strength", strength)
	_screen_material.set_shader_parameter("cue_strength", cues)
	_occlusion.guide_strength = cues
	_focus_audio.set_strength(maxf(strength, cues))

func _rebuild() -> void:
	_refresh_in = 0.30
	_build_trail(_route.call())
	_clear_pickups()
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var marks: Dictionary = _marks.call()
	for gate: Node3D in marks.gates:
		var corners := [
			Vector3(-0.96, 0.10, 0.0), Vector3(-0.96, 2.49, 0.0),
			Vector3(0.96, 2.49, 0.0), Vector3(0.96, 0.10, 0.0),
		]
		for i in corners.size():
			_stroke(gate.to_global(corners[i]), gate.to_global(corners[(i + 1) % corners.size()]),
				gate.global_basis.z, 0.016, BLUE, 0.88 if not gate.is_open else 0.36)
	for pickup: Node3D in marks.pickups:
		for mesh: MeshInstance3D in pickup._display.find_children("*", "MeshInstance3D", true, false):
			if mesh == pickup._halo:
				continue
			var copy := MeshInstance3D.new()
			copy.mesh = mesh.mesh
			copy.material_override = _silhouette
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_pickups.add_child(copy)
			copy.global_transform = mesh.global_transform
	for exit: Node3D in marks.exits:
		_beacon(exit.global_position + Vector3.UP * 1.18, 0.46, EXIT)
	_mesh.surface_end()

func _clear_pickups() -> void:
	for copy: Node in _pickups.get_children():
		copy.queue_free()
		_pickups.remove_child(copy)

func _build_trail(route: PackedVector3Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4427
	var frames: Array[Transform3D] = []
	var variation: Array[Color] = []
	_route_samples.clear()
	var trail_distance := 0.0
	for i in range(1, route.size()):
		var step := route[i] - route[i - 1]
		var distance := step.length()
		if distance < 0.05:
			continue
		var forward := step / distance
		var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.BACK
		var side := up.cross(forward).normalized()
		var basis := Basis(side, forward.cross(side), forward)
		var sample_count := maxi(1, ceili(distance / 0.85))
		for j in sample_count:
			_route_samples.append(route[i - 1] + step * ((j + 0.5) / sample_count) + Vector3.UP * 0.25)
		var count := maxi(1, roundi(distance * 8.0))
		var interval := distance / count
		for j in count:
			var point := route[i - 1] + forward * (interval * (j + rng.randf_range(0.04, 0.38)))
			point += side * rng.randf_range(-0.18, 0.18) + Vector3.UP * rng.randf_range(0.12, 0.29)
			frames.append(Transform3D(basis, point))
			var wave_phase := fposmod((trail_distance + j * interval) * 0.18, 1.0)
			variation.append(Color(rng.randf(), rng.randf_range(0.28, 1.0), interval * 0.85, wave_phase))
		trail_distance += distance
	_trail.instance_count = frames.size()
	for i in frames.size():
		_trail.set_instance_transform(i, frames[i])
		_trail.set_instance_custom_data(i, variation[i])

func _refresh_occluders() -> void:
	_occlusion_refresh = 0.16
	var source_camera := _source.get_camera_3d()
	if source_camera == null:
		_occlusion.guide_blockers.clear()
		return
	var origin := source_camera.global_position
	var candidates: Array[Vector3] = []
	for point: Vector3 in _route_samples:
		if origin.distance_squared_to(point) < 22.0 * 22.0 and source_camera.is_position_in_frustum(point):
			candidates.append(point)
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return origin.distance_squared_to(a) < origin.distance_squared_to(b))
	var space: PhysicsDirectSpaceState3D = _occlusion.player.get_world_3d().direct_space_state
	var blockers := {}
	for point: Vector3 in candidates.slice(0, 32):
		var excluded: Array[RID] = [_occlusion.player.get_rid()]
		var ray := PhysicsRayQueryParameters3D.create(origin, point, 1, excluded)
		ray.hit_from_inside = true
		for i in 3:
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				break
			var group: String = _occlusion.guide_group(hit.collider)
			if group.is_empty():
				break
			blockers[group] = true
			excluded.append(hit.rid)
			ray.exclude = excluded
		if blockers.size() >= 12:
			break
	_occlusion.guide_blockers = blockers

func _beacon(at: Vector3, size: float, tint: Color) -> void:
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var corners := [at + Vector3.UP * size, at + axis * size * 0.74,
			at - Vector3.UP * size, at - axis * size * 0.74]
		for i in corners.size():
			_stroke(corners[i], corners[(i + 1) % corners.size()], axis.cross(Vector3.UP), 0.027, tint, 1.0)

func _stroke(a: Vector3, b: Vector3, normal: Vector3, width: float, tint: Color, opacity: float) -> void:
	var side := (b - a).cross(normal).normalized() * width
	if side.is_zero_approx():
		return
	_strip(a, b, side * 2.7, Color(tint, opacity * 0.27))
	_strip(a, b, side, Color(tint.lerp(Color.WHITE, 0.46), opacity))

func _strip(a: Vector3, b: Vector3, side: Vector3, tint: Color) -> void:
	for p: Vector3 in [a - side, a + side, b + side, a - side, b + side, b - side]:
		_mesh.surface_set_color(tint)
		_mesh.surface_add_vertex(p)
