extends SceneTree
const MENU := preload("res://modules/main_menu/MainMenu.tscn")
const Planner := preload("res://modules/main_menu/companion_path.gd")
var output := ProjectSettings.globalize_path("res://../.verification/main-menu/")
var menu: Control
var checks: Array[Dictionary] = []
var failures := 0
var snapshots: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks.append({"ok": ok, "message": message})
	if not ok:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in count: await process_frame
func shot(id: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	var result := root.get_texture().get_image().save_png(output + id + ".png")
	check(result == OK, "native image saved: " + id)
func new_menu() -> void:
	menu = MENU.instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(2)
func remove_menu() -> void:
	menu.queue_free()
	await frames(3)
func pointer(at: Vector2) -> void:
	root.warp_mouse(at)
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)
	if is_instance_valid(menu) and menu.companion.enabled:
		menu.companion.mouse_position = at
	await frames(3)
func click(at: Vector2) -> void:
	await pointer(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
func safe_mouse() -> bool:
	var companion: Node2D = menu.companion
	if not companion.safe_bounds.grow(0.5).has_point(companion.position): return false
	for rect: Rect2 in companion.obstacles:
		if rect.grow(-0.5).has_point(companion.position): return false
	return companion.display_is_safe()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	Input.use_accumulated_input = false
	root.mode = Window.MODE_WINDOWED
	root.position = Vector2i.ZERO
	var previous_scale := root.content_scale_size
	var previous_aspect := root.content_scale_aspect
	for physical: Vector2i in [Vector2i(1920,1080),Vector2i(1920,1200),Vector2i(2560,1440),Vector2i(2560,1600)]:
		root.size = physical
		await new_menu()
		check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN and menu.menu_cursor.sprite.texture!=null, str(physical) + " menu draws the selected custom cursor from its first frame")
		check(root.get_node_or_null("HandDrawnCursor") != null, "reuses existing cursor singleton")
		check(not menu.title_complete and menu.buttons[0].disabled, "menu waits for the typewriter title")
		await frames(40)
		check(not menu.title_complete and menu.paper.holes.is_empty(), "no gnaw during title entrance")
		if physical == Vector2i(1920,1080):
			var shown:=0
			var still:=true
			for i in 18:
				var glyph: TextureRect=menu.title.letters[i]
				if glyph.visible: shown+=1
				var resting: Vector2=menu.title.origin+menu.title.source_rects[i].position*menu.title.art_scale+menu.title.rest_offset(i)
				still=still and glyph.position.is_equal_approx(resting) and glyph.scale==Vector2.ONE
			check(shown>0 and shown<18 and still,"typewriter reveals letters in place without a downward fall or bounce")
			await shot("title-entering")
		await frames(205)
		check(menu.title_complete and not menu.buttons[0].disabled, "all eighteen letters appear before menu activation")
		var view: Vector2 = root.get_visible_rect().size
		check(is_equal_approx(view.x/view.y, 16.0/9.0), "single 16:9 composition on every monitor")
		check(is_equal_approx(menu.paper_rect.size.x/menu.paper_rect.size.y, 16.0/9.0), "paper keeps exact source aspect")
		check(menu.paper_rect.position.x >= 0 and menu.paper_rect.position.y >= 0 and menu.paper_rect.end.x <= view.x+1 and menu.paper_rect.end.y <= view.y+1, "entire supplied paper and shadows fit")
		check(menu.title.letters.size() == 18, "eighteen independently animated letter units")
		check(menu.title.letters[0].texture is AtlasTexture and menu.title.letters[0].texture.atlas.resource_path.ends_with("title_handdrawn_v2.png"), "new cocoa-border yellow-grain artwork is used without altering the original")
		var metadata: Dictionary = menu.metadata
		check(int(metadata.title_reassembly_mismatches) == 0, "source alpha/ink preserved in verified split")
		var final_positions := true
		for i in 18:
			var glyph: TextureRect = menu.title.letters[i]
			var expected: Vector2 = menu.title.origin + menu.title.source_rects[i].position * menu.title.art_scale + menu.title.rest_offset(i)
			if glyph.position.distance_to(expected) > 0.01: final_positions = false
		check(final_positions, "title settles at its intentional hand-set offsets")
		var companion_height: float = menu.companion.sprite.texture.get_height() * menu.companion.base_scale
		check(is_equal_approx(companion_height, 260.0), "mouse legibility updated to 260 logical pixels, stable across ratios")
		check(menu.companion.sprite.texture is AtlasTexture and menu.companion.sprite.texture.atlas.resource_path.ends_with("mouse_cartoon.png"), "uses the user-selected cartoon PNG")
		check(menu.extension is ColorRect and menu.extension.scale == Vector2.ONE, "solid cream margin; no auto-extended background artwork")
		await shot("menu-%dx%d" % [physical.x,physical.y])
		check(menu.icons[0] is Label and menu.icons[0].get_theme_color("font_color")==Color("705039"), "Chinese menu uses deep brown hand lettering")
		check(menu.icons[0].material.shader.resource_path.ends_with("hand_wobble.gdshader"), "Chinese labels have independent hand wobble")
		check(menu.find_children("*","Polygon2D",true,false).is_empty(),"no decorative tape strips remain on the menu")
		check(menu.paper_stack.sheets.size()==4 and menu.paper_stack.get_index()<menu.title.get_index(), "four independent paper layers include the original yellow and extra blue sheets")
		check(menu.get_node_or_null("PaperLighting")==null, "no sunlight patches or half-screen shade overlay")
		if physical == Vector2i(1920,1080):
			await check_title_motion()
			await check_paper_layers()
		snapshots.append({"physical": [physical.x,physical.y], "logical": [view.x,view.y],"paper": str(menu.paper_rect),"first_menu_y": menu.menu_rects[0].get_center().y,"last_menu_y": menu.menu_rects[2].get_center().y})
		# Compare source-space route visibility on both sides, around the protected title/menu.
		var from: Vector2 = menu.paper_rect.position + menu.paper_rect.size * Vector2(0.16,0.73)
		var to: Vector2 = menu.paper_rect.position + menu.paper_rect.size * Vector2(0.83,0.73)
		var route: PackedVector2Array = Planner.route(from,to,menu.companion.safe_bounds,menu.companion.obstacles)
		var all_clear := not route.is_empty()
		var previous := from
		for waypoint in route:
			all_clear = all_clear and Planner.segment_clear(previous,waypoint,menu.companion.obstacles)
			previous = waypoint
		check(all_clear, "mouse takes a direct route across typography with no text obstacles")
		if physical == Vector2i(1920,1080):
			await interactions()
		await remove_menu()
		check(root.content_scale_size == previous_scale and root.content_scale_aspect == previous_aspect, "menu restores original game scaling on exit")
	# Click through to the actual imported visual novel, not the maze selector or placeholder.
	root.size = Vector2i(1920,1080)
	await new_menu()
	await frames(250)
	await click(menu.buttons[0].get_global_rect().get_center())
	await frames(6)
	check(root.get_node_or_null("MenuPaperTransition") == null, "Start uses a short fade without an extracted sheet")
	await shot("start-fade")
	await frames(55)
	var novel: Control = current_scene
	check(is_instance_valid(novel) and novel.scene_file_path == "res://modules/visual_novel/VisualNovel.tscn", "Start opens the real visual novel")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"leaving the menu restores the existing native story cursor")
	check(root.content_scale_size == Vector2i(1600,900) and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "story retains original 1600x900 16:9 composition")
	var day: Control = novel.story.bakery
	check(day.flow.queue.size() == 1 and "三十二岁" in day.flow.current_line().text, "imported DAY01 opening is the friend's merged opening, not the three-line placeholder")
	day.runtime.letters = 10000
	day.runtime._process(0)
	await frames(3)
	await shot("visual-novel-opening")
	var right := InputEventKey.new()
	right.pressed = true
	right.keycode = KEY_RIGHT
	day.runtime._input(right)
	check(day.flow.section == "exterior", "real visual novel continues with original Right-key navigation")
	await frames(100)
	day.runtime.letters = 10000
	day.runtime._process(0)
	await frames(2)
	await shot("visual-novel-exterior")
	check(root.get_node_or_null("MenuPaperTransition") == null, "transition releases temporary screen texture and overlay")
	novel.queue_free()
	await frames(5)
	# Minimal story adapter mounts unchanged formal mazes and leaves development results unscored.
	for number in [1,2,3]:
		var bridge: Control = load("res://modules/visual_novel/scripts/story/story_race.gd").new()
		bridge.round_number = number
		root.add_child(bridge)
		await frames(25)
		var runtime: Node = bridge.runtime
		check(is_instance_valid(runtime) and is_instance_valid(runtime.hud), "story trial %d uses the original shared HUD" % number)
		check(runtime.intro.active and runtime.clock.elapsed == 0.0 and not runtime.actor.controls_enabled, "story trial %d retains intro, input lock, clock and countdown ordering" % number)
		if number == 3: check(bridge.maze.race.current_mode == "Race" and bridge.maze.race.state == "PREPARATION", "story third trial retains default Race")
		var result: Array = []
		bridge.finished.connect(func(value: Dictionary): result.append(value))
		bridge.development_finish()
		await frames(6)
		check(result.size() == 1 and result[0].seconds == null and not result[0].score_valid, "story development skip %d cannot fabricate a race time" % number)
	var file := FileAccess.open(output + "results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks,"failures": failures,"snapshots":snapshots},"\t"))
	var cursor := root.get_node_or_null("HandDrawnCursor")
	if cursor: cursor.queue_free()
	await frames(3)
	print("MAIN_MENU_RESULTS ", checks.size(), " checks; failures=", failures)
	quit(1 if failures else 0)
func interactions() -> void:
	var c: Node2D = menu.companion
	menu.foley.mute_when_unfocused = false
	# Keep the native window test independent of desktop mouse movement outside the game.
	c.set_process_input(false)
	await check_mouse_animation(c)
	await check_text_crossing(c)
	await check_full_turn(c)
	# Use real pointer motion through the native viewport, including a route around the menu.
	for point in [Vector2(330,820),Vector2(1550,830),Vector2(1800,1050),Vector2(900,760),Vector2(270,320)]:
		await pointer(point)
		var all_safe := true
		for i in 120:
			await frames(1)
			all_safe = all_safe and safe_mouse()
		check(all_safe, "live mouse stays on paper while freely crossing text toward " + str(point))
	await pointer(Vector2(650,780))
	await frames(70)
	check(c.state != c.State.GNAW, "mouse waits before idle Easter egg")
	var holes_before: int = menu.paper.holes.size()
	await frames(120)
	check(c.state == c.State.GNAW, "1.5 seconds of stationary pointer starts gnaw; state=%s still=%.2f" % [c.state,c.still_time])
	await frames(210)
	check(menu.paper.holes.size() > holes_before and int(menu.paper.holes.back().bites) == 4, "four bites grow a retained irregular paper tear")
	await shot("gnaw-four-bites")
	await pointer(Vector2(420,850))
	check(c.state != c.State.GNAW and c.still_time < 0.2, "moving pointer immediately cancels gnaw")
	var retained: int = menu.paper.holes.size()
	var center: Vector2 = menu.buttons[1].get_global_rect().get_center()
	await click(center)
	await frames(5)
	check(menu.credits.opening and menu.credits.active, "Credits is attached as a central sticky note")
	await shot("credits-note-arriving")
	await frames(30)
	check(menu.credits_open and menu.credits.visible and not c.enabled, "native Credits hit target opens note and stops companion")
	check(menu.menus.visible and menu.title.visible and menu.credits.dim.color.a>0.3, "original menu remains behind the dimmed sticky note")
	check(menu.credits.note.get_theme_stylebox("panel").bg_color==Color("fff0b4"), "Credits uses a creamy yellow note surface")
	check(menu.credits.corner!=null and menu.credits.note.material.shader.resource_path.ends_with("paper_fold.gdshader"), "sticky note has a transparent cut-out and a folded paper back at its lower corner")
	check(not menu.foley.voice.playing, "paper steps stop while a note is open")
	await frames(340)
	check(menu.paper.holes.size() == retained, "no gnaw or extra holes during credits")
	await shot("credits-sticky-1920x1080")
	menu.credits.back.pressed.emit()
	await frames(5)
	check(menu.credits.closing,"Return peels the note off the page")
	await shot("credits-note-peeling")
	await frames(30)
	check(not menu.credits_open and c.enabled and menu.paper.visible, "Return restores menu, companion and current tears")
	check(menu.paper.holes.size() == retained, "existing tears persist on returning from credits")
	await check_exit_note()
	await check_random_tears()
	# External story modules can take the entry signal without loading the maze host.
	var started := [false]
	menu.start_requested.connect(func(): started[0] = true)
	menu.buttons[0].pressed.emit()
	await frames(105)
	check(started[0] and is_instance_valid(menu), "exported start signal allows future story integration")

func check_title_motion() -> void:
	var samples: Array[Image] = []
	for phase in 3:
		await frames(8)
		RenderingServer.force_draw(false)
		samples.append(root.get_texture().get_image())
	for i in 18:
		var glyph: TextureRect = menu.title.letters[i]
		var area := Rect2i(glyph.get_global_rect()).intersection(Rect2i(0,0,1920,1080))
		var changed := 0
		for y in range(area.position.y,area.end.y):
			for x in range(area.position.x,area.end.x):
				if color_distance(samples[0].get_pixel(x,y),samples[1].get_pixel(x,y)) > 0.012 or color_distance(samples[1].get_pixel(x,y),samples[2].get_pixel(x,y)) > 0.012: changed += 1
		check(changed > 20,"letter %d has actual changing hand-drawn frames after landing" % i)

func color_distance(a: Color,b: Color) -> float:
	return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)

