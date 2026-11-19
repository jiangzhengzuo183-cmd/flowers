extends RefCounted
## 夜校、课堂演出、回家与章节结尾；同样使用1600×900设计坐标。
const Hotspot := preload("res://modules/visual_novel/scripts/story/scene_hotspot.gd")
const EXPLORE := preload("res://modules/visual_novel/assets/experience/bakery-explore.png")
const Hot := preload("res://modules/visual_novel/scripts/story/scene_hotspot.gd")
var object_hotspots: Dictionary = {}
var detail_image: TextureRect
const PEOPLE := preload("res://modules/visual_novel/assets/bakery/people-scene.png")
const SCHOOL := preload("res://modules/visual_novel/assets/bakery/school-scene.png")
const SCHOOL_EMPTY := preload("res://modules/visual_novel/assets/bakery/school-empty.png")
const STREET := preload("res://modules/visual_novel/assets/bakery/street-night.png")
const ALICE := preload("res://modules/visual_novel/assets/bakery/alice-new.png")
const DialogueCast := preload("res://modules/visual_novel/scripts/story/dialogue_cast.gd")
const REPORT_SCENE := preload("res://modules/visual_novel/scenes/report1.tscn")
var dialogue_cast: RefCounted

var host: Control
var people_hotspots: Dictionary = {}
var alice_hotspot: Button
var interaction_layer: Control
var alice_portrait: TextureRect
var departed_cast: Control
var interact_hint: TextureRect
var lesson_words: Label
var lesson_button: Button
var lesson_timer: Timer
var lesson_tween: Tween
var lesson_playing := false
var establishing := false
var previous_section := ""
var walker: AnimatedSprite2D
var walk_time := 0.0
var end_overlay: Control
var end_tween: Tween
var report_window: AcceptDialog
var report_text: RichTextLabel
var report_button: Button
var report_page: Control
var hover_panel: PanelContainer
var hover_text: Label
var hover_target: Button
var hover_tween: Tween
var hover_generation := 0
var separated_people: Dictionary = {}
var name_tag: PanelContainer
var paper_back: PanelContainer
var paper_grain: TextureRect
var paper_inner: PanelContainer

func _init(owner: Control) -> void:
	host = owner

func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas

func _add_hotspot(vertices: PackedVector2Array, label: String, action: Callable) -> Button:
	var hotspot := Hotspot.new()
	hotspot.configure(vertices, label)
	hotspot.pressed.connect(action)
	hotspot.hint_changed.connect(_on_hint_changed.bind(hotspot))
	interaction_layer.add_child(hotspot)
	return hotspot

func _texture(texture: Texture2D, parent: Control, rect: Rect2) -> TextureRect:
	var item := TextureRect.new()
	item.texture = texture
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	item.position = rect.position
	item.size = rect.size
	return item

