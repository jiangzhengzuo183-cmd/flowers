extends "res://scripts/story/bakery_chapter.gd"
## 延续原纸张UI与双人控制器；后续状态独立，缺少背景保持空白。
const ContinuationFlow := preload("res://scripts/story/continuation_flow.gd")
const Race := preload("res://scripts/story/story_race.gd")
const Hotspot := preload("res://scripts/story/scene_hotspot.gd")
const NativeInk := preload("res://scripts/story/ink_observation.gd")
var ink_game: Control
var shown_report := ""
var detail_return: Button
var narrative := ContinuationFlow.new()
var items_box: VBoxContainer
var item_layer: Control
var item_image: TextureRect
var end_screen: PanelContainer
var end_label: Label
var chapter_button: Button
var race: Control
var utility_window: AcceptDialog
var utility_content: VBoxContainer
var machine_audio: AudioStreamPlayer
var lab_audio: AudioStreamPlayer
var loaded_scene := -1
var designed_page: Control
var room_machine: TextureRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	# 旧探索、演出、结尾不参与后续章节，只复用纸张UI和立绘层。
	for item: CanvasItem in [day01_view.interaction_layer,day01_view.alice_portrait,day01_view.departed_cast,day01_view.walker,day01_view.lesson_words,day01_view.lesson_button,day01_view.end_overlay]: item.hide()
	items_box = VBoxContainer.new()
	items_box.position = Vector2(64,190)
	items_box.size.x = 180
	items_box.add_theme_constant_override("separation",12)
	stage.add_child(items_box)
	item_layer = Control.new()
	item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(item_layer)
	item_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_image = day01_view._texture(null,stage,Rect2(620,240,360,330))
	room_machine=day01_view._texture(_asset("television-front-v1.png"),stage,Rect2(1225,250,300,285))
	room_machine.hide()
	detail_return=_button("返回探索",func() -> void:narrative.close_item();_refresh())
	stage.add_child(detail_return)
	detail_return.position=Vector2(1270,810)

	_build_extension_cast()
	_build_end_screen()
	utility_window = AcceptDialog.new()
	_style_dialog(utility_window)
	utility_window.exclusive = true
	utility_window.ok_button_text = "返回场景"
	add_child(utility_window)
	utility_content = VBoxContainer.new()
	utility_content.custom_minimum_size = Vector2(480,240)
	utility_content.add_theme_constant_override("separation",18)
	utility_window.add_child(utility_content)
	utility_window.confirmed.connect(_close_utility)
	utility_window.canceled.connect(_close_utility)
	machine_audio = AudioStreamPlayer.new()
	add_child(machine_audio)
	lab_audio = AudioStreamPlayer.new()
	add_child(lab_audio)
	if ResourceLoader.exists("res://assets/continuation/machine-lesson.ogg"):
		machine_audio.stream = load("res://assets/continuation/machine-lesson.ogg")
	if ResourceLoader.exists("res://assets/continuation/lab-ambience.ogg"):
		lab_audio.stream = load("res://assets/continuation/lab-ambience.ogg")
	if "--preview-part3" in OS.get_cmdline_user_args(): narrative.enter_scene(6)
	if "--preview-chapter4" in OS.get_cmdline_user_args():
		# Preview starts here with no fabricated earlier completion or reports.
		for number in range(narrative.data.scenes.size()):
			if narrative.data.scenes[number].id == "p4-maze": narrative.enter_scene(number); break
	_refresh()

func _asset(value: String) -> Texture2D:
	if value.is_empty(): return null
	var path := value if value.begins_with("res://") else "res://assets/continuation/"+value
	return load(path) if ResourceLoader.exists(path) else null

