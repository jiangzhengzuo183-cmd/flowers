extends Control
## DAY 01 六段流程，使用项目中的场景和 UI 素材。
signal enter_maze
signal return_to_story
signal continue_chapter

const Flow := preload("res://modules/visual_novel/scripts/story/bakery_flow.gd")
const Day01View := preload("res://modules/visual_novel/scripts/story/day01_scene_view.gd")
const NOTE_PATH := "user://bakery-notebook.txt"
const ReportBook := preload("res://modules/visual_novel/scripts/story/report_book.gd")
const ReportCatalog := preload("res://modules/visual_novel/scripts/story/report_book_catalog.gd")
var report_book: Control
const DAY := preload("res://modules/visual_novel/assets/bakery/interior.png")
const NIGHT := preload("res://modules/visual_novel/assets/bakery/interior-night.png")
const OUTSIDE := preload("res://modules/visual_novel/assets/bakery/exterior.png")
var flow := Flow.new()
var note_path := NOTE_PATH
var title: Label
var location: Label
var task: Label
var stage: Control
var backdrop: TextureRect
var shade: ColorRect
var narrator: Label
var charlie: TextureRect
var cast_layer: Control
var people_row: Control
var person_buttons: Dictionary = {}
var portrait_buttons: Dictionary = {}
var person_statuses: Dictionary = {}
var object_buttons: Dictionary = {}
var speaker: Label
var dialogue_text: Label
var progress: Label
var paper: PanelContainer
var dialogue_panel: Control
var next_button: Button
var continue_button: Button
var maze_button: Button
var history_window: AcceptDialog
var history_text: RichTextLabel
var notebook_window: ConfirmationDialog
var notebook_editor: TextEdit
var notebook_feedback: Label
var transition_tween: Tween
var last_section := ""
var runtime: Control
var day01_view: RefCounted

func _ready() -> void:
	if not flow.error.is_empty():
		add_child(_label(flow.error))
		return
	if "--preview-school" in OS.get_cmdline_user_args() and not Engine.has_meta("day01_school_preview_used"):
		Engine.set_meta("day01_school_preview_used", true)
		flow.history.clear()
		flow.section = "classroom"
		flow._begin(flow.data.school.intro)
	if "--preview-report1" in OS.get_cmdline_user_args() and not Engine.has_meta("day01_report_preview_used"):
		Engine.set_meta("day01_report_preview_used",true)
		flow.section = "home"
		flow._begin(flow.data.home)
	if FileAccess.file_exists(note_path):
		flow.notebook_text = FileAccess.get_file_as_string(note_path)
	_build_ui()
	_refresh()
	next_button.grab_focus()

func _label(value: String, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	return label

func open_report_book(id: String, review: bool, on_finished: Callable) -> bool:
	if is_instance_valid(report_book): return true
	var book := ReportBook.new()
	book.name = "ProgressReportBook"
	book.request = ReportCatalog.request(self,id,review)
	book.z_index = 150
	report_book = book
	book.finished.connect(func(status: String) -> void:
		if report_book != book: return
		report_book = null
		book.queue_free()
		on_finished.call(status))
	add_child(book)
	return true

func show_report_text_fallback(id: String, on_finished: Callable) -> void:
	# A failed web asset must not fall back to a composite containing future dates.
	var source: Dictionary
	if id == "report1": source = {"title":flow.data.report_title,"date":flow.data.report_date,"text":flow.data.report}
	else: source = get("narrative").data.reports[id]
	var popup := AcceptDialog.new()
	_style_dialog(popup)
	popup.title = str(source.title)+" · "+str(source.date)
	popup.ok_button_text = "继续"
	popup.exclusive = true
	var text := RichTextLabel.new()
	text.custom_minimum_size = Vector2(800,520)
	text.add_theme_font_override("normal_font",preload("res://modules/visual_novel/assets/fonts/YeLiHangJiuLinKaTong.ttf"))
	text.add_theme_font_size_override("normal_font_size",26)
	text.add_theme_color_override("default_color",Color("493f30"))
	text.text = str(source.text).replace("\\n","\n")
	popup.add_child(text)
	add_child(popup)
	popup.confirmed.connect(func() -> void: popup.hide();popup.queue_free();on_finished.call("completed"))
	popup.canceled.connect(func() -> void: popup.popup_centered.call_deferred())
	popup.popup_centered_ratio(0.85)

func _button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.pressed.connect(callback)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("f7d487")
	normal.border_color = Color("927452")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("ffe9b1")
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("c3a16b")
	button.add_theme_stylebox_override("pressed", pressed)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("34464b"))
	return button