func build() -> void:
	interaction_layer = Control.new()
	interaction_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.stage.add_child(interaction_layer)
	interaction_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	people_hotspots.karp = _add_hotspot(PackedVector2Array([Vector2(382,272),Vector2(478,277),Vector2(496,342),Vector2(450,401),Vector2(447,492),Vector2(422,567),Vector2(443,668),Vector2(414,775),Vector2(453,812),Vector2(445,839),Vector2(258,839),Vector2(257,788),Vector2(292,701),Vector2(276,586),Vector2(271,493),Vector2(258,440),Vector2(284,377),Vector2(350,343),Vector2(363,290)]), "卡普尔 · 交谈", host.start_talk.bind("karp"))
	people_hotspots.donner = _add_hotspot(PackedVector2Array([Vector2(834,272),Vector2(930,270),Vector2(954,310),Vector2(960,337),Vector2(1030,375),Vector2(1067,423),Vector2(1041,458),Vector2(989,458),Vector2(977,568),Vector2(1002,652),Vector2(990,704),Vector2(838,704),Vector2(833,663),Vector2(811,570),Vector2(821,468),Vector2(778,452),Vector2(760,421),Vector2(778,388),Vector2(813,358),Vector2(806,318)]), "唐纳店长 · 交谈", host.start_talk.bind("donner"))
	people_hotspots.gimpy = _add_hotspot(PackedVector2Array([Vector2(1162,246),Vector2(1248,246),Vector2(1268,278),Vector2(1263,326),Vector2(1254,345),Vector2(1265,385),Vector2(1335,418),Vector2(1372,463),Vector2(1324,504),Vector2(1270,518),Vector2(1272,594),Vector2(1245,675),Vector2(1258,751),Vector2(1320,788),Vector2(1327,829),Vector2(1251,841),Vector2(1168,824),Vector2(1095,838),Vector2(1080,815),Vector2(1089,758),Vector2(1100,680),Vector2(1117,608),Vector2(1105,536),Vector2(1110,486),Vector2(1097,435),Vector2(1109,379),Vector2(1139,341)]), "吉姆皮 · 交谈", host.start_talk.bind("gimpy"))
	alice_hotspot = _add_hotspot(PackedVector2Array([Vector2(1090,305),Vector2(1155,305),Vector2(1180,342),Vector2(1173,385),Vector2(1205,410),Vector2(1212,491),Vector2(1190,533),Vector2(1215,730),Vector2(1205,830),Vector2(1170,841),Vector2(1147,815),Vector2(1106,839),Vector2(1008,834),Vector2(1000,812),Vector2(1055,750),Vector2(1075,551),Vector2(1065,493),Vector2(1010,465),Vector2(997,438),Vector2(1035,428),Vector2(1072,451),Vector2(1093,400),Vector2(1070,365)]), "爱丽丝老师 · 交谈", start_alice)
	interact_hint = _texture(_atlas(preload("res://modules/visual_novel/assets/bakery/ui-interact.png"), Rect2(45,925,870,280)), interaction_layer, Rect2(64,815,190,62))
	interact_hint.hide()
	departed_cast = Control.new()
	departed_cast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.cast_layer.add_child(departed_cast)
	_texture(preload("res://modules/visual_novel/assets/bakery/charlie-scene.png"), departed_cast, Rect2(430,244,350,650))
	separated_people.donner = _texture(preload("res://modules/visual_novel/assets/bakery/donner-scene.png"), departed_cast, Rect2(735,260,350,460))
	separated_people.gimpy = _texture(preload("res://modules/visual_novel/assets/bakery/gimpy-scene.png"), departed_cast, Rect2(1010,240,430,620))
	lesson_words = host._label("work    工作\n\nlearn    学习\n\nremember    记住", 24)
	lesson_words.add_theme_color_override("font_color", Color("f4e8bd"))
	host.stage.add_child(lesson_words)
	lesson_words.position = Vector2(950,350)
	lesson_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alice_portrait = _texture(ALICE, host.cast_layer, Rect2(360,88,880,1760))
	lesson_button = host._button("下课后  →", finish_lesson)
	host.stage.add_child(lesson_button)
	lesson_button.position = Vector2(1300,820)
	lesson_button.size = Vector2(236,54)
	lesson_timer = Timer.new()
	lesson_timer.one_shot = true
	lesson_timer.timeout.connect(_lesson_timeout)
	host.add_child(lesson_timer)
	_build_objects()
	_build_walker()
	_build_end()
	_apply_ui_assets()
	_build_hover_hint()
	dialogue_cast = DialogueCast.new(host)
	dialogue_cast.build()

func _build_walker() -> void:
	walker = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	var strip: Texture2D = preload("res://modules/visual_novel/assets/bakery/charlie-walk.png")
	for index in range(4):
		frames.add_frame("default", _atlas(strip, Rect2(index * strip.get_width() / 4.0, 0, strip.get_width() / 4.0, strip.get_height())))
	frames.set_animation_speed("default", 5.0)
	walker.sprite_frames = frames
	walker.scale = Vector2.ONE * (145.0 / strip.get_height())
	walker.position = Vector2(340,628)
	host.stage.add_child(walker)

