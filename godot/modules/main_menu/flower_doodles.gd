extends Control
const FLOWERS:=preload("res://modules/main_menu/assets/flower_heads.png")
const INK:=preload("res://modules/main_menu/flower_ink.gdshader")
var blooms: Array[TextureRect]=[]
var elapsed:=0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var cell:=FLOWERS.get_width()/3.0
	for i in 8:
		var atlas:=AtlasTexture.new()
		atlas.atlas=FLOWERS
		atlas.region=Rect2([0,1,2,1,2,0,1,2][i]*cell,0,cell,FLOWERS.get_height())
		atlas.filter_clip=true
		var flower:=TextureRect.new()
		flower.texture=atlas
		flower.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		flower.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flower.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		flower.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var ink:=ShaderMaterial.new()
		ink.shader=INK
		ink.set_shader_parameter("seed",i*1.1)
		flower.material=ink
		flower.modulate.a=[0.86,0.82,0.83,0.78,0.80,0.82,0.76,0.80][i]
		add_child(flower)
		blooms.append(flower)
func place(paper: Rect2) -> void:
	var unit:=paper.size.x/1920.0
	var centers: Array[Vector2]=[Vector2(1635,345),Vector2(1750,470),Vector2(1585,590),Vector2(230,450),Vector2(345,884),Vector2(1490,850),Vector2(1645,945),Vector2(1395,968)]
	var sizes: Array[float]=[210.0,175.0,155.0,190.0,350.0,190.0,145.0,130.0]
	for i in blooms.size():
		var bloom:=blooms[i]
		bloom.size=Vector2.ONE*sizes[i]*unit*1.12
		var center:=Vector2(960,540)+(centers[i]-Vector2(960,540))*0.965
		bloom.position=paper.position+center*unit-bloom.size*0.5
		bloom.pivot_offset=bloom.size*0.5
		bloom.rotation_degrees=[-12.0,16.0,7.0,15.0,-9.0,-8.0,18.0,-16.0][i]
		bloom.material.set_shader_parameter("flower_size",bloom.size)
func _process(delta: float) -> void:
	elapsed+=delta
	for i in blooms.size():
		var p:=clampf((elapsed-0.35-[0.0,0.20,0.40,0.10,0.30,0.24,0.44,0.58][i])/1.65,0.0,1.0)
		blooms[i].material.set_shader_parameter("progress",p)
	if elapsed>2.65: set_process(false)
