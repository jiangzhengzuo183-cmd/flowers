extends Control
## Native notebook close-up. Only Continue/Close is shown; paper and live text move together.
signal finished(status: String)
const Leaf := preload("res://scripts/story/report_leaf.gd")
const SANS := preload("res://assets/fonts/SourceHanSansSC-Regular.otf")
const BOOK := Rect2(96,12,1408,873.4815)
const S := 1408.0/1080.0
var request: Dictionary = {}
var data: Dictionary
var reports: Array = []
var leaves: Dictionary = {}
var cache: Dictionary = {}
var cover_texture: Texture2D
var base: Texture2D
var wood: Texture2D
var shadows: Dictionary = {}
var current := 0
var target := 0
var phase := "closed"
var progress := 0.0
var motion: Tween
var action: Button
var cover_hit: Button
var intro := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size=Vector2(1600,900);mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_ALL
	data=JSON.parse_string(FileAccess.get_file_as_string("res://data/report_book_pages.json"))
	base=load("res://assets/report-book/book-base.png");wood=load("res://assets/report-book/desk-wood.png")
	for shape: String in ["open","closed","right"]:
		for kind: String in ["contact","ambient"]:
			shadows[shape+"-"+kind]=load("res://assets/report-book/shadow-"+shape+"-"+kind+".png")
	_select_content()
	var cover:=Leaf.new();cover.cover=true;cover.artwork=load("res://assets/report-book/closed-cover.png")
	cover_texture=_viewport(cover,Vector2i(530,650))
	action=Button.new();action.position=Vector2(1240,772);action.size=Vector2(190,48)
	action.add_theme_font_override("font",SANS);action.add_theme_font_size_override("font_size",24)
	var style:=StyleBoxFlat.new();style.bg_color=Color("f3d69a");style.border_color=Color("ac8951");style.set_border_width_all(1);style.set_corner_radius_all(6)
	action.add_theme_stylebox_override("normal",style);action.add_theme_color_override("font_color",Color("493b29"))
	action.pressed.connect(_action);add_child(action)
	cover_hit=Button.new();cover_hit.flat=true;cover_hit.position=Vector2(460,33);cover_hit.size=Vector2(680,834)
	cover_hit.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;cover_hit.pressed.connect(open_cover);add_child(cover_hit)
	_update_controls();_start.call_deferred()

func _select_content() -> void:
	for original: Dictionary in data.reports:
		var group: Array=data.entries.filter(func(e: Dictionary) -> bool:return e.spread==original.id)
		var allowed: Array=group.filter(func(e: Dictionary) -> bool:return e.id in request.unlocked)
		if allowed.is_empty():continue
		var mask:=0
		for i in group.size():
			if group[i].id in request.unlocked:mask|=1<<i
		var report: Dictionary=original.duplicate(true)
		var dates: Array[String]=[]
		for e: Dictionary in allowed:
			if e.date not in dates:dates.append(e.date)
		report.date="／".join(dates);reports.append(report)
		for side: String in ["left","right"]:
			var source: Dictionary=data.pages.filter(func(p: Dictionary) -> bool:return p.reportId==original.id and p.side==side)[0]
			var page: Dictionary=source.duplicate(true);var all:=false;var ids: Array=[]
			for e: Dictionary in allowed:
				if e.blocks[side] is String:all=true
				else:ids.append_array(e.blocks[side])
			page.content=source.content.filter(func(b: Dictionary) -> bool:return all or b.id in ids)
			page.art=data.variants[original.id][str(mask)][side];leaves[original.id+"-"+side]=page
	for i in reports.size():
		for e: Dictionary in data.entries:
			if e.id==request.currentReport and e.spread==reports[i].id:target=i

func _viewport(leaf: Control,dimensions: Vector2i) -> Texture2D:
	var viewport:=SubViewport.new();viewport.size=dimensions;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(viewport);viewport.add_child(leaf);return viewport.get_texture()

func _page(index: int,side: String) -> Texture2D:
	var key: String=reports[index].id+"-"+side
	if not cache.has(key):
		var leaf:=Leaf.new();leaf.page=leaves[key];leaf.artwork=load(leaf.page.art);cache[key]=_viewport(leaf,Vector2i(762,925))
	return cache[key]

func _start() -> void:
	if reports.is_empty():queue_redraw();return
	current=target;_page(current,"left");_page(current,"right")
	if request.mode=="story" and target>0 and request.currentReport not in ["report1","report2-0304"]:
		current=target-1;_page(current,"left");_page(current,"right");phase="reading";intro=true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if intro:_flip(target)
	elif request.mode=="story":open_cover()
	_update_controls();queue_redraw();grab_focus()

func _animate(from: float,to: float,seconds: float,done: Callable) -> void:
	motion=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_method(func(v: float) -> void:progress=v;queue_redraw(),from,to,seconds)
	motion.tween_callback(done)

func _action() -> void:
	if phase=="closed":finished.emit("closed");return
	if phase!="reading":return
	phase="closing";_update_controls()
	_animate(1,0,1.2,func() -> void:phase="closed";finished.emit("completed" if request.mode=="story" else "closed"))

