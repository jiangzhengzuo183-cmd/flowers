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
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, str(physical) + " independent visible custom cursor")
		check(root.get_node_or_null("HandDrawnCursor") != null, "reuses existing cursor singleton")
		check(not menu.title_complete and menu.buttons[0].disabled, "menu waits for falling letters")
		await frames(40)
		check(not menu.title_complete and menu.paper.holes.is_empty(), "no gnaw during title entrance")
		if physical == Vector2i(1920,1080): await shot("title-entering")
		await frames(205)
		check(menu.title_complete and not menu.buttons[0].disabled, "all eighteen letters settle before menu activation")
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
		if physical == Vector2i(1920,1080): await check_title_motion()
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
		check(all_clear, "mouse can route around protected ink without crossing it")
		if physical == Vector2i(1920,1080):
			await interactions()
		await remove_menu()
		check(root.content_scale_size == previous_scale and root.content_scale_aspect == previous_aspect, "menu restores original game scaling on exit")
	# Click through to the actual imported visual novel, not the maze selector or placeholder.
	root.size = Vector2i(1920,1080)
	await new_menu()
	await frames(250)
	await click(menu.buttons[0].get_global_rect().get_center())
	await frames(24)
	check(root.get_node_or_null("MenuPaperTransition") != null, "Start uses the shared paper-stack overlay across scenes")
	await shot("start-paper-stack")
	await frames(70)
	var novel: Control = current_scene
	check(is_instance_valid(novel) and novel.scene_file_path == "res://modules/visual_novel/VisualNovel.tscn", "Start opens the real visual novel")
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
	# Keep the native window test independent of desktop mouse movement outside the game.
	c.set_process_input(false)
	await check_mouse_animation(c)
	# Use real pointer motion through the native viewport, including a route around the menu.
	for point in [Vector2(330,820),Vector2(1550,830),Vector2(1800,1050),Vector2(900,760),Vector2(270,320)]:
		await pointer(point)
		var all_safe := true
		for i in 120:
			await frames(1)
			all_safe = all_safe and safe_mouse()
		check(all_safe, "live mouse stays on paper and outside text on path to " + str(point))
	await pointer(Vector2(345,840))
	await frames(150)
	check(c.state != c.State.GNAW, "mouse waits before idle Easter egg")
	var holes_before: int = menu.paper.holes.size()
	await frames(170)
	check(c.state == c.State.GNAW, "five seconds of stationary pointer starts gnaw; state=%s still=%.2f" % [c.state,c.still_time])
	await frames(170)
	check(menu.paper.holes.size() > holes_before and int(menu.paper.holes.back().bites) == 4, "four bites grow a retained irregular paper tear")
	await shot("gnaw-four-bites")
	await pointer(Vector2(420,850))
	check(c.state != c.State.GNAW and c.still_time < 0.2, "moving pointer immediately cancels gnaw")
	var retained: int = menu.paper.holes.size()
	var center: Vector2 = menu.buttons[1].get_global_rect().get_center()
	await click(center)
	await frames(24)
	check(menu.paper_transition.active, "Credits uses new sheet drawn over the old page instead of a fade")
	await shot("credits-paper-stack")
	await frames(82)
	check(menu.credits_open and menu.credits.visible and not c.enabled, "native Credits hit target opens credits and stops companion")
	check(not menu.paper.visible, "credits do not show mouse tears behind text")
	await frames(340)
	check(menu.paper.holes.size() == retained, "no gnaw or extra holes during credits")
	await shot("credits-final-1920x1080")
	menu.credits.back.pressed.emit()
	await frames(105)
	check(not menu.credits_open and c.enabled and menu.paper.visible, "Return restores menu, companion and current tears")
	check(menu.paper.holes.size() == retained, "existing tears persist on returning from credits")
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
	await pointer(Vector2(280,700))
	await frames(60)
	var last: int = c.pose_frame
	var updates := 0
	var held := 0
	var travelled := 0.0
	var prior: Vector2 = c.sprite.global_position
	var safe := true
	for i in 60:
		await frames(1)
		if c.pose_frame != last:
			updates += 1
			last = c.pose_frame
		travelled += c.sprite.global_position.distance_to(prior)
		if c.sprite.global_position.distance_to(prior) < 0.001: held += 1
		prior = c.sprite.global_position
		safe = safe and c.display_is_safe()
	check(updates >= 9 and updates <= 11,"companion shows ten held animation poses per second")
	check(held >= 40,"drawing holds between frames instead of sliding every rendered frame")
	check(travelled > 20.0,"rendered mouse actually follows the pointer rather than remaining frozen")
	check(safe,"body and tail stay inside paper and outside protected lettering")
	await shot("cartoon-mouse-follow")