func _build_extension_cast() -> void:
	var cast: RefCounted = day01_view.dialogue_cast
	for id:String in ["charlie_left","charlie_right"]:
		cast.portraits[id].texture=_asset("charlie-casual-v1.png")
		cast.portraits[id].flip_h=id=="charlie_left"
	for id: String in ["bert","strauss","nemur"]:
		var texture := _asset(id+".png")
		var width := 1320.0 * texture.get_width()/texture.get_height()
		cast.portraits[id] = day01_view._texture(texture,cast.layer,Rect2(390-width/2,100,width,1320))
		cast.portraits[id].hide()
	cast.speaker_names.merge({"bert":"伯特","strauss":"斯特劳斯医生","nemur":"尼姆教授"})
	cast.portraits.bert.flip_h = true
	# 三位研究者同时讨论时固定同场，避免按说话者反复替换出入场。
	var group := {"strauss_group":["strauss.png",210,"斯特劳斯医生"],"bert_group":["bert.png",570,"伯特"],"nemur_group":["nemur.png",930,"尼姆教授"],"charlie_group":["res://assets/bakery/charlie-reference.webp",1300,"查理"]}
	for id: String in group:
		var p: Array = group[id]
		var texture := _asset(p[0])
		var width := 1080.0 * texture.get_width()/texture.get_height()
		cast.portraits[id] = day01_view._texture(texture,cast.layer,Rect2(p[1]-width/2,130,width,1080))
		cast.portraits[id].hide()
		cast.speaker_names[id] = p[2]
		cast.portraits[id].flip_h = id == "bert_group"

func _build_end_screen() -> void:
	end_screen = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101a20")
	style.content_margin_left = 260
	style.content_margin_right = 260
	style.content_margin_top = 200
	style.content_margin_bottom = 180
	end_screen.add_theme_stylebox_override("panel",style)
	stage.add_child(end_screen)
	end_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",30)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	end_screen.add_child(stack)
	end_label = _label("",34)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_label.add_theme_color_override("font_color",Color("fff4df"))
	stack.add_child(end_label)
	stack.add_child(_button("阅读进步报告",_show_extension_report))
	chapter_button = _button("继续",_continue_chapter)
	stack.add_child(chapter_button)
	stack.add_child(_button("从头阅读",_confirm_restart))

func _active_item() -> Dictionary:
	if narrative.phase == "complete": return {}
	for item: Dictionary in narrative.scene().items:
		if item.id == narrative.active_item: return item
	return {}