func _build_end() -> void:
	end_overlay = Control.new()
	host.stage.add_child(end_overlay)
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color("090b0e")
	end_overlay.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	stack.position = Vector2(300,170)
	stack.size = Vector2(1000,440)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 24)
	end_overlay.add_child(stack)
	for entry: Array in [["CHAPTER 01",18],["DAY 01",28],["面包店的灯",58],["一个新的机会，正在等待着他。",22],["END OF DAY 01",16]]:
		var label: Label = host._label(entry[0], entry[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("f5e7c9"))
		stack.add_child(label)
	var actions := HBoxContainer.new()
	end_overlay.add_child(actions)
	actions.position = Vector2(350,680)
	actions.size = Vector2(900,60)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	report_button = host._button("继续 · 阅读进步抱告—1  ≫", show_report)
	actions.add_child(report_button)
	actions.add_child(host._button("从头体验", host._confirm_restart))
	host.maze_button.reparent(actions)
	report_window = AcceptDialog.new()
	host._style_dialog(report_window)
	report_window.title = "进步抱告—1 · 3月3日"
	report_window.ok_button_text = "合上报告"
	report_window.exclusive = true
	host.add_child(report_window)
	var pink := StyleBoxFlat.new()
	pink.bg_color = Color("faf2df")
	pink.content_margin_left = 36
	pink.content_margin_right = 36
	pink.content_margin_top = 28
	pink.content_margin_bottom = 20
	report_window.add_theme_stylebox_override("panel", pink)
	report_text = RichTextLabel.new()
	# Scope the handwriting to report content; dialog chrome and buttons keep the sans theme.
	report_text.add_theme_font_override("normal_font", preload("res://modules/visual_novel/assets/fonts/YeLiHangJiuLinKaTong.ttf"))
	report_text.custom_minimum_size = Vector2(660,480)
	report_text.add_theme_font_size_override("normal_font_size", 24)
	report_text.add_theme_color_override("default_color", Color("30232c"))
	report_text.add_theme_constant_override("normal_line_separation", 8)
	report_text.selection_enabled = true
	report_window.add_child(report_text)
	report_page = REPORT_SCENE.instantiate()
	report_page.name = "Report1Page"
	report_page.z_index = 50
	host.add_child(report_page)
	report_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	report_page.hide()
	report_page.continued.connect(_finish_report)

func _apply_ui_assets() -> void:
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("fff5e8")
	surface.border_color = Color("bea17a")
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(20)
	surface.shadow_color = Color(0.14,0.12,0.08,0.22)
	surface.shadow_offset = Vector2(0,3)
	surface.shadow_size = 9
	host.paper.add_theme_stylebox_override("panel", surface)
	paper_back = PanelContainer.new()
	var back_style: StyleBoxFlat = surface.duplicate()
	back_style.bg_color = Color("efc973")
	back_style.border_color = Color("c6a15d")
	back_style.shadow_size = 3
	paper_back.add_theme_stylebox_override("panel",back_style)
	paper_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.dialogue_panel.add_child(paper_back)
	host.dialogue_panel.move_child(paper_back,0)
	paper_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper_back.offset_left = 14
	paper_back.offset_right = 14
	paper_back.offset_top = 12
	paper_back.offset_bottom = 12
	paper_grain = _texture(_atlas(preload("res://modules/visual_novel/assets/bakery/paper-panel.png"),Rect2(250,230,900,560)),host.dialogue_panel,Rect2())
	host.dialogue_panel.move_child(paper_grain,2)
	paper_grain.stretch_mode = TextureRect.STRETCH_SCALE
	paper_grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper_grain.offset_left = 18
	paper_grain.offset_right = -18
	paper_grain.offset_top = 18
	paper_grain.offset_bottom = -18
	paper_grain.modulate.a = 0.24
	paper_inner = PanelContainer.new()
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color.TRANSPARENT
	inner.border_color = Color("d5b88d")
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(15)
	paper_inner.add_theme_stylebox_override("panel",inner)
	paper_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.dialogue_panel.add_child(paper_inner)
	host.dialogue_panel.move_child(paper_inner,3)
	paper_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper_inner.offset_left = 9
	paper_inner.offset_right = -9
	paper_inner.offset_top = 9
	paper_inner.offset_bottom = -9
	host.dialogue_text.add_theme_font_size_override("font_size", 23)
	var content := host.dialogue_text.get_parent().get_parent() as MarginContainer
	content.add_theme_constant_override("margin_left", 72)
	content.add_theme_constant_override("margin_right", 42)
	content.add_theme_constant_override("margin_top", 52)
	content.add_theme_constant_override("margin_bottom", 18)
	name_tag = PanelContainer.new()
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = Color("f5d583")
	tag_style.border_color = Color("b59a6e")
	tag_style.set_border_width_all(1)
	tag_style.set_corner_radius_all(3)
	tag_style.content_margin_left = 38
	tag_style.content_margin_right = 24
	tag_style.content_margin_top = 10
	tag_style.content_margin_bottom = 12
	tag_style.shadow_color = Color(0.18,0.13,0.07,0.18)
	tag_style.shadow_size = 3
	tag_style.shadow_offset = Vector2(1,3)
	name_tag.add_theme_stylebox_override("panel",tag_style)
	name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.dialogue_panel.add_child(name_tag)
	name_tag.position = Vector2(100,-34)
	name_tag.rotation = deg_to_rad(-2.0)
	name_tag.z_index = 1
	name_tag.clip_contents = false
	host.speaker.reparent(name_tag)
	host.speaker.add_theme_font_size_override("font_size",24)
	# 长尾夹跨住纸签左缘和纸张上沿，与纸签共用对话框坐标，不参与容器排版。
	host.dialogue_panel.clip_contents = false
	# PNG 已自带倾斜角度，整张等比缩小，保留透明留白，不再叠加旋转。
	var clip_texture: Texture2D = preload("res://modules/visual_novel/assets/bakery/ui-binder-clip.png")
	var clip_size := Vector2(96,96.0 * clip_texture.get_height() / clip_texture.get_width())
	var clip := _texture(clip_texture,host.dialogue_panel,Rect2(Vector2(70,-42),clip_size))
	clip.z_index = 2
	clip.set_meta("paperclip",true)
	host.progress.reparent(host.dialogue_panel)
	host.progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	host.progress.add_theme_font_size_override("font_size",18)
	host.continue_button.reparent(host.stage)
	host.continue_button.position = Vector2(1260,812)
	host.continue_button.size = Vector2(276,58)

func _skin_next() -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f5d17f") if state == "normal" else Color("ffe0a0") if state == "hover" else Color("e5bb69")
		style.border_color = Color("9e825b")
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		style.shadow_color = Color(0.2,0.15,0.08,0.15)
		style.shadow_offset = Vector2(1,3)
		style.shadow_size = 3
		host.next_button.add_theme_stylebox_override(state, style)
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		host.next_button.add_theme_color_override(color, Color("34464b"))
	host.next_button.add_theme_font_size_override("font_size",23)
	host.next_button.custom_minimum_size = Vector2(182,58)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("917653")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(12)
	host.next_button.add_theme_stylebox_override("focus",focus)

func _layout_reference_dialogue() -> void:
	# 纸张底边固定；长台词向上扩展，姓名和页码独立于正文排版。
	var font: Font = host.dialogue_text.get_theme_font("font")
	var rows := 0
	for line: String in host.dialogue_text.text.split("\n"):
		rows += maxi(1, ceili(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,23).x / 1358.0))
	var height := 196.0 + maxi(0,rows-1) * 34.0
	host.dialogue_panel.size = Vector2(1472,height)
	host.dialogue_panel.position = Vector2(64,876-height)
	name_tag.reset_size()
	name_tag.position = Vector2(100,-34)
	host.progress.position = Vector2(1360,18)
	host.progress.size = Vector2(72,28)
	var decorated: bool = host.paper.visible
	for item: CanvasItem in [paper_back,paper_grain,paper_inner,name_tag]:
		item.visible = decorated
	for child: Node in host.dialogue_panel.get_children():
		if child.has_meta("paperclip"):
			child.visible = decorated
	if decorated:
		host.speaker.add_theme_color_override("font_color",Color("34464b"))
		host.progress.add_theme_color_override("font_color",Color("526369"))