func open_cover() -> void:
	if phase!="closed" or reports.is_empty():return
	phase="opening";_update_controls()
	_animate(0,1,1.2,func() -> void:phase="reading";_update_controls();queue_redraw())

func _flip(destination: int) -> void:
	if phase!="reading" or destination<0 or destination>=reports.size() or destination==current:return
	target=destination;_page(target,"left");_page(target,"right");phase="preparing_turn";_update_controls()
	await RenderingServer.frame_post_draw
	phase="turning";progress=0
	_animate(0,1,0.82,func() -> void:current=target;phase="reading";intro=false;_update_controls();queue_redraw())

func _update_controls() -> void:
	if action==null:return
	action.visible=phase=="reading" or (phase=="closed" and request.mode=="review")
	action.text="返回剧情" if phase=="closed" else "继续" if request.mode=="story" else "合上笔记本"
	cover_hit.visible=phase=="closed" and not reports.is_empty()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and phase=="reading" and request.mode=="review":
		if Rect2(BOOK.position+Vector2(28,16)*S,Vector2(1012,614)*S).has_point(event.position):_flip(current+(1 if event.position.x>BOOK.position.x+534*S else -1))
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():return
	if event.is_action_pressed("ui_cancel") and request.mode=="review":_action();get_viewport().set_input_as_handled()
	elif request.mode=="review" and phase=="reading":
		if event.is_action_pressed("ui_right"):_flip(current+1);get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):_flip(current-1);get_viewport().set_input_as_handled()

func _paper_rect(left: bool) -> Rect2:
	return Rect2(BOOK.position+Vector2(28 if left else 534,16)*S,Vector2(506,614)*S)

func _draw() -> void:
	if wood==null:return
	draw_texture_rect(wood,Rect2(0,0,1600,900),false)
	if phase=="closed":
		_shadow_pair("closed",Rect2(460,33,680,834),680.0/530)
		draw_texture_rect(cover_texture,Rect2(460,33,680,834),false)
		if reports.is_empty():draw_string(SANS,Vector2(580,440),"完成对应剧情后解锁进步报告",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("59452c"))
		return
	if reports.is_empty():return
	if phase in ["opening","closing"]:_draw_cover();return
	_shadow_pair("open",BOOK,S)
	draw_texture_rect(base,BOOK,false)
	if phase=="turning":
		var next:=target>current
		draw_texture_rect(_page(current if next else target,"left"),_paper_rect(true),false)
		draw_texture_rect(_page(target if next else current,"right"),_paper_rect(false),false);_draw_turn(next)
	else:
		draw_texture_rect(_page(current,"left"),_paper_rect(true),false);draw_texture_rect(_page(current,"right"),_paper_rect(false),false)

func _draw_turn(next: bool) -> void:
	var theta:=PI*progress;var curl:=0.58*sin(theta);var w:=506*S;var h:=614*S
	var hinge:=BOOK.position+Vector2(534,16)*S;var x:=0.0;var z:=0.0;var strips: Array=[]
	for i in 40:
		var u0:=float(i)/40;var u1:=float(i+1)/40;var angle:=theta+curl*(u0+u1)/2
		var nx:=x+cos(angle)*w/40;var nz:=z+sin(angle)*w/40;var a:=6000/(6000-z);var b:=6000/(6000-nz);var direction:=1.0 if next else -1.0
		var points:=PackedVector2Array([hinge+Vector2(direction*x*a,h/2-h*a/2),hinge+Vector2(direction*nx*b,h/2-h*b/2),hinge+Vector2(direction*nx*b,h/2+h*b/2),hinge+Vector2(direction*x*a,h/2+h*a/2)])
		var front:=cos(angle)>=0;var reverse: bool=(not next) if front else next
		var texture:=_page(current,"right" if next else "left") if front else _page(target,"left" if next else "right")
		var t0:=1-u0 if reverse else u0;var t1:=1-u1 if reverse else u1
		strips.append({"z":(z+nz)/2,"points":points,"uv":PackedVector2Array([Vector2(t0,0),Vector2(t1,0),Vector2(t1,1),Vector2(t0,1)]),"texture":texture});x=nx;z=nz
	strips.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return a.z<b.z)
	for strip: Dictionary in strips:draw_polygon(strip.points,PackedColorArray([Color.WHITE]),strip.uv,strip.texture)

func _shadow_pair(shape: String,rect: Rect2,scale_factor: float,strength: float=1.0) -> void:
	if strength<=0:return
	var padded:=rect.grow(60*scale_factor)
	draw_texture_rect(shadows[shape+"-ambient"],Rect2(padded.position+Vector2(5,10)*scale_factor,padded.size),false,Color(1,1,1,0.20*strength))
	draw_texture_rect(shadows[shape+"-contact"],Rect2(padded.position+Vector2(1,3)*scale_factor,padded.size),false,Color(1,1,1,0.27*strength))

