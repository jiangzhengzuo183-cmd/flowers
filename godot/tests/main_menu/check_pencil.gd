extends SceneTree
var menu: Control
var checks:=0
var failures:=0
var output:=ProjectSettings.globalize_path("res://../.verification/main-menu/")
func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for i in count: await process_frame
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func shot(name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(output+name+".png")
func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1920,1080)
	root.position=Vector2i.ZERO
	menu=load("res://modules/main_menu/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	await frames(250)
	menu.menu_cursor.set_process_input(false)
	menu.menu_cursor.pointer=Vector2(1760,760)
	menu.menu_cursor.sprite.show()
	var c: Node2D=menu.companion
	var p: Node2D=menu.pencil
	c.set_process(false)
	c.set_process_input(false)
	c.set_enabled(true)
	var crossing: Vector2=p.start.lerp(p.tip,0.88)
	var axis: Vector2=(p.tip-p.start).normalized()
	var normal:=Vector2(-axis.y,axis.x)
	c.position=crossing+normal*105.0
	c.body_angle=(-normal).angle()+PI/2.0
	c.velocity=-normal*300.0
	c.mouse_position=crossing-normal*700.0
	c.last_mouse_position=c.mouse_position
	var before: int=c.hops
	var peak:=0.0
	var ground_gap:=0.0
	var active_frames:=0
	var took_shot:=false
	for i in 100:
		c._process(1.0/60.0)
		if c.state==c.State.JUMP: active_frames+=1
		peak=maxf(peak,c.jump_height)
		ground_gap=maxf(ground_gap,c.shadow.global_position.y-c.sprite.global_position.y)
		if c.jump_height>41.0 and not took_shot:
			await shot("pencil-hop-peak")
			took_shot=true
		await frames(1)
	check(c.hops==before+1 and active_frames>=37 and active_frames<=41,"crossing the shaft triggers one short, complete hop")
	check(peak>41.0 and peak<=42.01 and ground_gap>42.0,"body rises while its contact shadow stays on the paper")
	check(c.jump_height==0.0 and c.state!=c.State.JUMP,"landing restores normal following without leaving the mouse airborne")
	check(c.shadow.material.get_shader_parameter("airborne")==0.0,"landing restores the normal contact shadow")
	c.position=crossing
	c.velocity=Vector2.ZERO
	c.state=c.State.IDLE
	c.mouse_position=c.position
	c.last_mouse_position=c.mouse_position
	c.still_time=0.0
	var holes_before: int=menu.paper.holes.size()
	for i in 250:
		c._process(1.0/60.0)
		await frames(1)
	check(c.state!=c.State.GNAW and menu.paper.holes.size()==holes_before,"stationary mouse cannot gnaw the pencil or the paper directly beneath it")
	c.body_angle=(-normal).angle()+PI/2.0
	c.position=crossing+normal*c.nose_local.length()
	c._update_art(0.0)
	check(not c._gnaw_clear() and p.distance_to_shaft(c.position)>p.half_width+50.0,"nose and largest tear rim are protected even when the body is away from the shaft")
	check(not p.would_cross(crossing+Vector2(-axis.y,axis.x)*40.0,axis*400.0),"parallel movement beside the pencil does not trigger a jump")
	c.position=crossing-normal*105.0
	c.mouse_position=crossing+normal*700.0
	c.last_mouse_position=c.mouse_position
	c.body_angle=normal.angle()+PI/2.0
	c.velocity=normal*320.0
	c.jump_armed=true
	c.still_time=0.0
	before=c.hops
	for i in 100:
		c._process(1.0/60.0)
		await frames(1)
	check(c.hops==before+1 and c.jump_height==0.0,"crossing from the opposite side also completes exactly one hop")
	check(p.get_index()<c.get_index() and p.get_index()>menu.title.get_index(),"pencil lies above the paper ink and below the mouse")
	c.jump_age=0.20
	c.jump_height=25.0
	c._update_art(0.0)
	menu.open_credits()
	await frames(30)
	check(c.jump_height==0.0 and not c.enabled and absf(c.sprite.position.y)<1.0 and float(c.shadow.material.get_shader_parameter("airborne"))==0.0,"opening a panel grounds both body and shadow immediately, including mid-hop")
	menu.credits.peel()
	await frames(30)
	c.set_enabled(true)
	c.set_process(false)
	c.position=Vector2(650,860)
	c.body_angle=-0.4
	c.velocity=Vector2.ZERO
	c._update_art(0.0)
	await shot("menu-pencil-final")
	p.art.hide()
	await shot("pencil-shadow-only")
	var shadow_image:=root.get_texture().get_image()
	p.contact.hide()
	p.shadow.hide()
	await shot("pencil-shadow-baseline")
	var flat_image:=root.get_texture().get_image()
	var shaded:=0
	for y in range(730,1040):
		for x in range(160,420):
			if flat_image.get_pixel(x,y).get_luminance()-shadow_image.get_pixel(x,y).get_luminance()>0.025: shaded+=1
	check(shaded>1000,"the native paper image contains a visible pencil contact shadow and soft cast shadow")
	p.art.show()
	p.contact.show()
	p.shadow.show()
	print("PENCIL_RESULTS ",checks," checks; failures=",failures," peak=",peak," airborne_frames=",active_frames)
	menu.queue_free()
	var cursor:=root.get_node_or_null("HandDrawnCursor")
	if cursor: cursor.queue_free()
	await frames(3)
	quit(1 if failures else 0)
