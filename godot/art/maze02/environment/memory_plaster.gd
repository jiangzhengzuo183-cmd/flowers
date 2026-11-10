extends RefCounted
## Retints only wall instances and keeps the camera occlusion materials in sync.

const DreamFinish := preload("res://art/maze01/maze01_dream_finish.gd")
const Opaque := preload("res://art/maze02/environment/memory_plaster.gdshader")
const Fade := preload("res://art/maze02/environment/memory_plaster_fade.gdshader")
const FadeSource := preload("res://art/maze01/plaster_fade.gdshader")

static func targets_wall(mesh: MeshInstance3D) -> bool:
	var accent: Color = mesh.get_meta("accent_tint", Color.TRANSPARENT)
	if accent.a > 0.0:
		return accent == DreamFinish.CREAM_VIOLET or mesh.has_meta("maze02_plaster")
	var role: String = mesh.get_meta("art_role", "")
	var part: String = mesh.get_meta("greybox_part", "")
	return _chapel_masonry(mesh) or role in ["wall_banded", "chapel_wall"] or (
		role in ["plaster", "prism_plaster"] and part.begins_with("WallSegment_"))

static func apply(generator: Node3D, occlusion: Node) -> void:
	var variants: Dictionary = {}
	var textures: Dictionary = {}
	var powder: Image
	var candidates: Array[Dictionary] = []
	for mesh: MeshInstance3D in generator.find_children("*", "MeshInstance3D", true, false):
		if not targets_wall(mesh):
			continue
		var original := mesh.material_override
		if not (original is ShaderMaterial or original is StandardMaterial3D):
			continue
		candidates.append({"mesh": mesh, "rank": _rank(mesh)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rank < b.rank)
	if candidates.is_empty():
		return
	var aged_count := roundi(candidates.size() * 0.55)
	var edge_rank := float(candidates[maxi(aged_count - 1, 0)].rank)
	for i in candidates.size():
		var mesh: MeshInstance3D = candidates[i].mesh
		var original := mesh.material_override
		var violet: bool = mesh.get_meta("accent_tint", Color.TRANSPARENT) == DreamFinish.CREAM_VIOLET
		var grade := 0
		if i < aged_count:
			var inward := edge_rank - float(candidates[i].rank)
			grade = 1 + roundi(smoothstep(0.0, 6.0, inward) * 4.0)
		var strength := grade / 5.0
		var chapel := _chapel_masonry(mesh)
		var key := "%d/%d/%d" % [original.get_instance_id(), int(violet), grade]
		if not variants.has(key):
			if original is StandardMaterial3D and not textures.has(grade):
				if powder == null:
					powder = _powder_samples()
				textures[grade] = _powder_texture(powder, strength)
			variants[key] = _finish(original, violet, strength, textures.get(grade))
		mesh.material_override = variants[key]
		mesh.set_meta("maze02_plaster", true)
		mesh.set_meta("maze02_aged", grade > 0)
		mesh.set_meta("maze02_weather_strength", strength)
		if chapel:
			mesh.set_meta("maze02_chapel_finish", true)
		if violet:
			mesh.set_meta("accent_tint", DreamFinish.PLASTER_COLOR)

	for group: Dictionary in occlusion.groups.values():
		for entry: Dictionary in group.entries:
			if not entry.mesh.has_meta("maze02_plaster") or entry.alpha.shader != FadeSource:
				continue
			entry.original = entry.mesh.material_override
			var blend: ShaderMaterial = entry.alpha
			blend.shader = Fade
			blend.set_shader_parameter("weather_strength", entry.mesh.get_meta("maze02_weather_strength"))
			blend.set_shader_parameter("stone_color", entry.mesh.get_meta(
				"accent_tint", blend.get_shader_parameter("stone_color")))

static func _chapel_masonry(mesh: MeshInstance3D) -> bool:
	var part := String(mesh.get_meta("greybox_part", ""))
	var node: Node = mesh.get_parent()
	while node != null and node.name != &"LevelArchitecture":
		if node.name in [&"G6", &"G7", &"G8"]:
			return part.begins_with("ArchStone") or part.begins_with("WallAboveArch") or part in ["LeftPier", "RightPier"]
		if node.name == &"CentralRoundHall":
			return mesh.get_meta("art_role", "") in ["chapel_wall", "porch_roof", "plinth", "moulding"]
		node = node.get_parent()
	return false

static func _rank(mesh: MeshInstance3D) -> float:
	var point := mesh.to_global(mesh.get_aabb().get_center())
	var xz := Vector2(point.x, point.z)
	var distance := 60.0
	var centers := [Vector2(8.4, 38.4), Vector2(14.4, 10.8), Vector2(40.8, 8.4), Vector2(21.6, 21.3),
		Vector2(21.6, 3.6), Vector2(7.2, 25.2), Vector2(42.0, 31.2), Vector2(27.6, 33.6), Vector2(14.4, 44.4)]
	for center: Vector2 in centers:
		distance = minf(distance, xz.distance_to(center))
	return distance + 2.3 * sin(point.x * 0.59 + point.z * 0.46)

static func _finish(original: Material, violet: bool, strength: float, powder: Texture2D) -> Material:
	if original is StandardMaterial3D:
		var matte := original.duplicate() as StandardMaterial3D
		if violet:
			matte.albedo_color = DreamFinish.PLASTER_COLOR
		matte.albedo_texture = powder
		matte.uv1_triplanar = true
		matte.uv1_world_triplanar = true
		matte.uv1_scale = Vector3.ONE * 1.15
		matte.roughness = maxf(matte.roughness, lerpf(0.88, 0.92, strength))
		matte.metallic_specular = minf(matte.metallic_specular, 0.23)
		return matte
	var plaster := ShaderMaterial.new()
	plaster.shader = Opaque
	plaster.set_shader_parameter("weather_strength", strength)
	for key: StringName in [&"finish_color", &"finish_side_color", &"finish_roughness",
			&"legacy_winding", &"wall_half_height", &"grain"]:
		plaster.set_shader_parameter(key, original.get_shader_parameter(key))
	if violet:
		plaster.set_shader_parameter("finish_color", DreamFinish.PLASTER_COLOR)
		plaster.set_shader_parameter("finish_side_color", DreamFinish.PLASTER_COLOR)
	return plaster

static func _powder_samples() -> Image:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.142
	noise.fractal_octaves = 2
	var samples := noise.get_seamless_image(128, 128)
	samples.convert(Image.FORMAT_L8)
	return samples

static func _powder_texture(samples: Image, strength: float) -> ImageTexture:
	var darker := Color("fcfbf8").lerp(Color("f0e8db"), strength)
	var gray := samples.get_data()
	var rgb := PackedByteArray()
	rgb.resize(gray.size() * 3)
	for i in gray.size():
		var brightness := float(gray[i]) / 255.0
		rgb[i * 3] = roundi(lerpf(darker.r, 1.0, brightness) * 255.0)
		rgb[i * 3 + 1] = roundi(lerpf(darker.g, 1.0, brightness) * 255.0)
		rgb[i * 3 + 2] = roundi(lerpf(darker.b, 1.0, brightness) * 255.0)
	var image := Image.create_from_data(samples.get_width(), samples.get_height(), false, Image.FORMAT_RGB8, rgb)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
