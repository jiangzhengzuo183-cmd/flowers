extends Control
## Every stencil letter keeps its original RGBA pixels and source-space placement.
signal finished
const ASSETS := "res://modules/main_menu/assets/"
const REVEAL_SECONDS := 0.16
const RHYTHM := [0.0,0.10,0.20,0.30,0.40,0.50,0.60,0.93,1.05,1.17,1.52,1.64,1.76,1.88,2.00,2.12,2.24,2.36]
const REST_Y := [3.0,-4.0,2.0,-2.0,5.0,-1.0,3.0,4.0,-3.0,2.0,3.0,-2.0,5.0,-4.0,3.0,-1.0,2.0,-3.0]
const REST_ANGLE := [-1.8,1.1,-0.7,1.4,-1.3,0.9,-1.7,-1.2,1.4,-0.6,-1.4,0.9,-0.7,1.1,-1.2,0.7,-0.9,1.3]
const LEAD_IN := 0.16
var letters: Array[TextureRect] = []
var source_rects: Array[Rect2] = []
var elapsed := 0.0
var complete := false
var origin := Vector2.ZERO
var art_scale := 1.0
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
	_update_letters()

func _process(delta: float) -> void:
	if complete: return
	elapsed += delta
	_update_letters()
	if elapsed >= LEAD_IN + RHYTHM.back() + REVEAL_SECONDS:
		complete = true
		finished.emit()

func _update_letters() -> void:
	for i in letters.size():
		var p:=clampf((elapsed-LEAD_IN-RHYTHM[i])/REVEAL_SECONDS,0.0,1.0)
		var rect:=source_rects[i]
		letters[i].size=rect.size*art_scale
		letters[i].position=origin+rect.position*art_scale+rest_offset(i)
		letters[i].visible=p>0.0
		letters[i].modulate.a=smoothstep(0.0,1.0,p)
		letters[i].pivot_offset=letters[i].size*Vector2(0.5,1.0)
		letters[i].rotation=deg_to_rad(REST_ANGLE[i])
		letters[i].scale=Vector2.ONE
		letters[i].material.set_shader_parameter("settled",smoothstep(0.0,1.0,p))

func rest_offset(index: int) -> Vector2:
	return Vector2(0.0, REST_Y[index] * logical_scale)