func _build_hover_hint() -> void:
	hover_panel = PanelContainer.new()
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14,0.23,0.26,0.91)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	hover_panel.add_theme_stylebox_override("panel",style)
	hover_text = host._label("",18)
	hover_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_text.add_theme_color_override("font_color",Color("fff7e7"))
	hover_panel.add_child(hover_text)
	host.stage.add_child(hover_panel)
	hover_panel.hide()
	hover_panel.modulate.a = 0.0

func _hint_allowed(target: Button) -> bool:
	return is_instance_valid(target) and target.is_visible_in_tree() and not target.disabled and not target.hint_suppressed and host.flow.phase in ["people","school","objects"] and not has_modal()

func _on_hint_changed(active: bool, target: Button) -> void:
	if not is_instance_valid(hover_panel): return
	if active and _hint_allowed(target):
		_show_hint(target)
	elif target == hover_target:
		_hide_hint(not _hint_allowed(target))

func _show_hint(target: Button) -> void:
	if hover_tween: hover_tween.kill()
	hover_generation += 1
	_reset_brightness()
	hover_target = target
	hover_text.text = target.hint_text
	hover_panel.reset_size()
	hover_panel.show()
	_position_hint()
	# 只有离场后使用的独立透明 PNG 能轻微提亮；整幅插画保持原色。
	if departed_cast.visible:
		for id: String in separated_people:
			if people_hotspots[id] == target:
				separated_people[id].self_modulate = Color(1.04,1.04,1.04,1)
	hover_tween = host.create_tween()
	hover_tween.tween_property(hover_panel,"modulate:a",1.0,0.15)

