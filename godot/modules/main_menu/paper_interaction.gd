extends Node2D
## Randomized non-destructive tears; generated once per bite site, stable between frames.
var paper_rect:=Rect2()
var holes: Array[Dictionary]=[]
var active_hole:=-1
var redraw_pending:=false
var rng:=RandomNumberGenerator.new()
const MASK_SIZE:=Vector2i(1920,1080)
var mask_viewport: SubViewport
var notes_viewport: SubViewport
var mask_canvas: Node2D
var reveal: ColorRect
func _ready() -> void:
	rng.randomize()
	notes_viewport=_viewport()
	notes_viewport.add_child(preload("res://modules/main_menu/underpaper_notes.gd").new())
	notes_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	_freeze_notes.call_deferred()
	mask_viewport=_viewport()
	mask_viewport.transparent_bg=true
	mask_canvas=preload("res://modules/main_menu/tear_mask.gd").new()
	mask_viewport.add_child(mask_canvas)
	mask_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	reveal=ColorRect.new()
	reveal.mouse_filter=Control.MOUSE_FILTER_IGNORE
	reveal.material=ShaderMaterial.new()
	reveal.material.shader=preload("res://modules/main_menu/tear_reveal.gdshader")
	reveal.material.set_shader_parameter("tear_mask",mask_viewport.get_texture())
	reveal.material.set_shader_parameter("notes",notes_viewport.get_texture())
	add_child(reveal)
	reveal.hide()
func _viewport() -> SubViewport:
	var viewport:=SubViewport.new()
	viewport.size=MASK_SIZE
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(viewport)
	return viewport
func place(rect: Rect2) -> void:
	paper_rect=rect
	if is_instance_valid(reveal):
		reveal.position=rect.position
		reveal.size=rect.size
		reveal.material.set_shader_parameter("canvas_size",rect.size)
func begin_gnaw(at: Vector2) -> void:
	if holes.size()>=8: holes.pop_front()
	var seed_value:=rng.randf_range(0.0,1000.0)
	var profile:=PackedFloat32Array()
	var rim:=PackedFloat32Array()
	for i in 48:
		var angle:=TAU*float(i)/48.0
		profile.append(1.0+sin(angle*3.0+seed_value)*0.11+cos(angle*5.0+seed_value*0.7)*0.065+rng.randf_range(-0.045,0.045))
		rim.append(rng.randf_range(2.5,5.0))
	holes.append({"uv":(at-paper_rect.position)/paper_rect.size,"bites":0,"growth":0.0,"seed":seed_value,"radius":rng.randf_range(23.0,35.0),"aspect":rng.randf_range(0.70,1.12),"angle":rng.randf_range(-PI,PI),"profile":profile,"rim":rim})
	active_hole=holes.size()-1
	redraw_pending=true
func bite() -> void:
	if active_hole<0: return
	holes[active_hole].bites=mini(4,int(holes[active_hole].bites)+1)
	redraw_pending=true
func stop_gnaw() -> void: active_hole=-1
func _process(delta: float) -> void:
	if not redraw_pending: return
	var moving:=false
	for hole in holes:
		var goal:=float(hole.bites)
		hole.growth=move_toward(float(hole.growth),goal,delta*4.5)
		if absf(float(hole.growth)-goal)>0.001: moving=true
	redraw_pending=moving
	_refresh_mask()

func shape(hole: Dictionary,outer:=false) -> PackedVector2Array:
	var points:=PackedVector2Array()
	var fraction:=clampf(float(hole.growth)/4.0,0.0,1.0)
	if fraction<=0.002: return points
	var center: Vector2=Vector2(hole.uv)*Vector2(MASK_SIZE)
	var radius:=float(hole.radius)*sqrt(fraction)
	for i in 48:
		var angle:=TAU*float(i)/48.0
		var direction:=Vector2(cos(angle),sin(angle)*float(hole.aspect)).rotated(float(hole.angle))
		var reach:=radius*float(hole.profile[i])
		if outer: reach+=float(hole.rim[i])*sqrt(fraction)
		points.append(center+direction*reach)
	return points
func _refresh_mask() -> void:
	mask_canvas.inner_shapes.clear()
	mask_canvas.outer_shapes.clear()
	for hole in holes:
		var inner:=shape(hole)
		if inner.is_empty(): continue
		mask_canvas.inner_shapes.append(inner)
		mask_canvas.outer_shapes.append(shape(hole,true))
	mask_canvas.queue_redraw()
	mask_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	reveal.visible=not mask_canvas.inner_shapes.is_empty()

func _freeze_notes() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	notes_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
