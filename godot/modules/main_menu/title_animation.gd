extends Control
## Every stencil letter keeps its original RGBA pixels and source-space placement.
signal finished
const ASSETS := "res://modules/main_menu/assets/"
const DROP_SECONDS := 0.72
const RHYTHM := [0.0,0.08,0.20,0.29,0.40,0.52,0.66,1.10,1.23,1.39,1.95,2.05,2.20,2.28,2.42,2.53,2.69,2.82]
const REST_Y := [3.0,-4.0,2.0,-2.0,5.0,-1.0,3.0,4.0,-3.0,2.0,3.0,-2.0,5.0,-4.0,3.0,-1.0,2.0,-3.0]
const REST_ANGLE := [-1.8,1.1,-0.7,1.4,-1.3,0.9,-1.7,-1.2,1.4,-0.6,-1.4,0.9,-0.7,1.1,-1.2,0.7,-0.9,1.3]
const LEAD_IN := 0.16
var letters: Array[TextureRect] = []
var source_rects: Array[Rect2] = []
var elapsed := 0.0
var complete := false
var origin := Vector2.ZERO
var art_scale := 1.0
var drop_distance := 150.0
var logical_scale := 1.0

func build(metadata: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry: Dictionary in metadata.letters:
		var glyph := TextureRect.new()
		glyph.material = ShaderMaterial.new()
		glyph.material.shader = preload("res://modules/main_menu/title_ink.gdshader")
		glyph.material.set_shader_parameter("seed", float(entry.index))
		if entry.get("atlas",false):
			var atlas := AtlasTexture.new()
			atlas.atlas = load(ASSETS + str(entry.file))
			var region: Array = entry.rect
			atlas.region = Rect2(region[0],region[1],region[2],region[3])
			atlas.filter_clip = true
			glyph.texture = atlas
		else:
			glyph.texture = load(ASSETS + str(entry.file))
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(glyph)
		letters.append(glyph)
		var r: Array = entry.rect
		source_rects.append(Rect2(r[0], r[1], r[2], r[3]))

func place(at: Vector2, factor: float, unit: float) -> void:
	origin = at
	art_scale = factor
	logical_scale = unit
	drop_distance = 150.0 * unit
	_update_letters()

func _process(delta: float) -> void:
	if complete: return
	elapsed += delta
	_update_letters()
	if elapsed >= LEAD_IN + RHYTHM.back() + DROP_SECONDS:
		complete = true
		finished.emit()

func _update_letters() -> void:
	for i in letters.size():
		var p := clampf((elapsed - LEAD_IN - RHYTHM[i]) / DROP_SECONDS, 0.0, 1.0)
		# A short accelerating fall, then a tiny damped impact and paper-ink settling.
		var descent := clampf(p / 0.64, 0.0, 1.0)
		var y := -drop_distance * (1.0 - pow(descent, 1.65))
		var landing := clampf((p - 0.64) / 0.36, 0.0, 1.0)
		if p > 0.64:
			y = sin(landing * TAU) * exp(-landing * 2.6) * 15.0 * drop_distance / 150.0
		var rect := source_rects[i]
		letters[i].size = rect.size * art_scale
		letters[i].position = origin + rect.position * art_scale + rest_offset(i) + Vector2(0.0, y)
		letters[i].modulate.a = smoothstep(0.0, 0.10, p)
		letters[i].pivot_offset = letters[i].size * Vector2(0.5, 1.0)
		letters[i].rotation = deg_to_rad(REST_ANGLE[i] + sin(i * 2.1) * 1.4 * pow(1.0 - p, 2.0))
		var press := sin(landing * PI) * exp(-landing * 2.0) * 0.042
		letters[i].scale = Vector2(1.0 + press * 0.5, 1.0 - press)
		letters[i].material.set_shader_parameter("settled", smoothstep(0.85, 1.0, p))

func rest_offset(index: int) -> Vector2:
	return Vector2(0.0, REST_Y[index] * logical_scale)
