extends SceneTree
var menu: Control
var output:=ProjectSettings.globalize_path("res://../.verification/main-menu/")
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for i in count: await process_frame
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func shot(name: String) -> Image:
	await frames(1)
	RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image()
	image.save_png(output+name+".png")
	return image
func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1920,1080)
	root.position=Vector2i.ZERO
	menu=load("res://modules/main_menu/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	await frames(2)
	menu.menu_cursor.set_process_input(false)
	menu.menu_cursor.pointer=Vector2(1500,700)
	menu.menu_cursor.sprite.show()
	check(Input.mouse_mode==Input.MOUSE_MODE_HIDDEN and not menu.title_complete,"main menu owns the selected cursor before title entry completes")
	check(menu.menu_cursor.cursor_frames[0]==root.get_node("HandDrawnCursor").frames[0],"menu reuses the exact existing cursor artwork")
	var first:=await shot("cursor-first-frame")
	var cursor_ink:=0
	for y in range(694,786):
		for x in range(1493,1573):
			var pixel:=first.get_pixel(x,y)
			if pixel.r>0.75 and pixel.g>0.35 and pixel.b<0.35: cursor_ink+=1
	check(cursor_ink>500,"the native rendered first-menu image contains the yellow hand-drawn pointer")
	var cursor_frames: Dictionary={}
	for i in 30:
		await frames(1)
		cursor_frames[menu.menu_cursor.frame]=true
	check(cursor_frames.size()==3,"main menu pointer cycles through all three established wobble frames")
	var bloom: TextureRect=menu.flowers.blooms[0]
	var area:=Rect2i(bloom.get_global_rect()).grow(2)
	var before:=await shot("flowers-brush-start")
	var progress_before: float=bloom.material.get_shader_parameter("progress")
	await frames(38)
	var during:=await shot("flowers-brush-middle")
	var progress_during: float=bloom.material.get_shader_parameter("progress")
	check(progress_before<progress_during and progress_during<1.0,"flowers are progressively drawn rather than appearing at once")
	await frames(130)
	menu.companion.set_enabled(false)
	var after:=await shot("flowers-brush-complete")
	var changed:=0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			if absf(after.get_pixel(x,y).b-before.get_pixel(x,y).b)>0.025: changed+=1
	check(changed>100,"blue crayon petals really appear in the rendered image")
	check(menu.flowers.blooms.size()==8 and bloom.texture is AtlasTexture,"eight stemless heads form three larger, staggered flower groups")
	var first_frame:=after
	await frames(10)
	var next_frame:=await shot("flowers-wobble")
	var wobble:=0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			if absf(first_frame.get_pixel(x,y).b-next_frame.get_pixel(x,y).b)>0.018: wobble+=1
	check(wobble>20,"finished flower petals retain visible hand-drawn frame motion")
	var p: Node2D=menu.paper
	p.holes.clear()
	for at in [Vector2(1450,570),Vector2(1486,570),Vector2(1522,570)]:
		p.begin_gnaw(at)
		p.holes.back().radius=32.0
		p.holes.back().aspect=1.0
		for i in 4: p.bite()
		await frames(60)
		p.stop_gnaw()
	await shot("connected-tears-notes")
	RenderingServer.force_draw(false)
	var mask: Image=p.mask_viewport.get_texture().get_image()
	var continuous:=true
	for x in range(1430,1540):
		var pixel:=mask.get_pixel(x,570)
		continuous=continuous and pixel.g>0.96 and pixel.r-pixel.g<0.02
	check(continuous,"overlapping tear interiors connect with no internal white rim seam")
	check(mask.get_pixel(1380,570).r<0.01,"the lower notes remain hidden outside the tear")
	var notes: Image=p.notes_viewport.get_texture().get_image()
	notes.save_png(output+"underpaper-full-page.png")
	print("NOTES_VIEWPORT mode=",p.notes_viewport.render_target_update_mode," page=",notes.get_size()," sample=",notes.get_pixel(1500,570))
	var handwriting_pixels:=0
	var inner_shadow_pixels:=0
	var rendered: Image=root.get_texture().get_image()
	for y in range(545,597):
		for x in range(1440,1532):
			if notes.get_pixel(x,y).get_luminance()<0.82: handwriting_pixels+=1
			if mask.get_pixel(x,y).g>0.97 and notes.get_pixel(x,y).get_luminance()-rendered.get_pixel(x,y).get_luminance()>0.06: inner_shadow_pixels+=1
	check(inner_shadow_pixels>30,"the upper sheet casts a visible inset shadow onto the lower paper inside the opening")
	check(handwriting_pixels>25,"a real global handwritten English page exists behind the connected holes")
	check(p.notes_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"the notes page is cached rather than rebuilt every frame")
	var disconnected:=mask.get_pixel(1300,500)
	check(disconnected.r==0 and disconnected.g==0,"unchewed paper cannot expose the hidden text")
	await check_printed_ink()
	await check_live_shadow()
	menu.open_credits()
	await frames(30)
	menu.menu_cursor.pointer=menu.credits.back.get_global_rect().get_center()
	await shot("credits-custom-cursor")
	check(Input.mouse_mode==Input.MOUSE_MODE_HIDDEN and menu.menu_cursor.sprite.texture!=null,"credits and menu hover keep the selected software cursor")
	menu.close_credits()
	await frames(30)
	check(menu.paper_stack.sheets[0].material.get_shader_parameter("amount")>1.5 and menu.paper_stack.sheets[3].material.get_shader_parameter("amount")>1.2,"independent sheet motion is increased without moving the menu layout")
	print("PAPER_DETAILS_RESULTS ",checks," checks; failures=",failures)
	menu.queue_free()
	await frames(4)
	var shared_cursor:=root.get_node_or_null("HandDrawnCursor")
	if shared_cursor: shared_cursor.queue_free()
	await frames(3)
	quit(1 if failures else 0)

func cut(at: Vector2) -> void:
	menu.paper.begin_gnaw(at)
	menu.paper.holes.back().radius=32.0
	menu.paper.holes.back().aspect=1.0
	for i in 4: menu.paper.bite()
	await frames(60)
	menu.paper.stop_gnaw()
func check_printed_ink() -> void:
	var glyph: TextureRect=menu.title.letters[0]
	var at:=glyph.get_global_rect().position+glyph.size*Vector2(0.25,0.20)
	var before:=await shot("printed-title-before")
	await cut(at)
	var after:=await shot("printed-title-torn")
	var blue_before:=0.0
	var blue_after:=0.0
	for y in range(int(at.y)-8,int(at.y)+8):
		for x in range(int(at.x)-8,int(at.x)+8):
			blue_before+=before.get_pixel(x,y).b
			blue_after+=after.get_pixel(x,y).b
	check(blue_after-blue_before>40.0,"gnawing the yellow title removes its printed ink and exposes the lower page")
	var bloom: TextureRect=menu.flowers.blooms[0]
	at=bloom.get_global_rect().get_center()+Vector2(bloom.size.x*0.25,0)
	before=await shot("printed-flower-before")
	await cut(at)
	after=await shot("printed-flower-torn")
	var mask: Image=menu.paper.mask_viewport.get_texture().get_image()
	var before_blue:=0
	var after_blue:=0
	for y in range(int(at.y)-27,int(at.y)+27):
		for x in range(int(at.x)-27,int(at.x)+27):
			if mask.get_pixel(x,y).g<0.97: continue
			var a:=before.get_pixel(x,y)
			var z:=after.get_pixel(x,y)
			if a.b>a.r+0.03: before_blue+=1
			if z.b>z.r+0.03: after_blue+=1
	check(before_blue>20 and after_blue<before_blue*0.25,"a flower is printed on the sheet and loses its blue strokes inside a tear")
	at=menu.icons[1].get_global_rect().get_center()
	before=await shot("printed-chinese-before")
	await cut(at)
	after=await shot("printed-chinese-torn")
	mask=menu.paper.mask_viewport.get_texture().get_image()
	var before_ink:=0
	var after_ink:=0
	for y in range(int(at.y)-25,int(at.y)+25):
		for x in range(int(at.x)-27,int(at.x)+27):
			if mask.get_pixel(x,y).g<0.97: continue
			if before.get_pixel(x,y).r<0.60: before_ink+=1
			if after.get_pixel(x,y).r<0.60: after_ink+=1
	check(before_ink>20 and after_ink<before_ink*0.25,"Chinese menu ink is cut away by the same paper hole")
	await shot("paper-ink-cutaways")

func check_live_shadow() -> void:
	var c: Node2D=menu.companion
	c.set_enabled(true)
	c.set_process_input(false)
	c.set_process(false)
	c.position=Vector2(600,840)
	c.body_angle=PI/2.0
	c.turn_speed=0.0
	c.velocity=Vector2(310,0)
	c.gait_time=0.0
	c.sprite.hide()
	c._update_art(1.0/60.0)
	var first_cycle: float=c.shadow.material.get_shader_parameter("step_cycle")
	var first:=await shot("mouse-contact-shadow-only")
	for i in 8:
		c._update_art(1.0/60.0)
		await frames(1)
	var second:=await shot("mouse-contact-shadow-step")
	var changed:=0
	for y in range(760,920):
		for x in range(500,700):
			if absf(first.get_pixel(x,y).get_luminance()-second.get_pixel(x,y).get_luminance())>0.012: changed+=1
	check(c.shadow.material.get_shader_parameter("step_cycle")!=first_cycle and changed>20,"body and paw contact shadows visibly change with the step cycle")
	var before_scale: Vector2=c.shadow.scale
	c.turn_speed=10.5
	c._update_art(1.0/60.0)
	check(float(c.shadow.material.get_shader_parameter("turn_load"))>0.9 and c.shadow.scale.x>before_scale.x,"turning redistributes the close contact shadow")
	c.sprite.show()
	c.set_process(true)
	c.set_enabled(false)