func _build_ui() -> void:
	clip_contents = true
	stage = Control.new()
	stage.name = "Stage"
	add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.clip_contents = true
	backdrop = TextureRect.new()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade = ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	narrator = _label("", 30)
	narrator.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narrator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	narrator.add_theme_color_override("font_color", Color("f5eedc"))
	stage.add_child(narrator)
	narrator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	narrator.offset_left = 150
	narrator.offset_right = -150
	narrator.offset_bottom = -110
	cast_layer = Control.new()
	cast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_layer.clip_contents = true
	stage.add_child(cast_layer)
	cast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cast_layer.offset_bottom = -22
	charlie = TextureRect.new()
	charlie.texture = preload("res://modules/visual_novel/assets/bakery/charlie-reference.webp")
	charlie.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	charlie.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	charlie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_layer.add_child(charlie)
	people_row = Control.new()
	people_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_layer.add_child(people_row)
	people_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var textures := {
		"gimpy": preload("res://modules/visual_novel/assets/bakery/gimpy-reference.webp"),
		"donner": preload("res://modules/visual_novel/assets/bakery/donner-reference.webp"),
		"karp": load("res://modules/visual_novel/assets/bakery/karp-cutout.png") if ResourceLoader.exists("res://modules/visual_novel/assets/bakery/karp-cutout.png") else load("res://modules/visual_novel/assets/bakery/karp.png")
	}
	for person: Dictionary in flow.people:
		var id: String = person.id
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		people_row.add_child(slot)
		slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var portrait := TextureButton.new()
		portrait.texture_normal = textures[id]
		portrait.ignore_texture_size = true
		portrait.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		portrait.focus_mode = Control.FOCUS_NONE
		portrait.tooltip_text = "与%s交谈" % person.name
		var mask := BitMap.new()
		mask.create_from_image_alpha(portrait.texture_normal.get_image(), 0.2)
		portrait.texture_click_mask = mask
		portrait.pressed.connect(start_talk.bind(id))
		slot.add_child(portrait)
		portrait_buttons[id] = portrait
		var name_button := _button(person.name, start_talk.bind(id))
		slot.add_child(name_button)
		person_buttons[id] = name_button
		var status := _label("", 14)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.add_theme_color_override("font_color", Color("fff4dc"))
		status.add_theme_color_override("font_shadow_color", Color("263b31"))
		status.add_theme_constant_override("shadow_offset_y", 2)
		slot.add_child(status)
		person_statuses[id] = status
	var positions := {"bread": Vector2(0.10, 0.59), "orders": Vector2(0.73, 0.56), "notebook": Vector2(0.51, 0.66)}
	for id: String in positions:
		var button := _button(str(flow.data.objects[id].name) + "  ◇", start_object.bind(id))
		stage.add_child(button)
		button.position = positions[id] * Vector2(1600, 900)
		object_buttons[id] = button
	var header_tint := ColorRect.new()
	header_tint.visible = false
	header_tint.color = Color(0.07, 0.19, 0.23, 0.35)
	header_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(header_tint)
	header_tint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header_tint.offset_bottom = 82
	var header := HBoxContainer.new()
	stage.add_child(header)
	header.position = Vector2(64, 22)
	header.size = Vector2(1472, 46)
	header.add_theme_constant_override("separation", 22)
	var brand := _label("献给阿尔吉侬的花束", 23)
	brand.add_theme_color_override("font_color", Color("fff8e9"))
	header.add_child(brand)
	title = _label("第一章 · 面包店", 15)
	title.add_theme_color_override("font_color", Color("fff0d2"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_header_button("对话记录", _show_history))
	header.add_child(_header_button("操作帮助", _show_help))
	header.add_child(_header_button("从头阅读", _confirm_restart))
	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("f7d487")
	badge_style.border_color = Color("e6bd72")
	badge_style.border_width_left = 2
	badge_style.content_margin_left = 16
	badge_style.content_margin_right = 16
	badge_style.content_margin_top = 7
	badge_style.content_margin_bottom = 7
	badge.add_theme_stylebox_override("panel", badge_style)
	stage.add_child(badge)
	badge.position = Vector2(64, 30)
	location = _label("", 15)
	location.add_theme_color_override("font_color", Color("34464b"))
	badge.add_child(location)
	task = _label("", 15)
	task.position = Vector2(64, 144)
	task.size.x = 650
	task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task.add_theme_color_override("font_color", Color("fff3d8"))
	task.add_theme_color_override("font_shadow_color", Color("263b31"))
	task.add_theme_constant_override("shadow_offset_y", 2)
	stage.add_child(task)
	dialogue_panel = Control.new()
	stage.add_child(dialogue_panel)
	dialogue_panel.position = Vector2(140, 678)
	dialogue_panel.size = Vector2(1320, 200)
	paper = PanelContainer.new()
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color(1, 0.973, 0.918, 0.97)
	surface.border_color = Color("d9b576")
	surface.border_width_top = 3
	surface.set_corner_radius_all(4)
	surface.shadow_color = Color(0.05, 0.12, 0.18, 0.22)
	surface.shadow_size = 15
	paper.add_theme_stylebox_override("panel", surface)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := MarginContainer.new()
	dialogue_panel.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 30)
	content.add_theme_constant_override("margin_right", 30)
	content.add_theme_constant_override("margin_top", 16)
	content.add_theme_constant_override("margin_bottom", 14)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	content.add_child(box)
	var meta := HBoxContainer.new()
	box.add_child(meta)
	speaker = _label("查理", 21)
	speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(speaker)
	progress = _label("", 13)
	meta.add_child(progress)
	dialogue_text = _label("", 22)
	dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.add_theme_constant_override("line_spacing", 2)
	box.add_child(dialogue_text)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(actions)
	next_button = _button("继续  ≫", _on_next_pressed)
	actions.add_child(next_button)
	continue_button = _button("开始工作物件探索  ≫", continue_main)
	actions.add_child(continue_button)
	maze_button = _button("体验现有迷宫  ↗", func() -> void: enter_maze.emit())
	actions.add_child(maze_button)
	_build_dialogs()
	day01_view = Day01View.new(self)
	day01_view.build()
	runtime = load("res://modules/visual_novel/scripts/story/experience_runtime.gd").new()
	runtime.host = self
	add_child(runtime)

