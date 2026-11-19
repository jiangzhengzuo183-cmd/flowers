extends Control
## Native Godot port of the supplied module; no browser bridge required.
signal completed(result: Dictionary)
const Field := preload("res://scripts/story/ink_field.gd")
const SHADER := preload("res://scripts/story/ink_flow.gdshader")
const ROOT := "res://web/ink-observation/assets/"
var frame: Control
var cards: Array[Control] = []
var inks: Array[TextureRect] = []
var homes: Array[Rect2] = []
var angles := [-7.0,-5.0,10.0,-9.0]
var ids := ["I","IV","V","IX"]
var selected := -1
var zoom := 1.0
var viewed: Array[String] = []
var field: RefCounted
var finish_button: Button
var moving := false
var tween: Tween
var done := false
var hovered := -1
var hover_tweens: Dictionary = {}
var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/experience.json"))

func texture(image: Texture2D, parent: Control, rect: Rect2) -> TextureRect:
	var item := TextureRect.new()
	item.texture = image
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.position = rect.position
	item.size = rect.size
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	frame = Control.new()
	frame.size = Vector2(1600,900)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	texture(load(ROOT+"wood.png"),frame,Rect2(0,0,1600,900))
	var title := Label.new()
	title.text="墨迹测试"
	title.position=Vector2(64,30)
	title.add_theme_font_size_override("font_size",38)
	title.add_theme_color_override("font_color",Color("fff3df"))
	frame.add_child(title)
	field = Field.new(settings.ink)
	var positions := [Vector2(0.79,0.65),Vector2(0.39,0.64),Vector2(0.65,0.25),Vector2(0.22,0.26)]
	for i in range(4):
		var card := Control.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(card)
		var size := Vector2(320,320/1.15)
		var rect := Rect2(positions[i]*Vector2(1600,900)-size/2,size)
		homes.append(rect)
		card.position = rect.position
		card.size = rect.size
		card.pivot_offset = size/2
		card.rotation_degrees = angles[i]
		texture(load(ROOT+"paper.png"),card,Rect2(Vector2.ZERO,size))
		var number := Label.new()
		number.text=ids[i]
		number.position=size*0.12
		number.add_theme_color_override("font_color",Color("8f806a"))
		card.add_child(number)
		var ink := texture(load(ROOT+"ink-"+ids[i]+".png"),card,Rect2(size*0.12,size*0.76))
		ink.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("flow_texture",field.texture)
		ink.material = null
		ink.set_meta("flow_material",material)
		cards.append(card)
		inks.append(ink)
	finish_button = Button.new()
	finish_button.text = "结束观察"
	finish_button.position = Vector2(1370,816)
	finish_button.size = Vector2(170,54)
	frame.add_child(finish_button)
	finish_button.pressed.connect(finish)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if not is_instance_valid(frame): return
	var s := minf(size.x/1600,size.y/900)
	frame.scale = Vector2.ONE*s
	frame.position = (size-Vector2(1600,900)*s)/2

func select_card(i: int) -> void:
	if moving or selected>=0 or done: return
	_stop_hover(i)
	selected = i
	zoom = 1
	if ids[i] not in viewed: viewed.append(ids[i])
	frame.move_child(cards[i],frame.get_child_count()-1)
	finish_button.hide()
	field.reset()
	inks[i].material = inks[i].get_meta("flow_material")
	_animate(Rect2(440,137,720,626),0)

func put_back() -> void:
	if moving or selected<0: return
	var i := selected
	inks[i].material = null
	field.reset()
	_animate(homes[i],angles[i],true)

func _animate(rect: Rect2, angle: float, closing: bool = false) -> void:
	moving = true
	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var card := cards[selected]
	tween.tween_property(card,"position",rect.position,0.4)
	tween.tween_property(card,"size",rect.size,0.4)
	tween.tween_property(card,"rotation_degrees",angle,0.4)
	tween.tween_method(func(s: Vector2) -> void:
		card.pivot_offset = s/2
		card.get_child(0).size = s
		card.get_child(1).position = s*0.12
		inks[selected].position = s*0.12
		inks[selected].size = s*0.76,card.size,rect.size,0.4)
	tween.chain().tween_callback(func() -> void:
		moving = false
		if closing:
			selected = -1
			finish_button.show())

func _input(event: InputEvent) -> void:
	if not visible or done: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		put_back()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and selected>=0 and not moving:
		var ink := inks[selected]
		var p := ink.get_local_mouse_position()/ink.size
		if Rect2(Vector2.ZERO,Vector2.ONE).has_point(p): field.move(p,maxf(get_process_delta_time(),0.008))
		else: field.last = Vector2(-10,-10)
	if event is InputEventMouseButton and event.pressed:
		if selected>=0 and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			if not moving:
				zoom = clampf(zoom+(0.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -0.1),1,1.35)
				var s := Vector2(720,626)*zoom
				_animate(Rect2(Vector2(800,450)-s/2,s),0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if selected>=0:
				if not Rect2(Vector2.ZERO,cards[selected].size).has_point(cards[selected].get_local_mouse_position()): put_back()
			elif not finish_button.get_global_rect().has_point(event.position):
				for i in range(3,-1,-1):
					if Rect2(Vector2.ZERO,cards[i].size).has_point(cards[i].get_local_mouse_position()):
						select_card(i)
						break

func _process(dt: float) -> void:
	if selected>=0 and not moving: field.step(dt)
	elif selected < 0 and not moving and not done: _set_hover(_card_at_mouse())

func _card_at_mouse() -> int:
	# Use the resting, rotated footprint so the lift cannot cause hover flicker.
	var pointer := frame.get_local_mouse_position()
	for i in range(cards.size()-1,-1,-1):
		var local := (pointer-homes[i].get_center()).rotated(-deg_to_rad(angles[i]))+homes[i].size/2
		if Rect2(Vector2.ZERO,homes[i].size).has_point(local): return i
	return -1

func _set_hover(index: int) -> void:
	if index == hovered: return
	hovered = index
	for i in range(cards.size()):
		if hover_tweens.has(i): hover_tweens[i].kill()
		var target := homes[i].position-Vector2(0,8) if i == index else homes[i].position
		var motion := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		motion.tween_property(cards[i],"position",target,0.18)
		hover_tweens[i] = motion

func _stop_hover(keep := -1) -> void:
	for motion: Tween in hover_tweens.values(): motion.kill()
	hover_tweens.clear()
	hovered = -1
	for i in range(cards.size()):
		if i != keep: cards[i].position = homes[i].position

func finish() -> void:
	if selected>=0 or moving or done: return
	done = true
	completed.emit({"viewed":viewed.duplicate(),"source":"godot-native"})
	queue_free()

func _exit_tree() -> void:
	if tween: tween.kill()
	for motion: Tween in hover_tweens.values(): motion.kill()
	for ink: TextureRect in inks: ink.material = null
	field = null