func _reset_brightness() -> void:
	for actor: TextureRect in separated_people.values():
		actor.self_modulate = Color.WHITE

func _hide_hint(immediate: bool = false) -> void:
	if hover_tween: hover_tween.kill()
	hover_generation += 1
	hover_target = null
	_reset_brightness()
	if immediate:
		hover_panel.modulate.a = 0.0
		hover_panel.hide()
		return
	var generation := hover_generation
	hover_tween = host.create_tween()
	hover_tween.tween_property(hover_panel,"modulate:a",0.0,0.15)
	hover_tween.tween_callback(func() -> void:
		if hover_generation == generation and hover_target == null:
			hover_panel.hide())

func _position_hint() -> void:
	var actor_rect := hover_target.get_global_rect()
	var desired: Vector2 = actor_rect.position - host.stage.global_position + Vector2(actor_rect.size.x * 0.55 + 10,-hover_panel.size.y-12)
	hover_panel.position = Vector2(clampf(desired.x,16,host.stage.size.x-hover_panel.size.x-16),clampf(desired.y,16,host.stage.size.y-hover_panel.size.y-16))

func _sync_hover() -> void:
	if hover_target == null: return
	if not _hint_allowed(hover_target):
		_hide_hint(true)
	else:
		_position_hint()

func has_modal() -> bool:
	if is_instance_valid(host.get("designed_page")):return true
	for child: Node in host.get_children():
		if child is Window and child.visible:
			return true
	return false

func start_alice() -> void:
	if host.flow.start_alice():
		host._refresh()
		host.next_button.grab_focus()

func finish_lesson() -> void:
	if host.flow.finish_lesson():
		lesson_timer.stop()
		if lesson_tween: lesson_tween.kill()
		lesson_playing = false
		host._refresh()
		host.next_button.grab_focus()

func _lesson_timeout() -> void:
	if has_modal():
		lesson_timer.start(0.2)
	else:
		finish_lesson()