func _header_button(value: String, callback: Callable) -> Button:
	var button := _button(value, callback)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.22, 0.26, 0.5)
	style.border_color = Color(1, 0.96, 0.86, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(24)
	style.content_margin_left = 18
	style.content_margin_right = 18
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("fff8e9"))
	return button

func _place_portraits() -> void:
	# 相同的近景与固定坐标不受台词长度、其他人物是否离场影响。
	var close_height := 1760.0
	var close_width := close_height * charlie.texture.get_width() / charlie.texture.get_height()
	charlie.position = Vector2((1600.0 - close_width) / 2.0, 88)
	charlie.size = Vector2(close_width, close_height)
	var centers := {"gimpy": 320.0, "karp": 800.0, "donner": 1280.0}
	for id: String in portrait_buttons:
		var portrait: TextureButton = portrait_buttons[id]
		var selecting := flow.phase == "people"
		var height := 1120.0 if selecting else close_height
		var width := height * portrait.texture_normal.get_width() / portrait.texture_normal.get_height()
		var center: float = centers[id] if selecting else 800.0
		portrait.position = Vector2(center - width / 2.0, 110 if selecting else 88)
		portrait.size = Vector2(width, height)
		person_buttons[id].position = Vector2(centers[id] - 90, 578)
		person_buttons[id].size = Vector2(180, 46)
		person_statuses[id].position = Vector2(centers[id] - 160, 632)
		person_statuses[id].size = Vector2(320, 25)

func _show_help() -> void:
	var dialog := AcceptDialog.new()
	_style_dialog(dialog)
	dialog.title = "操作帮助"
	dialog.dialog_text = "点击继续，逐句阅读。\n面包店中点击画里的吉姆皮、卡普尔或唐纳店长交谈。\n工作台上可以查看面包架、订单和笔记本。\n到夜校后，点击黑板前的爱丽丝老师。\nDAY 01 结尾可以阅读进步抱告—1。\n可选探索可以跳过；笔记本可查看原有剧情。"
	dialog.ok_button_text = "知道了"
	dialog.exclusive = true
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _build_dialogs() -> void:
	history_window = AcceptDialog.new()
	_style_dialog(history_window)
	history_window.title = "查理的记录 · 已读对话"
	history_window.exclusive = true
	history_window.ok_button_text = "返回场景"
	add_child(history_window)
	history_text = RichTextLabel.new()
	history_text.add_theme_color_override("default_color", Color("34464b"))
	history_text.selection_enabled = true
	history_text.custom_minimum_size = Vector2(400, 260)
	history_window.add_child(history_text)