func _soft_shadow(points: PackedVector2Array,radius: float,strength: float) -> void:
	if strength<=0.001:return
	var center:=Vector2.ZERO
	for point: Vector2 in points:center+=point
	center/=points.size()
	# Nested translucent silhouettes soften the edge as the cover lifts from the desk.
	for i in range(12,0,-1):
		var expanded:=PackedVector2Array()
		for point: Vector2 in points:expanded.append(point+(point-center).normalized()*radius*i/12.0)
		draw_colored_polygon(expanded,Color(0.20,0.125,0.065,strength*(1.0-float(i)/15.0)/8.0))

func _warp(texture: Texture2D,rect: Rect2,uv_rect: Rect2,project: Callable,tint: Color=Color.WHITE) -> void:
	for y in 12:
		for x in 12:
			var points:=PackedVector2Array();var uv:=PackedVector2Array()
			for t: Vector2 in [Vector2(float(x)/12,float(y)/12),Vector2(float(x+1)/12,float(y)/12),Vector2(float(x+1)/12,float(y+1)/12),Vector2(float(x)/12,float(y+1)/12)]:
				points.append(project.call(rect.position+t*rect.size));uv.append(uv_rect.position+t*uv_rect.size)
			draw_polygon(points,PackedColorArray([tint]),uv,texture)

func _draw_cover() -> void:
	var p:=progress;var theta: float=-PI*smoothstep(0.06,1.0,p);var travel: float=smoothstep(0.0,0.65,p)
	var raw: Array[Vector2]=[Vector2(46,68),Vector2(415,18),Vector2(519,539),Vector2(131,603)]
	var start: Array[Vector2]=[];var end: Array[Vector2]=[Vector2(534,14),Vector2(1061,14),Vector2(1061,650),Vector2(534,650)]
	for i in 4:start.append(((Vector2(460,33)+raw[i]*Vector2(680.0/530,834.0/650)-BOOK.position)/S).lerp(end[i],travel))
	var flat:=func(point: Vector2) -> Vector2:
		var u: float=(point.x-534)/527;var v: float=(point.y-14)/636
		return BOOK.position+start[0].lerp(start[1],u).lerp(start[3].lerp(start[2],u),v)*S
	var open_weight: float=smoothstep(0.85,1.0,p)
	var closed_weight: float=1.0-smoothstep(0.0,0.12,p)
	var moving_weight: float=(1.0-open_weight)*(1.0-closed_weight)
	_shadow_pair("closed",Rect2(460,33,680,834),680.0/530,closed_weight)
	_shadow_pair("open",BOOK,S,open_weight)
	var ground:=func(point: Vector2) -> Vector2:return flat.call(point)+Vector2(3,9)
	_warp(shadows["right-ambient"],Rect2(474,-60,666,790),Rect2(0,0,1,1),ground,Color(1,1,1,0.20*moving_weight))
	_warp(shadows["right-contact"],Rect2(474,-60,666,790),Rect2(0,0,1,1),ground,Color(1,1,1,0.27*moving_weight))
	_warp(base,Rect2(534,0,546,670),Rect2(534.0/1080,0,546.0/1080,1),flat)
	_warp(_page(current,"right"),Rect2(534,16,506,614),Rect2(0,0,1,1),flat)
	var cast:=PackedVector2Array()
	for point: Vector2 in [Vector2(534,14),Vector2(1061,14),Vector2(1061,650),Vector2(534,650)]:
		var dx: float=point.x-534;var height: float=-sin(theta)*dx
		cast.append(flat.call(Vector2(534+cos(theta)*dx+height*0.13,point.y+height*0.20))+Vector2(2,7))
	_soft_shadow(cast,(5+abs(sin(theta))*18)*S,0.27*(1.0-0.35*abs(sin(theta)))*moving_weight)
	var rotate:=func(point: Vector2) -> Vector2:
		var dx: float=point.x-534;var z: float=-sin(theta)*dx;var f: float=10000/(10000-z)
		return flat.call(Vector2(534+dx*cos(theta)*f,335+(point.y-335)*f))
	if cos(theta)>=0:
		for y in 16:
			for x in 16:
				var points:=PackedVector2Array();var uv:=PackedVector2Array()
				for t: Vector2 in [Vector2(float(x)/16,float(y)/16),Vector2(float(x+1)/16,float(y)/16),Vector2(float(x+1)/16,float(y+1)/16),Vector2(float(x)/16,float(y+1)/16)]:
					points.append(rotate.call(Vector2(534+t.x*527,14+t.y*636)));uv.append(raw[0].lerp(raw[1],t.x).lerp(raw[3].lerp(raw[2],t.x),t.y)/Vector2(530,650))
				draw_polygon(points,PackedColorArray([Color.WHITE]),uv,cover_texture)
	else:
		var back:=func(point: Vector2) -> Vector2:return rotate.call(Vector2(1068-point.x,point.y))
		_warp(base,Rect2(0,0,534,670),Rect2(0,0,534.0/1080,1),back)
		_warp(_page(current,"left"),Rect2(28,16,506,614),Rect2(0,0,1,1),back)