func _refresh() -> void:
	if not is_instance_valid(items_box): return
	if loaded_scene>=0 and loaded_scene!=narrative.scene_index and narrative.phase!="complete" and not runtime.busy:
		var destination: String = {"office":"心理咨询室","lab":"实验室","hospital":"医院病房","school":"夜校"}.get(narrative.scene().bg,"")
		if not narrative.scene().intro.is_empty() and narrative.scene().intro[0][0]=="旁白":destination=""
		runtime.transition(destination,_refresh)
		return
	var complete := narrative.phase == "complete"
	end_screen.visible = complete or narrative.phase == "chapter_end"
	if complete:
		end_label.text = "DAY 16–46 END\n从“变聪明”到“读懂人心”"
		dialogue_panel.hide()
		item_layer.hide()
		items_box.hide()
		continue_button.hide()
		var empty_cast: Array[String] = []
		day01_view.dialogue_cast.refresh_for(empty_cast,"")
		chapter_button.hide()
		return
	var scene_data := narrative.scene()
	var line := narrative.current_line()
	var reading := narrative.phase == "reading"
	var exploring := narrative.phase == "explore" and narrative.active_item.is_empty()
	var item := _active_item()
	var needs_machine: bool = scene_data.bg == "home" or scene_data.id == "p3-volume"
	if needs_machine and machine_audio.stream != null and runtime.audio.armed:
		if not machine_audio.playing: machine_audio.play()
	else: machine_audio.stop()
	lab_audio.stop()
	title.text = scene_data.part+" · "+scene_data.title
	location.text = {"office-outside":"心理咨询室外 · 3月4日午休","office":"心理咨询室","lab":"实验室","hospital":"医院病房","cafeteria":"大学餐厅","home":"查理住处","bar":"酒馆","school":"实验室附近的教室","bakery":"面包店"}.get(scene_data.bg,"")
	var visible_bg: String = item.get("bg",scene_data.bg) if reading else scene_data.bg
	if reading and item.has("bg"):
		location.text = {"memory":"记忆碎片","cafeteria":"大学餐厅"}.get(visible_bg,location.text)
	backdrop.texture = _asset(narrative.data.assets.backgrounds.get(visible_bg,""))
	backdrop.visible = backdrop.texture != null
	backdrop.modulate = Color.WHITE
	shade.color = Color(0.04,0.07,0.09,0.12) if backdrop.visible else Color("182329")
	narrator.hide()
	charlie.hide()
	people_row.hide()
	for button: Button in object_buttons.values(): button.hide()
	day01_view.alice_portrait.hide()
	day01_view._hide_hint(true)
	items_box.hide()
	title.get_parent().hide()
	if loaded_scene != narrative.scene_index:
		loaded_scene = narrative.scene_index
		_rebuild_items()
	for button: Button in items_box.get_children():
		button.text = button.get_meta("label") + ("  ✓" if narrative.completed.has(str(loaded_scene)+":"+button.get_meta("id")) else "")
	# One list of compact actions; separate ink buttons would overlap people.
	items_box.hide()
	item_layer.visible = exploring
	if scene_data.has("after_maze") and not narrative.maze_results.has(str(int(scene_data.maze))): item_layer.hide()
	task.visible = exploring
	task.text = "点击人物或物件探索；点击右下角继续。" if not scene_data.get("missing_text",false) else ""
	speaker.text = line.speaker
	dialogue_text.text = line.text
	dialogue_text.show()
	paper.show()
	dialogue_panel.visible = reading
	detail_return.visible = not reading and not item.is_empty() and narrative.phase=="explore"
	progress.text = "%d / %d" % [narrative.index+1,narrative.queue.size()] if reading else ""
	next_button.visible = dialogue_panel.visible
	next_button.text = "继续  ≫" if reading else "返回探索  ≫"
	continue_button.visible = exploring
	var needs_maze: bool = scene_data.has("maze") and not narrative.maze_results.has(str(int(scene_data.get("maze",0))))
	continue_button.text = "进入迷宫测试  ≫" if needs_maze else "下一场景  ≫"
	continue_button.disabled = scene_data.get("requires_volume",false) and not narrative.volume_adjusted
	maze_button.hide()
	day01_view._skin_next()
	day01_view._layout_reference_dialogue()
	var actors: Array[String] = []
	var specified: Array = item.get("actors",scene_data.get("actors",[]))
	if exploring:
		for candidate: Dictionary in scene_data.items:
			if candidate.get("kind","") == "person":
				specified = candidate.get("actors",specified)
				break
	# 多人办公室对话按该句明确参与者配置，不把旧人物挪位。
	if scene_data.has("speakerActors"):
		specified = ["strauss_group","bert_group","nemur_group","charlie_group"]
	actors.assign(specified)
	actors=_dialogue_pair(actors,line.speaker)
	if end_screen.visible or narrative.phase == "maze" or not reading: actors.clear()
	day01_view.dialogue_cast.refresh_for(actors,line.speaker)
	item_image.texture = _asset(narrative.data.assets.items.get(item.get("asset",""),item.get("asset","")+".png")) if item.has("asset") else null
	if scene_data.get("ink",false): item_image.texture = null
	item_image.visible = item_image.texture != null and not end_screen.visible and narrative.phase != "maze"
	room_machine.visible=visible_bg in ["home","home-night"] and not end_screen.visible and narrative.phase!="maze"
	if room_machine.visible and item.get("asset","")=="television":item_image.hide()
	if narrative.phase == "chapter_end":
		if shown_report != scene_data.report:
			shown_report = scene_data.report
			_show_extension_report.call_deferred()
		var report: Dictionary = narrative.data.reports[scene_data.report]
		end_label.text = "DAY 02 END\n跑在我前面的阿尔吉侬\n下一章：手术之后" if scene_data.report == "report2" else "CHAPTER 01 · PART 03 END\n慢慢移动的时针" if scene_data.report == "report8" else report.title+"\n"+report.date
		chapter_button.text = "进入 DAY 03–15  ≫" if scene_data.report == "report2" else "继续  ≫"
		chapter_button.visible = true
	if narrative.phase == "maze" and not is_instance_valid(race):
		race = Race.new()
		race.round_number = int(scene_data.maze)
		stage.add_child(race)
		race.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		race.finished.connect(_race_finished)
	if OS.has_feature("web") and "--ink-qa" in OS.get_cmdline_user_args():
		JavaScriptBridge.get_interface("window").flowerInkQA = JSON.stringify({"scene":scene_data.id,"phase":narrative.phase,"index":narrative.index,"history":narrative.history.size(),"completed":narrative.completed,"ink_observed":narrative.ink_observed,"ink_result":narrative.ink_result})