func _style_dialog(dialog: AcceptDialog) -> void:
	dialog.theme = theme
	dialog.borderless = true
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("faf2df")
	surface.border_color = Color("b49b72")
	surface.set_border_width_all(2)
	surface.content_margin_left = 18
	surface.content_margin_right = 18
	surface.content_margin_top = 14
	surface.content_margin_bottom = 14
	dialog.add_theme_stylebox_override("panel", surface)
	dialog.get_ok_button().add_theme_color_override("font_focus_color", Color("34464b"))
	if dialog is ConfirmationDialog:
		dialog.get_cancel_button().add_theme_color_override("font_focus_color", Color("34464b"))

func start_talk(id: String) -> void:
	if flow.start_talk(id):
		_refresh()
		next_button.grab_focus()

func start_object(id: String) -> void:
	if flow.start_object(id):
		_refresh()
		next_button.grab_focus()

func advance() -> void:
	if is_instance_valid(runtime) and runtime.busy: return
	if day01_view.has_modal():
		return
	if flow.phase == "report":
		day01_view.report_page.request_continue()
		return
	if flow.phase == "lesson":
		day01_view.finish_lesson()
		return
	if day01_view.establishing:
		day01_view.establishing = false
	flow.advance()
	_refresh()
	if flow.phase == "people":
		for id: String in person_buttons:
			if not person_buttons[id].disabled:
				person_buttons[id].grab_focus()
				break
	elif flow.phase == "objects":
		object_buttons.bread.grab_focus()
	elif flow.phase == "complete":
		# The new report book opens automatically; the legacy end-screen button may not exist.
		if is_instance_valid(day01_view.report_button) and day01_view.report_button.is_visible_in_tree():
			day01_view.report_button.grab_focus()
	elif flow.phase == "school":
		day01_view.alice_hotspot.grab_focus()

func continue_main() -> void:
	if flow.continue_main():
		_refresh()
		if flow.phase == "objects":
			object_buttons.bread.grab_focus()
		else:
			next_button.grab_focus()

