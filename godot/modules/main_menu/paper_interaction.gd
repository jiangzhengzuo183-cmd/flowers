extends Node2D
## Randomized non-destructive tears; generated once per bite site, stable between frames.
var paper_rect:=Rect2()
var holes: Array[Dictionary]=[]
var edge_holes: Array[Dictionary]=[]
var front_quad:=PackedVector2Array()
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
func _new_hole(at: Vector2) -> Dictionary:
	var seed_value:=rng.randf_range(0.0,1000.0)
	var profile:=PackedFloat32Array()
	var rim:=PackedFloat32Array()
	for i in 48:
		var angle:=TAU*float(i)/48.0
		profile.append(1.0+sin(angle*3.0+seed_value)*0.11+cos(angle*5.0+seed_value*0.7)*0.065+rng.randf_range(-0.045,0.045))
		rim.append(rng.randf_range(2.5,5.0))
	return {"uv":(at-paper_rect.position)/paper_rect.size,"bites":0,"growth":0.0,"seed":seed_value,"radius":rng.randf_range(23.0,35.0),"aspect":rng.randf_range(0.70,1.12),"angle":rng.randf_range(-PI,PI),"profile":profile,"rim":rim}
func configure_surface(front: PackedVector2Array,lower: Array[PackedVector2Array]) -> void:
	front_quad=front
	var normalized:=PackedVector2Array()
	for p in front: normalized.append((p-paper_rect.position)/paper_rect.size)
	reveal.material.set_shader_parameter("front_quad",normalized)
	var below:=PackedVector2Array()
	for polygon in lower:
		for p in polygon: below.append((p-paper_rect.position)/paper_rect.size)
	reveal.material.set_shader_parameter("lower_quads",below)
	# Each cluster is a short, overlapping trail of bites, with uneven depth and diameter.
	var sites: Array=[Vector3(0,0.14,37),Vector3(1,0.73,41),Vector3(2,0.17,42),Vector3(2,0.63,32),Vector3(3,0.42,35)]
	var counts: Array[int]=[3,4,4,3,3]
	var index:=0
	for group in sites.size():
		var spec: Vector3=sites[group]
		var side:=int(spec.x)
		var a:=front[side]
		var b:=front[(side+1)%4]
		var along: Vector2=(b-a).normalized()
		var inward:=Vector2(-along.y,along.x)
		for bite_index in counts[group]:
			var reach: float=(float(bite_index)-float(counts[group]-1)*0.5)*spec.z*0.72
			var depth: float=[-0.06,0.38,0.12,0.52,0.24][bite_index]*spec.z
			var at:=a.lerp(b,spec.y)+along*reach+inward*depth
			if index>=edge_holes.size():
				var hole:=_new_hole(at)
				hole.radius=spec.z*rng.randf_range(0.78,1.13)
				hole.bites=4
				hole.growth=4.0
				hole.cluster=group
				hole.aspect=rng.randf_range(0.78,1.13)
				edge_holes.append(hole)
			else: edge_holes[index].uv=(at-paper_rect.position)/paper_rect.size
			index+=1
	# Two small enclosed tooth-mark openings sit just inside selected edge trails.
	for group in [0,1]:
		var spec: Vector3=sites[group]
		var side:=int(spec.x)
		var a:=front[side]
		var b:=front[(side+1)%4]
		var along: Vector2=(b-a).normalized()
		var inward:=Vector2(-along.y,along.x)
		var at:=a.lerp(b,spec.y)+along*(88.0 if group==0 else -90.0)+inward*(61.0 if group==0 else 82.0)
		if index>=edge_holes.size():
			var hole:=_new_hole(at)
			hole.radius=20.0 if group==0 else 22.0
			hole.aspect=rng.randf_range(0.91,1.08)
			hole.bites=4
			hole.growth=4.0
			hole.inner=true
			hole.cluster=group
			for tooth in 48: hole.profile[tooth]+=sin(float(tooth)*TAU*9.0/48.0+float(hole.seed))*0.06
			edge_holes.append(hole)
		else: edge_holes[index].uv=(at-paper_rect.position)/paper_rect.size
		index+=1
	redraw_pending=true
	_refresh_mask()
func begin_gnaw(at: Vector2) -> void:
	if holes.size()>=8: holes.pop_front()
	holes.append(_new_hole(at))
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
	for hole in edge_holes+holes:
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
	reveal.material.set_shader_parameter("notes_ready",true)
