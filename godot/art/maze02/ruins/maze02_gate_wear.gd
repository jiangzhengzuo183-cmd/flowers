extends RefCounted
## Keep the mechanism's own glaze material and charge animation. Paint only its surface.

const SIZE := 192
const STONE := Color("b4a994")

static func apply(gates: Dictionary) -> void:
	for id: String in gates:
		var gate: Node3D = gates[id]
		var glaze: StandardMaterial3D = gate.get_node("DreamGateFinish").glaze
		glaze.albedo_texture = _chipped_glaze(glaze.albedo_color, hash(id))
		glaze.albedo_color = Color.WHITE
		glaze.roughness = 0.49
		gate.panel.set_meta("maze02_chipped_glaze", true)

static func _chipped_glaze(teal: Color, seed: int) -> ImageTexture:
	var coarse := FastNoiseLite.new()
	coarse.seed = seed
	coarse.frequency = 0.127
	coarse.fractal_octaves = 2
	var grain := FastNoiseLite.new()
	grain.seed = seed + 31
	grain.frequency = 0.22
	grain.fractal_octaves = 2
	var scratches := _scratches(seed)
	var pixels := PackedByteArray()
	pixels.resize(SIZE * SIZE * 3)
	for y in SIZE:
		for x in SIZE:
			# A BoxMesh uses a 3 by 2 atlas. Catch chips around each face's borders.
			var u := fposmod(float(x) * 3.0 / SIZE, 1.0)
			var v := fposmod(float(y) * 2.0 / SIZE, 1.0)
			var edge := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			var exposed := 1.0 - smoothstep(0.005, 0.095, edge)
			var coarse_sample := coarse.get_noise_2d(x, y)
			var fleck := grain.get_noise_2d(x, y)
			var score := coarse_sample * 0.70 + fleck * 0.15 + exposed * 0.64
			var chip := smoothstep(0.63, 0.72, score) * exposed
			var rim := smoothstep(0.58, 0.65, score) * (1.0 - chip) * exposed
			var index := x + y * SIZE
			var scratch := scratches[index]
			var color := teal.lerp(STONE, chip * 0.78 + scratch * 0.34)
			color = color.lightened(maxf(fleck, 0.0) * 0.021 + rim * 0.074 + scratch * 0.10)
			color = color.darkened(maxf(-fleck, 0.0) * 0.027)
			var i := index * 3
			pixels[i] = roundi(color.r * 255.0)
			pixels[i + 1] = roundi(color.g * 255.0)
			pixels[i + 2] = roundi(color.b * 255.0)
	var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, pixels)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func _scratches(seed: int) -> PackedFloat32Array:
	var wear := PackedFloat32Array()
	wear.resize(SIZE * SIZE)
	var random := RandomNumberGenerator.new()
	random.seed = seed + 917
	var cell := Vector2(SIZE / 3.0, SIZE / 2.0)
	for row in 2:
		for column in 3:
			var face := Vector2(column, row) * cell
			for i in 3:
				var at := face + Vector2(random.randf_range(0.12, 0.65), random.randf_range(0.18, 0.79)) * cell
				var line := Vector2(random.randf_range(6.5, 13.0), random.randf_range(-4.0, -1.3))
				if i == 0:
					at = face + Vector2(0.25, 0.68) * cell
					line = Vector2(random.randf_range(13.5, 16.0), -4.2)
				var strength := random.randf_range(0.72, 0.98)
				var end := at + line
				for y in range(maxi(0, floori(end.y) - 2), mini(SIZE, ceili(at.y) + 2)):
					for x in range(maxi(0, floori(at.x) - 2), mini(SIZE, ceili(end.x) + 2)):
						var point := Vector2(x + 0.5, y + 0.5) - at
						var t := clampf(point.dot(line) / line.length_squared(), 0.0, 1.0)
						var distance := (point - line * t).length()
						var taper := smoothstep(0.01, 0.21, t) * (1.0 - smoothstep(0.72, 1.0, t))
						var mark := (1.0 - smoothstep(0.24, 1.22, distance)) * strength * taper
						var index := x + y * SIZE
						wear[index] = maxf(wear[index], mark)
	return wear