func _refresh() -> void:
	_place_portraits()
	var line := flow.current_line()
	speaker.text = line.speaker
	dialogue_text.text = line.text
	var opening := flow.section == "opening"
	speaker.add_theme_color_override("font_color", Color("fff8e9") if opening else Color("243f48"))
	progress.add_theme_color_override("font_color", Color("fff0d2") if opening else Color("7c8178"))
	var outside := flow.section in ["exterior", "leaving", "complete"]
	var night := flow.section in ["closing", "leaving", "complete"]
	backdrop.texture = OUTSIDE if outside else (NIGHT if night else DAY)
	backdrop.visible = not opening
	backdrop.modulate = Color(0.43, 0.48, 0.66) if outside and night else Color.WHITE
	var shade_target := Color("0c0e12") if opening else Color(0.06, 0.07, 0.12, 0.3 if night else 0.1)
	if last_section != flow.section:
		if transition_tween:
			transition_tween.kill()
		if last_section.is_empty() or opening:
			shade.color = shade_target
		else:
			shade.color = Color(0.02, 0.025, 0.04, 0.85)
			transition_tween = create_tween()
			transition_tween.tween_property(shade, "color", shade_target, 0.8)
		last_section = flow.section
	narrator.visible = opening
	narrator.text = line.text
	charlie.visible = str(line.speaker).begins_with("查理") and not opening and not outside and flow.phase == "reading"
	dialogue_text.visible = not opening
	paper.visible = not opening
	location.text = "面包店外 · 夜" if outside and night else "面包店外 · 日" if outside else "面包店室内 · 夜" if night else "面包店室内 · 日"
	if opening:
		location.text = "查理的进步报告 / 开篇"
	var segment_number := 1
	var segment_name := "掉落的面包卷"
	if flow.section in ["intro", "people"]:
		segment_number = 2
		segment_name = "面包店 · 人物互动"
	elif flow.section == "objects":
		segment_number = 3
		segment_name = "面包店 · 工作物件探索"
	elif night:
		segment_number = 4
		segment_name = "夜晚 · 打烊下班"
	title.text = "%02d / %s" % [segment_number, segment_name]
	people_row.visible = flow.section == "people" or flow.active_person != "" or (flow.phase == "reading" and flow.section in ["objects", "closing"])
	for person: Dictionary in flow.people:
		var id: String = person.id
		var selecting := flow.phase == "people"
		var gone := flow.departed(id)
		var speaking: bool = line.speaker == person.name
		var column := person_buttons[id].get_parent() as Control
		column.visible = selecting or speaking
		person_buttons[id].disabled = not selecting or gone
		portrait_buttons[id].disabled = not selecting or gone
		portrait_buttons[id].focus_mode = Control.FOCUS_NONE
		portrait_buttons[id].modulate.a = 0.0 if selecting and gone else 1.0
		person_buttons[id].visible = selecting
		person_statuses[id].visible = selecting
		person_statuses[id].text = "已离开" if gone else "已交谈 · 可重读" if id in flow.completed_people else "点击人物交谈"
	for id: String in object_buttons:
		object_buttons[id].visible = flow.phase == "objects"
		object_buttons[id].text = str(flow.data.objects[id].name) + ("  ✓" if id in flow.completed_objects else "  ◇")
	next_button.visible = flow.phase in ["reading", "complete"]
	next_button.disabled = not flow.error.is_empty()
	next_button.text = "从头阅读  ↺" if flow.phase == "complete" else "继续  ≫"
	if flow.phase == "reading" and flow.index == flow.queue.size() - 1:
		next_button.text = {"opening": "走向面包店  ≫", "exterior": "进入面包店  ≫", "intro": "自由交谈  ≫", "people": "结束对话  ≫", "objects": "继续  ≫" if flow.return_phase == "notebook" else "返回工作台  ≫", "closing": "离开面包店  ≫", "leaving": "结束本段  ≫"}.get(flow.section, "继续  ≫")
		if flow.section == "leaving": next_button.text = "前往夜校  ≫"
		elif flow.section == "classroom": next_button.text = "和老师打招呼  ≫"
		elif flow.section == "alice": next_button.text = "课后独白  ≫"
		elif flow.section == "home": next_button.text = "结束 DAY 01  ≫"
	continue_button.visible = flow.phase in ["people", "objects"]
	continue_button.text = "开始工作物件探索  ≫" if flow.phase == "people" else "收拾完毕 · 打烊  ≫"
	maze_button.hide()
	progress.text = "%d / %d" % [flow.index + 1, flow.queue.size()] if flow.phase == "reading" else "已交谈 %d / 3" % flow.completed_people.size() if flow.phase == "people" else "已查看 %d / 3" % flow.completed_objects.size() if flow.phase == "objects" else ""
	task.text = "点击人物立绘或姓名交谈；可选探索不影响主线。" if flow.phase == "people" else "点击面包架、订单或笔记本；也可以直接进入打烊。" if flow.phase == "objects" else "面包店段落已完成；笔记本中保存的文字会保留。" if flow.phase == "complete" else "点击“继续”逐句阅读。"
	task.visible = flow.phase in ["objects", "complete"]
	day01_view.refresh()
	if OS.has_feature("web") and "--report-qa" in OS.get_cmdline_user_args():
		JavaScriptBridge.get_interface("window").flowerReportQA = JSON.stringify({"node":"day01","section":flow.section,"phase":flow.phase,"history":flow.history.size(),"report_opened":flow.report_opened,"report_completed":flow.report_completed,"page_visible":is_instance_valid(day01_view.report_page) and day01_view.report_page.visible})

func _process(delta: float) -> void:
	if day01_view: day01_view.tick(delta)

func _show_history() -> void:
	var entries: PackedStringArray = []
	var state: RefCounted = runtime.model() if is_instance_valid(runtime) else flow
	for line: Dictionary in state.history:
		entries.append("【%s】%s：\n%s" % [line.get("scene",""),line.speaker, line.text])
	history_text.text = "\n\n".join(entries)
	history_text.scroll_to_line(history_text.get_line_count()-1)
	history_window.popup_centered_ratio(0.75)

func _confirm_restart() -> void:
	var dialog := ConfirmationDialog.new()
	_style_dialog(dialog)
	dialog.title = "从头阅读"
	dialog.exclusive = true
	dialog.dialog_text = "重新开始 DAY 01？\n已经保存的笔记本内容会保留。"
	dialog.ok_button_text = "从头阅读"
	dialog.cancel_button_text = "继续当前进度"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		return_to_story.emit()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _on_next_pressed() -> void:
	if flow.phase == "reading" and is_instance_valid(runtime):
		runtime.request_advance()
		return
	if flow.phase == "complete":
		_confirm_restart()
	else:
		advance()