func refresh() -> void:
	var state: RefCounted = host.flow
	if state.phase == "report":
		host.stage.hide()
		if not report_page.visible: report_page.open()
		return
	report_page.hide()
	host.stage.show()
	detail_image.texture = preload("res://modules/visual_novel/assets/experience/orders.png") if state.active_object == "orders" else preload("res://modules/visual_novel/assets/experience/notebook.png") if state.active_object == "notebook" and state.return_phase == "notebook" else null
	detail_image.visible = state.phase == "reading" and detail_image.texture != null
	var reading: bool = state.phase == "reading"
	var choosing_people: bool = state.phase == "people"
	var choosing_teacher: bool = state.phase == "school"
	var school_scene: bool = state.section in ["classroom", "alice", "lesson"]
	var lesson: bool = state.phase == "lesson"
	var complete: bool = state.phase == "complete"
	interaction_layer.visible = choosing_people or choosing_teacher or state.phase == "objects"
	for id: String in object_hotspots:
		object_hotspots[id].visible = state.phase == "objects"
		object_hotspots[id].disabled = state.phase != "objects"
		object_hotspots[id].hint_text = ("✓ " if id in state.completed_objects else "")+host.flow.data.objects[id].name+" · 查看"
	if state.section == "objects": host.backdrop.texture = EXPLORE
	for b: Button in host.object_buttons.values(): b.hide()
	for id: String in people_hotspots:
		var button: Button = people_hotspots[id]
		button.visible = choosing_people
		button.disabled = not choosing_people or state.departed(id)
		button.hint_text = ("✓ " if id in state.completed_people else "") + host.flow.person(id).name + (" · 再次交谈" if id in state.completed_people else " · 交谈")
		button.tooltip_text = ""
	alice_hotspot.visible = choosing_teacher
	alice_hotspot.disabled = not choosing_teacher
	departed_cast.visible = choosing_people and state.departed("karp")
	if choosing_people:
		host.backdrop.texture = host.DAY if state.departed("karp") else PEOPLE
		host.people_row.visible = false
		host.charlie.visible = false
		host.task.visible = true
		host.task.text = "点击画面中的人物交谈。查理正在收拾打翻的面包卷。"
	if school_scene:
		host.backdrop.texture = SCHOOL_EMPTY
		host.backdrop.visible = true
		host.backdrop.modulate = Color.WHITE
		host.location.text = "夜校教室 · 夜"
		host.title.text = "05 / 夜校 · 爱丽丝老师"
		host.people_row.visible = false
		host.charlie.visible = reading and state.section == "alice" and str(state.current_line().speaker).begins_with("查理")
		host.task.visible = choosing_teacher
		host.task.text = "点击黑板前的爱丽丝老师，开始今晚的学习。"
		if choosing_teacher:
			host.continue_button.visible = false
	alice_portrait.visible = state.section == "alice" and state.current_line().speaker == "爱丽丝"
	alice_portrait.position = Vector2(140,88)
	alice_portrait.size = Vector2(1320,1760)
	if state.section == "classroom":
		alice_portrait.visible = false
		alice_portrait.position = Vector2(895,225)
		alice_portrait.size = Vector2(460,660)
	lesson_words.visible = lesson
	lesson_button.visible = lesson
	if lesson:
		alice_portrait.visible = true
		alice_portrait.position = Vector2(1060,215)
		alice_portrait.size = Vector2(460,660)
		host.charlie.visible = true
		host.charlie.position = Vector2(320,380)
		host.charlie.size = Vector2(440,650)
		if not lesson_playing:
			lesson_playing = true
			lesson_words.visible_characters = 0
			lesson_tween = host.create_tween()
			lesson_tween.tween_property(lesson_words,"visible_characters",lesson_words.text.length(),4.3)
			lesson_timer.start(5.5)
	if state.section == "home":
		host.backdrop.hide()
		if host.transition_tween: host.transition_tween.kill()
		host.shade.color = Color.BLACK
		host.narrator.show()
		host.narrator.text = state.current_line().text
		host.dialogue_text.hide()
		host.paper.hide()
		host.location.text = "夜晚街道 · 回家的路上"
		host.title.text = "06 / DAY 01 END"
		host.people_row.visible = false
		host.charlie.visible = false
		if previous_section != "home": walk_time = 0.0
	walker.hide()
	host.dialogue_panel.visible = not choosing_people and not choosing_teacher and not lesson and not complete
	end_overlay.visible = complete
	host.title.get_parent().visible = not complete
	host.location.get_parent().visible = not complete
	if complete: host.task.visible = false
	if complete and previous_section != "complete":
		end_overlay.modulate.a = 0.0
		end_tween = host.create_tween()
		end_tween.tween_property(end_overlay,"modulate:a",1.0,0.9)
	if state.section == "classroom" and previous_section != "classroom":
		establishing = true
		host.get_tree().create_timer(0.9).timeout.connect(_end_establishing)
	if establishing and state.section == "classroom": host.dialogue_panel.visible = false
	if state.section != "classroom": establishing = false
	_skin_next()
	_layout_reference_dialogue()
	_sync_hover()
	dialogue_cast.refresh()
	previous_section = state.section

func _end_establishing() -> void:
	if not is_instance_valid(host): return
	establishing = false
	if host.flow.section == "classroom": host._refresh()

func tick(_delta: float) -> void:
	_sync_hover()
	var modal := has_modal()
	lesson_timer.paused = modal
	if lesson_playing and lesson_tween and lesson_tween.is_valid():
		if modal: lesson_tween.pause()
		else: lesson_tween.play()
	walker.pause()

func show_report() -> void:
	if has_modal() or not host.flow.start_report(): return
	host._refresh()

func _finish_report() -> void:
	if host.runtime.debug_model!=null:
		host.runtime.restore()
		return
	if has_modal() or not host.flow.finish_report(): return
	report_page.hide()
	host.continue_chapter.emit()

func _build_objects() -> void:
	detail_image = _texture(null,host.stage,Rect2(650,150,300,460))
	var rectangles := {"bread":Rect2(110,470,590,230),"notebook":Rect2(940,505,110,70),"orders":Rect2(1195,410,105,145)}
	for id: String in rectangles:
		var r: Rect2 = rectangles[id]
		object_hotspots[id] = _add_hotspot(PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]),host.flow.data.objects[id].name+" · 查看",host.start_object.bind(id))
