extends Node2D
## Randomized non-destructive tears; generated once per bite site, stable between frames.
var paper_rect:=Rect2()
var holes: Array[Dictionary]=[]
var active_hole:=-1
var redraw_pending:=false
var rng:=RandomNumberGenerator.new()
func _ready() -> void: rng.randomize()
func place(rect: Rect2) -> void:
	paper_rect=rect
	queue_redraw()
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
	queue_redraw()
func _draw() -> void:
	var unit:=paper_rect.size.x/1920.0
	for hole in holes:
		var growth:=float(hole.growth)
		if growth<=0.01: continue
		var center: Vector2=paper_rect.position+Vector2(hole.uv)*paper_rect.size
		var fraction:=clampf(growth/4.0,0.0,1.0)
		var radius:=float(hole.radius)*sqrt(fraction)*unit
		var inner:=PackedVector2Array()
		var outer:=PackedVector2Array()
		for i in 48:
			var angle:=TAU*float(i)/48.0
			var direction:=Vector2(cos(angle),sin(angle)*float(hole.aspect)).rotated(float(hole.angle))
			inner.append(center+direction*radius*float(hole.profile[i]))
			outer.append(center+direction*(radius*float(hole.profile[i])+float(hole.rim[i])*sqrt(fraction)*unit))
		# Torn white paper fibers surround the warm lower sheet, rather than a black hole.
		draw_colored_polygon(outer,Color("fffef2"))
		draw_colored_polygon(inner,Color("d7ccb2"))
		var edge:=inner.duplicate()
		edge.append(inner[0])
		draw_polyline(edge,Color(0.50,0.40,0.26,0.25),1.0*unit,true)
		for i in range(1,46,3):
			var p:=inner[i]
			var inward: Vector2=(center-p).normalized()
			var fiber: float=(0.9+float(hole.rim[i])*0.45)*unit*sqrt(fraction)
			draw_line(p-inward*unit,p+inward*fiber,Color(1.0,0.99,0.94,0.90),0.8*unit,true)