func check_mouse_animation(c: Node2D) -> void:
	c.position=Vector2(350,780)
	c.velocity=Vector2.ZERO
	await pointer(Vector2(1550,780))
	await frames(5)
	var last: int=c.pose_frame
	var updates:=0
	var smooth:=0
	var travelled:=0.0
	var steps_before: int=menu.foley.steps
	var prior: Vector2=c.sprite.global_position
	var safe:=true
	for i in 60:
		await frames(1)
		if c.pose_frame!=last:
			updates+=1
			last=c.pose_frame
		var movement: float=c.sprite.global_position.distance_to(prior)
		travelled+=movement
		if movement>0.1: smooth+=1
		prior=c.sprite.global_position
		safe=safe and c.display_is_safe()
	check(updates>=9 and updates<=11,"small body poses retain ten hand-drawn beats per second")
	check(smooth>=55,"world movement updates smoothly every frame rather than holding ten poses")
	check(travelled>250.0 and travelled<460.0,"mouse keeps a responsive continuous following speed")
	check(menu.foley.steps>steps_before,"moving companion produces short paper rustle grains")
	check(safe,"body and tail remain on the paper through movement")
	await shot("cartoon-mouse-follow")
	await pointer(Vector2(250,300))
	var last_angle: float=c.sprite.rotation
	var largest_turn:=0.0
	for i in 30:
		await frames(1)
		largest_turn=maxf(largest_turn,absf(angle_difference(last_angle,c.sprite.rotation)))
		last_angle=c.sprite.rotation
	check(largest_turn<0.55,"reversing pointer direction turns smoothly without held-angle snaps")

