extends CanvasLayer
## Pull a fresh sheet from the bottom of the stack, then let it settle over the old sheet.
signal completed
var active := false
var base: TextureRect
var sheet: Control
var image: TextureRect
var edge: ColorRect
var blocker: Control
var tween: Tween
var progress := 0.0
func _ready() -> void:
	layer = 240
	process_mode = Node.PROCESS_MODE_ALWAYS
	base = _picture(self)
	blocker = Control.new()
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet = Control.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	edge = ColorRect.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.material = ShaderMaterial.new()
	edge.material.shader = preload("res://modules/main_menu/paper_edge_shadow.gdshader")
	sheet.add_child(edge)
	image = _picture(sheet)
	visible = false
	set_process_input(false)
func _picture(parent: Node) -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return picture
func _snapshot() -> ImageTexture:
	RenderingServer.force_draw(false)
	var capture := get_viewport().get_texture().get_image()
	var image_size := Vector2(capture.get_size())
	var logical: Vector2 = get_viewport().get_visible_rect().size
	var aspect := logical.x / logical.y
	if absf(image_size.x / image_size.y - aspect) > 0.002:
		var crop := Vector2(minf(image_size.x,image_size.y*aspect),minf(image_size.y,image_size.x/aspect))
		capture = capture.get_region(Rect2i(Vector2i((image_size-crop)*0.5),Vector2i(crop)))
	return ImageTexture.create_from_image(capture)
func play(change_page: Callable, _returning := false) -> void:
	if active: return
	active = true
	set_process_input(true)
	base.texture = _snapshot()
	image.texture = preload("res://modules/main_menu/assets/background.png")
	visible = true
	_animate(0.0)
	await get_tree().process_frame
	change_page.call()
	await get_tree().process_frame
	await get_tree().process_frame
	# Draw the new scene off-screen once; the old page stays on screen until the next normal draw.
	visible = false
	var incoming := _snapshot()
	visible = true
	image.texture = incoming
	tween = create_tween()
	tween.tween_method(_animate,0.0,1.0,1.32).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	visible = false
	base.texture = null
	image.texture = null
	active = false
	set_process_input(false)
	completed.emit()
func _animate(value: float) -> void:
	progress = value
	var size: Vector2 = get_viewport().get_visible_rect().size
	sheet.size = size
	sheet.pivot_offset = size * Vector2(0.5,0.58)
	var y: float
	var angle: float
	if value < 0.16:
		# The lower edge first peeks out of the stack before the sheet is lifted.
		var p := smoothstep(0.0,0.16,value)
		y = lerpf(size.y-34.0,size.y+16.0,p)
		angle = lerpf(0.15,-0.9,p)
	elif value < 0.87:
		var p := smoothstep(0.16,0.87,value)
		y = lerpf(size.y+16.0,-5.0,p)
		angle = lerpf(-0.9,0.12,p)
	else:
		var p := smoothstep(0.87,1.0,value)
		y = lerpf(-5.0,0.0,p)
		angle = lerpf(0.12,0.0,p)
	var lift := sin(value * PI)
	sheet.position = Vector2(sin(value*PI)*7.0,y)
	sheet.rotation_degrees = angle
	edge.position = Vector2(-20.0,-20.0)
	edge.size = size + Vector2(40.0,40.0)
	edge.material.set_shader_parameter("sheet_size",size)
	edge.material.set_shader_parameter("lift",lift)
func _input(_event: InputEvent) -> void:
	if active: get_viewport().set_input_as_handled()
func _exit_tree() -> void:
	if tween and tween.is_valid(): tween.kill()