func _rebuild_items() -> void:
	for child: Node in items_box.get_children():
		items_box.remove_child(child)
		child.queue_free()
	for child: Node in item_layer.get_children():
		item_layer.remove_child(child)
		child.queue_free()
	for item: Dictionary in narrative.scene().items:
		var button := _button(item.label,start_object.bind(item.id))
		button.add_theme_font_size_override("font_size",18)
		button.set_meta("label",item.label)
		button.set_meta("id",item.id)
		items_box.add_child(button)
		var r: Array = item.get("rect",[])
		if item.id=="television" and narrative.scene().bg in ["home","home-night"]:r=[1225,250,300,285]
		if narrative.scene().bg == "hospital":
			r = {"cake":[905,475,110,85],"magazine":[1065,505,165,85]}.get(item.id,r)
		if r.is_empty():
			# No embedded person/object exists at this point: use an honest compact
			# action rather than a hit area on unrelated background furniture.
			var action := _button(item.label+" · "+("交谈" if item.get("kind","")=="person" else "查看"),start_object.bind(item.id))
			action.custom_minimum_size=Vector2(220,40)
			item_layer.add_child(action)
			action.position=Vector2(64,190+(items_box.get_child_count()-1)*52)
			action.add_theme_font_size_override("font_size",17)
			for visual: String in ["normal","hover","pressed","focus"]: action.add_theme_stylebox_override(visual,StyleBoxEmpty.new())
		if item.id == "ink": r=[]
		if not r.is_empty():
			var hot := Hotspot.new()
			hot.configure(PackedVector2Array([Vector2(r[0],r[1]),Vector2(r[0]+r[2],r[1]),Vector2(r[0]+r[2],r[1]+r[3]),Vector2(r[0],r[1]+r[3])]),item.label+" · 查看")
			item_layer.add_child(hot)
			hot.pressed.connect(start_object.bind(item.id))
			hot.hint_changed.connect(func(active: bool) -> void:
				if active and narrative.phase == "explore": day01_view._show_hint(hot)
				else: day01_view._hide_hint())

func advance() -> void:
	if runtime.busy: return
	if day01_view.has_modal() or narrative.phase == "maze": return
	if narrative.phase == "reading": narrative.advance()
	elif not narrative.active_item.is_empty(): narrative.close_item()
	_refresh()

func continue_main() -> void:
	if runtime.busy: return
	if day01_view.has_modal(): return
	var proceed := func() -> void:
		narrative.continue_scene()
		_refresh()
	if narrative.scene().has("maze"): runtime.transition("迷宫实验",proceed)
	else: runtime.transition("实验室" if narrative.scene().id == "d2-ink" else "",proceed)

func start_object(id: String) -> void:
	if runtime.busy: return
	if day01_view.has_modal() or not narrative.start_item(id): return
	_refresh()
	if narrative.phase == "ink_observation":
		stage.hide()
		runtime.hide()
		ink_game = NativeInk.new()
		add_child(ink_game)
		ink_game.completed.connect(_ink_completed)
	if narrative.phase in ["note","volume","words"]: _show_utility()
	if narrative.phase == "archive":
		runtime.reports()
		narrative.close_item()
		_refresh()

func start_talk(id: String) -> void:
	start_object(id)

func _show_utility() -> void:
	for child: Node in utility_content.get_children():
		utility_content.remove_child(child)
		child.queue_free()
	var item := _active_item()
	utility_window.title = item.label
	if narrative.phase == "note":
		for choice: String in item.choices:
			utility_content.add_child(_button(choice,func() -> void:
				if choice not in narrative.notes: narrative.notes.append(choice)
				utility_window.hide()
				_close_utility()))
	elif narrative.phase == "volume":
		utility_content.add_child(_label("转低音量，让机器安静下来。",22))
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.01
		slider.value = narrative.volume
		slider.custom_minimum_size = Vector2(480,60)
		utility_content.add_child(slider)
		slider.value_changed.connect(func(value: float) -> void:
			narrative.set_volume(value)
			machine_audio.volume_db = linear_to_db(maxf(value,0.001)))
	else:
		for word: String in item.words: utility_content.add_child(_label(word,28))
	utility_window.popup_centered(Vector2i(560,350))