func check_text_crossing(c: Node2D) -> void:
	c.position=Vector2(940,860)
	c.velocity=Vector2.ZERO
	await pointer(Vector2(940,160))
	var text_frames:=0
	for i in 125:
		await frames(1)
		for rect in menu.ink_rects:
			if rect.has_point(c.sprite.global_position):
				text_frames+=1
				break
	check(c.obstacles.is_empty() and text_frames>20,"mouse actually crosses title and menu ink instead of diverting around it")
	check(menu.companion.get_index()>menu.title.get_index(),"mouse is drawn above the title it walks across")
	check(float(menu.title.letters[0].material.get_shader_parameter("paw_strength"))>0.9,"active companion provides live pressure to title and handwritten ink")
	await shot("mouse-on-title")

func check_exit_note() -> void:
	await click(menu.buttons[2].get_global_rect().get_center())
	await frames(26)
	check(menu.exit_open and menu.exit_note.active and current_scene==menu,"Desktop opens a confirmation instead of quitting immediately")
	var surface: StyleBoxFlat = menu.exit_note.note.get_theme_stylebox("panel")
	check(surface.bg_color==Color("fff5dffb") and surface.corner_radius_top_left==16,"exit confirmation reuses the maze note surface")
	check(menu.exit_note.note.size.is_equal_approx(menu.exit_note.dimensions), "exit note keeps its intended compact size after wrapping text")
	check(menu.exit_note.note.get_global_rect().end.y<root.get_visible_rect().size.y-100, "exit note and actions remain fully inside the screen")
	await shot("exit-confirmation")
	menu.exit_note.cancel_button.pressed.emit()
	await frames(30)
	check(not menu.exit_open and menu.companion.enabled and current_scene==menu,"Cancel returns to the same menu")
	menu.open_credits()
	await frames(3)
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	Input.parse_input_event(escape)
	await frames(30)
	check(not menu.credits_open and not menu.credits.active and menu.companion.enabled,"Escape during note arrival safely peels and restores input")

