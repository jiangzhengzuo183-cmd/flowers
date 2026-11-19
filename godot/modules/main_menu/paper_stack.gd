extends Control
## Each visible sheet has its own cut-out and held-frame transform; the backing stays still.
const LAYER:=preload("res://modules/main_menu/paper_layer.gdshader")
const CLEAN:=preload("res://modules/main_menu/assets/background_clean_v2.png")
const ORIGINAL:=preload("res://modules/main_menu/assets/background.png")
var sheets: Array[TextureRect]=[]
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var polygons: Array=[
		[Vector2(0.012,0.014),Vector2(0.975,0.014),Vector2(0.980,0.977),Vector2(0.016,0.983)],
		[Vector2(0.180,0.090),Vector2(0.989,0.090),Vector2(0.948,0.995),Vector2(0.180,0.965)],
		[Vector2(0.035,0.034),Vector2(0.968,0.032),Vector2(0.967,0.956),Vector2(0.035,0.958)]]
	for i in 3:
		var sheet:=TextureRect.new()
		sheet.name=["BackSheet","YellowSheet","FrontSheet"][i]
		sheet.texture=ORIGINAL
		sheet.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		sheet.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sheet.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var ink:=ShaderMaterial.new()
		ink.shader=LAYER
		ink.set_shader_parameter("clean_paper",CLEAN)
		ink.set_shader_parameter("phase",[0.0,0.93,1.86][i])
		ink.set_shader_parameter("amount",[0.85,1.1,0.60][i])
		for j in 4: ink.set_shader_parameter(["corner_a","corner_b","corner_c","corner_d"][j],polygons[i][j])
		sheet.material=ink
		add_child(sheet)
		sheets.append(sheet)
func place(paper: Rect2) -> void:
	position=paper.position
	size=paper.size
	for sheet in sheets:
		sheet.size=paper.size
		sheet.material.set_shader_parameter("paper_size",paper.size)
