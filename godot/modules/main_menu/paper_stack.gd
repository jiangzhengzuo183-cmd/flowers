extends Control
## Complete lower sheets overlap; their corners are revealed by placement, never by a wedge cutout.
const LAYER:=preload("res://modules/main_menu/paper_layer.gdshader")
const PAPER:=preload("res://modules/main_menu/assets/paper_stack_yellow_blue.png")
const SINGLE:=preload("res://modules/main_menu/assets/paper_single.png")
var sheets: Array[TextureRect]=[]
var shadows: Array[TextureRect]=[]
var ground_shadow: TextureRect
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var atlas:=AtlasTexture.new()
	atlas.atlas=SINGLE
	atlas.region=Rect2(36,20,1600,900)
	atlas.filter_clip=true
	var scales: Array[float]=[0.8685,0.9662545,0.950525,1.0424895]
	var centers: Array[Vector2]=[Vector2(945.525,553.51),Vector2(953.245,534.21),Vector2(982.195,547.72),Vector2(960,540)]
	var angles: Array[float]=[-4.0,-0.4,0.55,-0.8]
	for i in 4:
		var ink:=ShaderMaterial.new()
		ink.shader=LAYER
		ink.set_shader_parameter("phase",[2.72,0.0,0.93,1.86][i])
		ink.set_shader_parameter("amount",[1.90,1.70,2.15,1.35][i])
		ink.set_shader_parameter("art_scale",Vector2.ONE*scales[i])
		ink.set_shader_parameter("rest_angle",deg_to_rad(angles[i]))
		ink.set_shader_parameter("art_offset",centers[i]-Vector2(960,540)*scales[i] if i<3 else Vector2(960,540)-Vector2(0.506,0.486)*Vector2(1920,1080)*scales[i])
		ink.set_shader_parameter("paper_tone",i<3)
		ink.set_shader_parameter("paper_color",[Color("c2dce6"),Color("f9f3e9"),Color("f5e6a5"),Color.WHITE][i])
		var corners: Array[Vector2]=[Vector2(0.035,0.034),Vector2(0.965,0.034),Vector2(0.965,0.966),Vector2(0.035,0.966)]
		if i==3: corners=[Vector2(0.0515,0.038),Vector2(0.9605,0.038),Vector2(0.9605,0.934),Vector2(0.0515,0.934)]
		for j in 4: ink.set_shader_parameter(["corner_a","corner_b","corner_c","corner_d"][j],corners[j])
		var shade:=_sheet(PAPER if i==3 else atlas)
		shade.material=ink.duplicate()
		shade.material.set_shader_parameter("shadow_only",true)
		shade.material.set_shader_parameter("shadow_offset",Vector2(1.4,3.8) if i==3 else Vector2(3.0,6.0))
		shade.material.set_shader_parameter("shadow_blur",4.5 if i==3 else 7.0)
		shade.material.set_shader_parameter("shadow_strength",0.24 if i==3 else 0.32)
		add_child(shade)
		shadows.append(shade)
		var sheet:=_sheet(PAPER if i==3 else atlas)
		sheet.name=["ExtraBlueSheet","BackWhiteSheet","OriginalYellowSheet","FrontDotGridSheet"][i]
		sheet.material=ink
		add_child(sheet)
		sheets.append(sheet)
	ground_shadow=shadows[0]
func _sheet(texture: Texture2D) -> TextureRect:
	var sheet:=TextureRect.new()
	sheet.texture=texture
	sheet.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	sheet.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sheet.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return sheet
func place(paper: Rect2) -> void:
	position=paper.position
	size=paper.size
	for i in sheets.size():
		for sheet in [sheets[i],shadows[i]]:
			sheet.size=paper.size
			sheet.material.set_shader_parameter("paper_size",paper.size)

func quad(index: int) -> PackedVector2Array:
	var sheet:=sheets[index]
	var ink: ShaderMaterial=sheet.material
	var corners: Array[Vector2]=[]
	for key in ["corner_a","corner_b","corner_c","corner_d"]: corners.append(ink.get_shader_parameter(key))
	var scale: Vector2=ink.get_shader_parameter("art_scale")
	var offset: Vector2=ink.get_shader_parameter("art_offset")
	var angle: float=ink.get_shader_parameter("rest_angle")
	var pivot: Vector2=(corners[0]+corners[2])*0.5*size
	var uv_start:=Vector2.ZERO
	var uv_scale:=Vector2.ONE
	if sheet.texture is AtlasTexture:
		var atlas: AtlasTexture=sheet.texture
		var dimensions:=atlas.atlas.get_size()
		uv_start=atlas.region.position/dimensions
		uv_scale=atlas.region.size/dimensions
	var polygon:=PackedVector2Array()
	for uv in corners:
		var local: Vector2=(uv-uv_start)/uv_scale*size
		polygon.append(position+((local-pivot)*scale).rotated(angle)+pivot*scale+offset)
	return polygon
func set_tear_mask(texture: Texture2D) -> void:
	for item in [sheets[3],shadows[3]]:
		item.material.set_shader_parameter("cut_paper",true)
		item.material.set_shader_parameter("tear_mask",texture)