func check_paper_layers() -> void:
	var artwork: Array=[menu.title,menu.menus,menu.flowers,menu.companion,menu.paper.reveal,menu.menu_cursor.sprite,menu.vignette]
	var visibility: Array[bool]=[]
	for item in artwork:
		visibility.append(item.visible)
		item.hide()
	await frames(2)
	RenderingServer.force_draw(false)
	var rendered:=root.get_texture().get_image()
	var paper: Image=menu.paper_stack.sheets[0].texture.get_image()
	check(menu.background.texture.resource_path.ends_with("wood_desk.png") and paper.get_pixel(0,0).a<0.1,"transparent paper stack exposes a separate wooden desk")
	var visible_blue:=false
	var visible_yellow:=false
	# Paper tilt moves exposed corners, so inspect their regions instead of one fixed pixel.
	for y in range(1050,1080,2):
		for x in range(40,1890,2):
			var pixel:=rendered.get_pixel(x,y)
			if x<480 and pixel.b>pixel.r+0.025 and pixel.g>0.6: visible_blue=true
			if x>900 and pixel.r>0.8 and pixel.g>0.7 and pixel.r>pixel.b+0.12: visible_yellow=true
	check(visible_blue and visible_yellow,"the original yellow sheet remains distinct from the additional pale blue sheet")
	check(rendered.get_pixel(80,500).r>0.90 and rendered.get_pixel(1842,750).r>0.90 and rendered.get_pixel(960,1022).r>0.90,"front paper keeps the original large on-screen coverage")
	var front: ShaderMaterial=menu.paper_stack.sheets[3].material
	var scale: Vector2=front.get_shader_parameter("art_scale")
	var offset: Vector2=front.get_shader_parameter("art_offset")
	var corner_a: Vector2=front.get_shader_parameter("corner_a")
	var corner_c: Vector2=front.get_shader_parameter("corner_c")
	var center: Vector2=(corner_a+corner_c)*0.5*menu.paper_rect.size*scale+offset
	check(center.distance_to(menu.paper_rect.size*0.5)<0.5 and is_equal_approx(scale.x,scale.y),"paper enlarges evenly around its own visual center, with original title/menu sizing")
	var stray_blue:=0
	var corner_blue:=0
	for y in range(0,1080,3):
		for x in range(0,1920,3):
			var pixel:=rendered.get_pixel(x,y)
			if pixel.b>pixel.r+0.025:
				if x<480 and y>1035: corner_blue+=1
				else: stray_blue+=1
	check(corner_blue>50 and stray_blue<25,"extra pale blue appears only as a small lower-left paper corner (corner=%d, stray=%d)"%[corner_blue,stray_blue])
	var complete:=true
	for layer in 3:
		var image: Image=menu.paper_stack.sheets[layer].texture.get_image()
		for y in range(1,10):
			for x in range(1,10):
				complete=complete and image.get_pixel(int(image.get_width()*float(x)/10.0),int(image.get_height()*float(y)/10.0)).a>0.98
	check(complete,"all lower sheets have complete opaque interiors instead of clipped paper wedges")
	var no_gaps:=true
	for phase in 3:
		await frames(9)
		RenderingServer.force_draw(false)
		var sample:=root.get_texture().get_image()
		for x in range(80,1840,4):
			var reached_desk:=false
			for y in range(1000,1080):
				var pixel:=sample.get_pixel(x,y)
				var desk:=pixel.r<0.70 and pixel.g<0.50 and pixel.b<0.35
				if desk: reached_desk=true
				elif reached_desk and pixel.r>0.80: no_gaps=false
	check(no_gaps,"all held paper frames keep continuous overlap without desk-colored holes along the lower edge")
	RenderingServer.force_draw(false)
	var shaded:=root.get_texture().get_image()
	for shade in menu.paper_stack.shadows: shade.hide()
	RenderingServer.force_draw(false)
	var flat:=root.get_texture().get_image()
	var shadow_pixels:=0
	for y in range(0,1080,2):
		for x in range(0,1920,2):
			var base:=flat.get_pixel(x,y)
			if base.r<0.70 and base.g<0.50 and base.b<0.35 and base.get_luminance()-shaded.get_pixel(x,y).get_luminance()>0.008: shadow_pixels+=1
	check(shadow_pixels>100,"paper stack casts a real visible soft shadow onto the separate warm wooden desk")
	for shade in menu.paper_stack.shadows: shade.show()
	var minimum:=1.0
	var maximum:=0.0
	for y in range(630,730):
		for x in range(1250,1400):
			var value:=rendered.get_pixel(x,y).get_luminance()
			minimum=minf(minimum,value)
			maximum=maxf(maximum,value)
	check(minimum>0.82 and maximum-minimum>0.008,"cream paper retains a faint dot-grid instead of a blank surface")
	var base_at: Vector2=menu.background.position
	var regions: Array[Rect2i]=[Rect2i(30,1055,310,25),Rect2i(0,400,55,200),Rect2i(500,1040,1200,40),Rect2i(4,450,45,160)]
	menu.background.hide()
	for shade in menu.paper_stack.shadows: shade.hide()
	for sheet in menu.paper_stack.sheets: sheet.hide()
	for layer in 4:
		menu.paper_stack.sheets[layer].show()
		var samples: Array[Image]=[]
		for phase in 3:
			await frames(9)
			RenderingServer.force_draw(false)
			samples.append(root.get_texture().get_image())
		var changed:=0
		var area: Rect2i=regions[layer]
		for y in range(area.position.y,area.end.y):
			for x in range(area.position.x,area.end.x):
				if color_distance(samples[0].get_pixel(x,y),samples[1].get_pixel(x,y))>0.012 or color_distance(samples[1].get_pixel(x,y),samples[2].get_pixel(x,y))>0.012: changed+=1
		check(changed>40,"paper sheet %d has its own real held-frame edge movement"%layer)
		menu.paper_stack.sheets[layer].hide()
	menu.background.show()
	for shade in menu.paper_stack.shadows: shade.show()
	for sheet in menu.paper_stack.sheets: sheet.show()
	check(menu.background.position==base_at and menu.paper_stack.sheets[0].material!=menu.paper_stack.sheets[1].material,"desk and layout stay fixed while individual sheets animate")
	for i in artwork.size(): artwork[i].visible=visibility[i]

