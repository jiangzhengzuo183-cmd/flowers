extends Control
## Shared production UI, linear reading timer, transition and isolated rehearsal.
const CONFIG := "res://modules/visual_novel/data/experience.json"
var host: Control
var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
var hud: HBoxContainer
var auto_button: Button
var automatic := false
var speed := 1
var age := 0.0
var letters := 0.0
var key := ""
var text := ""
var busy := false
var focused := true
var last_scene := ""
var curtain: ColorRect
var caption: Label
var window: AcceptDialog
var debug_model: RefCounted
var debug_window: AcceptDialog
var journal: Array[Dictionary] = []
var saved_journal: Array[Dictionary] = []
var saved_automatic := false
var report_unlocked: Array[String] = []
var hand: TextureRect
var lucky: TextureRect
var audio: Node
var mouse_plate: TextureRect
var mouse_next: Button
var review_page: Control
var debug_status: Label
var task_panel: PanelContainer

func _ready() -> void:
	z_index=60
	automatic=Engine.get_meta("experience_auto",false)
	speed=Engine.get_meta("experience_speed",1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = HBoxContainer.new()
	hud.position = Vector2(1224,24)
	hud.size = Vector2(312,48)
	hud.alignment=BoxContainer.ALIGNMENT_END
	hud.add_theme_constant_override("separation",8)
	add_child(hud)
	auto_button = small("自动 ●" if automatic else "自动",func() -> void: automatic = not automatic; Engine.set_meta("experience_auto",automatic); age=0; auto_button.text="自动 ●" if automatic else "自动")
	hud.add_child(auto_button)
	auto_button.custom_minimum_size=Vector2(88,48)
	for entry: Array in [["◌",host._show_history],["?",host._show_help],["☰",menu]]:
		hud.add_child(small(entry[0],entry[1]))
	var icons := ["","history","help","menu"]
	for i in range(hud.get_child_count()):
		var button: Button = hud.get_child(i)
		for state: String in ["normal","hover","pressed","focus"]:
			var style:=StyleBoxFlat.new();style.bg_color=Color("f5d17f") if state=="normal" else Color("ffe9aa");style.set_corner_radius_all(8)
			style.content_margin_left=10;style.content_margin_right=10
			button.add_theme_stylebox_override(state,style)
		button.custom_minimum_size.y=48
		if i>0:
			button.text=""
			button.icon=load("res://modules/visual_novel/assets/experience/"+icons[i]+".svg")
	task_panel=PanelContainer.new()
	task_panel.position=Vector2(64,100);task_panel.size=Vector2(740,70);task_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var prompt_style:=StyleBoxFlat.new();prompt_style.bg_color=Color("fff4df");prompt_style.set_corner_radius_all(8)
	prompt_style.content_margin_left=20;prompt_style.content_margin_right=20;prompt_style.content_margin_top=12;prompt_style.content_margin_bottom=12
	prompt_style.border_color=Color("d6af62");prompt_style.set_border_width_all(1)
	task_panel.add_theme_stylebox_override("panel",prompt_style);host.stage.add_child(task_panel)
	host.task.reparent(task_panel);host.task.add_theme_font_size_override("font_size",18)
	host.task.add_theme_color_override("font_color",Color("34464b"));host.task.add_theme_constant_override("outline_size",0)
	host.task.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	curtain = ColorRect.new()
	curtain.color = Color(0,0,0,0)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.hide()
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color",Color("fff3df"))
	caption.add_theme_font_size_override("font_size",30)
	curtain.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand = host.day01_view._texture(preload("res://modules/visual_novel/assets/experience/rabbit-hand.png"),host.cast_layer,Rect2(920,275,460,680))
	hand.hide()
	lucky = host.day01_view._texture(preload("res://modules/visual_novel/assets/experience/charlie-lucky.png"),host.cast_layer,Rect2(150,100,690,1035))
	lucky.hide()
	mouse_plate=host.day01_view._texture(preload("res://modules/visual_novel/assets/experience/algernon.png"),host.stage,Rect2(570,100,460,430))
	mouse_plate.hide()
	mouse_next=small("▶",request_advance)
	mouse_next.position=Vector2(1320,805)
	add_child(mouse_next)
	mouse_next.hide()
	var audio_script := load("res://modules/visual_novel/scripts/story/experience_audio.gd")
	audio = get_tree().root.get_node_or_null("ExperienceAudio")
	if audio == null:
		audio = audio_script.new()
		audio.name = "ExperienceAudio"
		get_tree().root.add_child.call_deferred(audio)
	get_tree().root.focus_entered.connect(_focus.bind(true))
	get_tree().root.focus_exited.connect(_focus.bind(false))

func _focus(value: bool) -> void:
	focused=value
	age=0

func small(label: String, action: Callable) -> Button:
	var b: Button = host._button(label,action)
	b.custom_minimum_size=Vector2(46,40)
	b.add_theme_font_size_override("font_size",18)
	return b

func model() -> RefCounted:
	return host.get("narrative") if host.get("narrative") != null else host.flow

func scene_id() -> String:
	return model().scene().id if host.get("narrative") != null and model().phase!="complete" else host.flow.section

func reading() -> bool:
	return model().phase=="reading" and not transitioning() and not host.day01_view.has_modal() and focused and not is_instance_valid(review_page)

func transitioning() -> bool:
	return busy or (is_instance_valid(host.transition_tween) and host.transition_tween.is_running())

func _process(dt: float) -> void:
	if not is_instance_valid(host): return
	var m := model()
	if is_instance_valid(debug_status):debug_status.text=scene_id()+" · "+str(m.index+1)+" / "+str(m.queue.size())
	var line: Dictionary = m.current_line()
	var current: String = scene_id()+":"+str(m.index)+":"+str(line.text)+":"+str(m.phase)
	if current!=key:
		key=current
		text=str(line.text)
		letters=0
		age=0
		if m.phase=="reading":
			journal.append({"scene":scene_id(),"speaker":line.speaker,"text":text})
			if debug_model==null: audio.action_for(scene_id(),text)
			elif is_instance_valid(audio): audio.silent_actions=true
	if not is_instance_valid(host.dialogue_text): return
	task_panel.visible=host.task.visible
	if not reading(): age=0
	else:
		letters=minf(text.length(),letters+dt*settings.reading.characters_per_second)
		if letters>=text.length(): age+=dt
		var wait_time: float = maxf(settings.reading.minimum_seconds,text.length()/settings.reading.characters_per_read_second)*settings.reading.speeds[speed]
		if automatic and age>=wait_time:
			age=0
			host.advance()
	var complete := letters>=text.length()
	host.dialogue_text.visible_characters = -1 if complete or m.phase!="reading" else int(letters)
	var black: bool = host.flow.section in ["opening","home"] and host.get("narrative")==null and m.phase=="reading"
	if host.get("narrative")!=null and m.phase=="reading":
		black=host._active_item().get("presentation","")=="memory"
		if black:
			host.backdrop.hide()
			host.shade.color=Color.BLACK
			host.narrator.show()
			host.narrator.text=text
			host.narrator.add_theme_color_override("font_color",Color("fff3df"))
		host.location.get_parent().visible=not black
	if host.get("narrative")==null:
		host.title.get_parent().hide()
		host.location.get_parent().visible = not black and m.phase not in ["complete","report","next_chapter"]
	hud.visible = not black and m.phase not in ["complete","report","chapter_end","next_chapter","maze","ink_observation"] and not busy
	if debug_model!=null and not busy:hud.show()
	if black:
		host.task.hide()
		host.progress.hide()
		host.dialogue_panel.hide()
		host.narrator.position=Vector2(150,0)
		host.narrator.size=Vector2(1300,900)
		host.narrator.visible_characters = -1 if complete else int(letters)
		if line.speaker.begins_with("查理"):
			host.narrator.position=Vector2(650,200);host.narrator.size=Vector2(800,400)
	else: host.progress.show()
	if m.phase=="reading" and not black and host.dialogue_panel.visible:
		host.next_button.text="▶"
		host.next_button.size=Vector2(42,42)
		host.next_button.position=Vector2(1390,host.dialogue_panel.size.y-60)
		host.next_button.custom_minimum_size=Vector2(42,42)
		host.next_button.visible=complete
		for state: String in ["normal","hover","pressed","focus"]: host.next_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var has_paper: bool = host.dialogue_panel.visible and host.paper.visible
	if not has_paper: host.day01_view.dialogue_cast.layer.hide()
	elif not host.day01_view.dialogue_cast.current.is_empty(): host.day01_view.dialogue_cast.layer.show()
	if black and line.speaker.begins_with("查理"):
		var one:Array[String]=["charlie_left"]
		host.day01_view.dialogue_cast.refresh_for(one,line.speaker)
		host.day01_view.dialogue_cast.layer.show()
	var show_lucky: bool = reading() and scene_id()=="d2-hospital" and "幸运兔脚、幸运钱" in text
	var show_hand: bool = reading() and "拿着它" in text
	set_display(lucky,show_lucky)
	set_display(hand,show_hand)
	var intro: bool = reading() and scene_id()=="d2-maze" and "这只白老鼠" in text
	mouse_plate.visible=intro
	mouse_next.visible=intro
	if intro:
		host.backdrop.hide()
		host.shade.color=Color("faf2df")
		host.dialogue_panel.hide()
		host.narrator.show()
		host.narrator.text="阿尔吉侬\n\n"+text
		host.narrator.position=Vector2(150,530)
		host.narrator.size=Vector2(1300,190)
		host.narrator.add_theme_color_override("font_color",Color("34464b"))
		if letters<text.length(): mouse_next.hide()
	var transition_narration: bool = reading() and line.speaker=="旁白" and ("场景转" in text or "来到" in text or "离开医院" in text or "手术已经完成" in text or "继续接受测试" in text or "一直等手术起效" in text or "在大学餐厅" in text)
	transition_narration=transition_narration or (reading() and "脱下围裙" in text)
	if transition_narration:
		host.dialogue_panel.hide()
		host.day01_view.dialogue_cast.layer.hide()
		host.narrator.show()
		host.narrator.text=text
		host.narrator.position=Vector2(210,260)
		host.narrator.size=Vector2(1180,300)
		host.narrator.add_theme_color_override("font_color",Color("fff3df"))
		host.shade.color=Color(0.03,0.04,0.04,0.85)
		mouse_next.visible=complete
	if is_instance_valid(audio):
		audio.silent_actions = debug_model!=null
		var group := "lab" if scene_id().begins_with("d2-") else "bakery"
		if "hospital" in scene_id(): group="hospital"
		if scene_id() in ["leaving","home","classroom","alice"]: group="night"
		if host.get("narrative")!=null:
			group={"lab":"lab","office":"lab","bar":"night","school":"night","cafeteria":"night","home":"night","home-night":"night","hospital":"hospital"}.get(m.scene().bg,"bakery") if m.phase!="complete" else "night"
		audio.choose(group)
	task_panel.visible=host.task.visible and not black and m.phase in ["people","objects","explore"]
	if OS.has_feature("web") and "--experience-qa" in OS.get_cmdline_user_args():
		var state := {"scene":scene_id(),"phase":m.phase,"index":m.index,"busy":busy,"letters":letters,"length":text.length(),"history":m.history.size(),"automatic":automatic,"hud":hud.is_visible_in_tree()}
		if host.get("narrative")!=null:
			state["ink_observed"]=m.ink_observed
			state["reports"]=m.unlocked_reports
			state["active_item"]=m.active_item
		if is_instance_valid(host.get("ink_game")):
			state.merge({"card":host.ink_game.selected,"flow":host.ink_game.field.energy,"moving":host.ink_game.moving,"zoom":host.ink_game.zoom})
		JavaScriptBridge.get_interface("window").flowerExperienceQA=JSON.stringify(state)

func set_display(item: TextureRect, show_it: bool) -> void:
	if item.get_meta("shown",false) == show_it: return
	item.set_meta("shown",show_it)
	var old: Tween = item.get_meta("animation") if item.has_meta("animation") else null
	if old:old.kill()
	if not item.has_meta("rest_y"):item.set_meta("rest_y",item.position.y)
	if show_it:
		item.modulate.a=0
		if item==hand:item.position.y=float(item.get_meta("rest_y"))+24
		item.show()
		var t:=create_tween().set_parallel(true)
		item.set_meta("animation",t)
		t.tween_property(item,"modulate:a",1.0,0.28)
		if item==hand:t.tween_property(item,"position:y",item.get_meta("rest_y"),0.28)
	elif item==hand:
		var t:=create_tween()
		item.set_meta("animation",t)
		t.tween_property(item,"modulate:a",0.0,0.18)
		t.tween_callback(item.hide)
	else:item.hide()

func request_advance() -> void:
	if not reading(): return
	if is_instance_valid(audio): audio.arm()
	age=0
	if letters<text.length(): letters=text.length(); host.dialogue_text.visible_characters=-1
	else: host.advance()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and is_instance_valid(audio): audio.arm()
	if transitioning() and (event is InputEventMouseButton or event is InputEventKey):
		get_viewport().set_input_as_handled()
		return
	if not reading(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER,KEY_RIGHT]:
		request_advance()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var black: bool = host.get("narrative")==null and host.flow.section in ["opening","home"]
		if host.get("narrative")!=null:black=host._active_item().get("presentation","")=="memory"
		if black or host.dialogue_panel.get_global_rect().has_point(event.position):
			request_advance()
			get_viewport().set_input_as_handled()

func transition(label: String, action: Callable) -> void:
	if busy: return
	busy=true
	age=0
	curtain.show()
	curtain.mouse_filter=Control.MOUSE_FILTER_STOP
	caption.text=label
	var t:=create_tween()
	t.tween_property(curtain,"color:a",1.0,settings.transition_seconds*0.4)
	t.tween_callback(action)
	t.tween_interval(settings.transition_seconds*0.2)
	t.tween_property(curtain,"color:a",0.0,settings.transition_seconds*0.4)
	t.tween_callback(func() -> void: busy=false; curtain.hide(); curtain.mouse_filter=Control.MOUSE_FILTER_IGNORE; age=0)

func popup(title: String) -> VBoxContainer:
	if is_instance_valid(window):window.hide();window.queue_free()
	window=AcceptDialog.new()
	host._style_dialog(window)
	window.title=title
	window.exclusive=true
	host.add_child(window)
	var content:=VBoxContainer.new()
	content.custom_minimum_size=Vector2(550,240)
	window.add_child(content)
	content.add_child(host._label(title,24))
	window.confirmed.connect(window.queue_free)
	window.canceled.connect(window.queue_free)
	window.popup_centered()
	return content

func menu() -> void:
	var box:=popup("菜单与声音")
	for entry: Array in [["总音量","master"],["音乐","music"],["音效","effects"]]:
		box.add_child(host._label(entry[0]))
		var slider:=HSlider.new()
		slider.min_value=0;slider.max_value=1;slider.step=0.01
		slider.value=audio.options.get(entry[1],0.7)
		box.add_child(slider)
		slider.value_changed.connect(func(v:float) -> void: audio.set_option(entry[1],v))
	box.add_child(small("静音 / 恢复",func() -> void: audio.set_option("mute",not audio.options.mute)))
	var speeds:=OptionButton.new()
	for name: String in ["慢","标准","快"]: speeds.add_item(name)
	speeds.select(speed)
	speeds.item_selected.connect(func(i:int) -> void: speed=i; Engine.set_meta("experience_speed",speed); age=0)
	box.add_child(speeds)
	box.add_child(small("已解锁报告",reports))
	box.add_child(small("从头阅读",host._confirm_restart))
	if settings.development: box.add_child(small("剧情调试",debug_menu))

func reports() -> void:
	var box:=popup("已解锁进步报告")
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(550,280)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var story: Node = host.get_parent()
	if story.get("completed_day01") != null and story.completed_day01.report_completed:
		list.add_child(small("进步抱告—1 · 3月3日",func() -> void:
			window.hide()
			review_page=load("res://modules/visual_novel/scenes/report1.tscn").instantiate()
			host.add_child(review_page)
			review_page.z_index=100
			review_page.open()
			review_page.continued.connect(review_page.queue_free)))
	if host.get("narrative")!=null:
		for id: String in model().unlocked_reports:
			var report:Dictionary=model().data.reports[id]
			list.add_child(small(report.title+" · "+report.date,func() -> void:
				window.hide()
				if id in ["report2-0304","report2-0306-maze","report2-0306-decision","report2-0308"]:
					host.open_designed_report(id,true)
					return
				host.day01_view.report_text.text=report.title+"\n"+report.date+"\n\n"+report.text
				host.day01_view.report_text.scroll_to_line(0)
				host.day01_view.report_window.popup_centered_ratio(0.84)))
	else: list.add_child(host._label("完成对应剧情后解锁。"))

func debug_menu() -> void:
	if not settings.development: return
	var box:=popup("剧情调试 · 独立演练状态")
	debug_status=host._label(scene_id()+" · "+str(model().index+1)+" / "+str(model().queue.size()))
	box.add_child(debug_status)
	var nodes:=OptionButton.new()
	if host.get("narrative")!=null:
		for data:Dictionary in model().data.scenes: nodes.add_item(data.id)
		nodes.select(mini(model().scene_index,nodes.item_count-1))
	else:
		for id:String in ["opening","exterior","intro","people","objects","closing","leaving","classroom","alice","home","complete"]: nodes.add_item(id)
	box.add_child(nodes)
	box.add_child(small("跳转 / 重播节点",func() -> void: rehearse(nodes.selected,nodes.get_item_text(nodes.selected)); window.hide()))
	box.add_child(small("上一句",func() -> void: isolate(); model().index=maxi(0,model().index-1); host._refresh(); key=""))
	box.add_child(small("下一句",func() -> void: isolate(); model().advance(); host._refresh(); key=""))
	box.add_child(small("结束演练，恢复正式进度",restore))

func isolate() -> void:
	if debug_model!=null:return
	debug_model=model()
	saved_automatic=automatic
	saved_journal=journal.duplicate(true)
	var clone:RefCounted=debug_model.get_script().new()
	for p:Dictionary in debug_model.get_property_list():
		if p.usage&PROPERTY_USAGE_SCRIPT_VARIABLE and p.name!="script":
			var value:Variant=debug_model.get(p.name)
			clone.set(p.name,value.duplicate(true) if value is Array or value is Dictionary else value)
	if host.get("narrative")!=null: host.narrative=clone
	else:host.flow=clone

func rehearse(number:int,id:String) -> void:
	isolate()
	_clear_transients()
	if host.get("narrative")!=null:
		model().enter_scene(number)
		host.loaded_scene=-1
	else:
		var m:=model()
		m.section=id
		m.active_person="alice" if id=="alice" else ""
		if id in ["people","objects","complete"]:m.phase=id
		else:m._begin(m.data.school.alice if id=="alice" else m.data.school.intro if id=="classroom" else m.data[id])
	host._refresh()
	key=""

func restore() -> void:
	if debug_model==null:return
	_clear_transients()
	if host.get("narrative")!=null:host.narrative=debug_model;host.loaded_scene=-1
	else:host.flow=debug_model
	debug_model=null
	automatic=saved_automatic
	Engine.set_meta("experience_auto",automatic)
	journal=saved_journal
	key=""
	host._refresh()
	if is_instance_valid(window):window.hide()

func _clear_transients() -> void:
	if is_instance_valid(host.get("ink_game")):
		host.ink_game.queue_free()
		host.stage.show()
		show()
	if is_instance_valid(host.get("race")):host.race.queue_free()
	if is_instance_valid(host.get("utility_window")):host.utility_window.hide()
	hand.hide()
	lucky.hide()
	automatic=false
	age=0