func _close_utility() -> void:
	narrative.close_item()
	_refresh()

func _ink_completed(result: Dictionary) -> void:
	stage.show()
	runtime.show()
	narrative.end_ink_observation(result)
	_refresh()
	next_button.grab_focus()

func _race_finished(result: Dictionary) -> void:
	narrative.complete_maze(result)
	_refresh()

func _continue_chapter() -> void:
	if runtime.busy or day01_view.has_modal(): return
	narrative.continue_chapter()
	_refresh()

func _show_extension_report() -> void:
	if narrative.phase not in ["chapter_end","complete"]: return
	var id: String = narrative.last_report if narrative.phase == "complete" else narrative.scene().report
	var report: Dictionary = narrative.data.reports[id]
	if id in ["report2-0304","report2-0306-maze","report2-0306-decision","report2-0308"]:
		open_designed_report(id,false)
		return
	day01_view.report_window.title = report.title
	day01_view.report_text.text = report.title+"\n"+report.date+"\n\n"+report.text
	day01_view.report_text.scroll_to_line(0)
	day01_view.report_window.popup_centered_ratio(0.84)

func open_designed_report(id:String,review:bool) -> void:
	if is_instance_valid(designed_page):return
	designed_page=load("res://scripts/story/designed_report.gd").new()
	designed_page.report_id=id
	designed_page.z_index=110
	add_child(designed_page)
	designed_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	designed_page.open()
	stage.hide();runtime.hide()
	designed_page.continued.connect(func() -> void:
		var finished_page:Control=designed_page
		designed_page=null
		finished_page.queue_free()
		stage.show();runtime.show()
		if not review and narrative.phase=="chapter_end":narrative.continue_chapter()
		_refresh())

func _dialogue_pair(specified:Array[String],who:String) -> Array[String]:
	var pair:Array[String]=[]
	if who.begins_with("查理") and ("独白" in who or "旁白" in who):return ["charlie_right"]
	var person:String={"伯特":"bert","斯特劳斯医生":"strauss","尼姆教授":"nemur","爱丽丝":"alice","唐纳店长":"donner","吉姆皮":"gimpy","卡普尔":"karp"}.get(who,"")
	if narrative.scene().id=="p4-research" and narrative.active_item.is_empty() and person in ["strauss","nemur"]:
		pair.assign(["strauss","nemur"])
	elif not person.is_empty():pair.assign([person,"charlie_right"] if person!="alice" else ["charlie_left","alice"])
	elif who.begins_with("查理"):
		for id:String in specified:
			var normal:String=id.trim_suffix("_group")
			if not normal.begins_with("charlie") and normal in day01_view.dialogue_cast.portraits:pair.append(normal);break
		pair.append("charlie_right")
	elif who=="旁白":return []
	else:return ["charlie_right"]
	for i in range(pair.size()):
		var image:TextureRect=day01_view.dialogue_cast.portraits[pair[i]]
		var height:=1320.0;var width:=height*image.texture.get_width()/image.texture.get_height()
		image.position=Vector2((390.0 if i==0 and pair.size()==2 else 1180.0)-width/2,100)
		image.size=Vector2(width,height)
	return pair

func _show_history() -> void:
	super._show_history()

func _show_help() -> void:
	var dialog := AcceptDialog.new()
	_style_dialog(dialog)
	dialog.dialog_text = "点击继续阅读；左侧可探索人物和物件。\n迷宫使用WASD或方向键行走，第一轮需到达出口；第二轮可主动结束。\n音量旋钮调到30%以下后可继续。\n背景或逐句文字缺少的场景保留空白，可直接继续。"
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _process(_delta: float) -> void:
	if is_instance_valid(race): race.paused = day01_view.has_modal()
	if is_instance_valid(lab_audio): lab_audio.stream_paused = history_window.visible
	if is_instance_valid(machine_audio) and runtime.audio != null:
		machine_audio.volume_db=linear_to_db(maxf(0.0001,narrative.volume*runtime.audio.options.master*runtime.audio.options.effects))
		machine_audio.stream_paused=history_window.visible or runtime.audio.options.mute