func check_random_tears() -> void:
	menu.companion.set_enabled(false)
	menu.companion.visible=true
	var p: Node2D=menu.paper
	p.holes.clear()
	for at in [Vector2(1470,470),Vector2(1630,610),Vector2(1450,740)]:
		p.begin_gnaw(at)
		for i in 4: p.bite()
		await frames(60)
		p.stop_gnaw()
	check(p.holes[0].seed!=p.holes[1].seed and p.holes[0].profile!=p.holes[1].profile,"each gnaw site gets an independent random outline")
	check(p.holes[0].radius!=p.holes[1].radius and p.holes[1].angle!=p.holes[2].angle,"tear size, aspect and rotation vary between bites")
	var enlarged:=true
	for hole in p.holes: enlarged=enlarged and float(hole.radius)>=23.0 and float(hole.radius)<=35.0 and is_equal_approx(float(hole.growth),4.0)
	check(enlarged,"full tears are larger, continuous, and show a white torn-paper rim")
	await shot("random-white-tears")
	for i in 8: p.begin_gnaw(Vector2(1500,500))
	var old_seed: float=p.holes.back().seed
	p.begin_gnaw(Vector2(1500,500))
	check(p.holes.size()==8 and float(p.holes.back().seed)!=old_seed,"tear limit cannot repeat the same shape when older holes are removed")
	p.stop_gnaw()
	menu.companion.set_enabled(true)
	menu.companion.set_process_input(false)


func check_full_turn(c: Node2D) -> void:
	c.position=Vector2(940,540)
	c.velocity=Vector2.ZERO
	c.body_angle=0.0
	c.turn_speed=0.0
	var previous: float=c.body_angle
	var total_turn:=0.0
	var headings: Dictionary={}
	for i in 300:
		var angle:=TAU*float(i)/270.0
		c.mouse_position=Vector2(940,540)+Vector2(cos(angle)*390.0,sin(angle)*230.0)
		await frames(1)
		if i>25: total_turn+=angle_difference(previous,c.body_angle)
		previous=c.body_angle
		headings[int(fposmod(c.body_angle,TAU)/(PI/4.0))]=true
	check(headings.size()==8 and absf(total_turn)>TAU*0.90,"orbiting pointer makes the mouse turn continuously through a full 360 degrees")
	c.position=Vector2(800,720)
	c.velocity=Vector2.RIGHT*200.0
	c.body_angle=PI/2.0
	c.turn_speed=0.0
	c.mouse_position=Vector2(800,220)
	c.last_mouse_position=c.mouse_position
	c.still_time=0.0
	var arc_x:=c.position.x
	var widest_arc:=0.0
	for i in 30:
		await frames(1)
		widest_arc=maxf(widest_arc,absf(c.position.x-arc_x))
	check(widest_arc>6.0,"a right-angle target change produces a curved body-led turn instead of straight-line strafing")
	await shot("mouse-free-turn")
