extends SceneTree
## Native Godot visual checks. Run without --headless; screenshots stay local.
var chapter: Control
var failures := 0
var elapsed := 0.0
func _initialize() -> void:
	call_deferred("run")
func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 45:
		push_error("Native UI capture timed out")
		quit(1)
	return false
func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		push_error(why)
func settle(seconds := 0.3) -> void:
	await create_timer(seconds).timeout
func capture(name: String) -> void:
	await settle()
	var bitmap := root.get_texture().get_image()
	check(bitmap != null and not bitmap.is_empty(),"Godot真实渲染输出："+name)
	if bitmap != null: bitmap.save_png("res://../.verification/paper-godot-"+name+".png")
func click(point: Vector2) -> void:
	var movement := InputEventMouseMotion.new()
	movement.position = point
	root.push_input(movement,true)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		root.push_input(event,true)
		await process_frame
func choose_option(key: String, index: int) -> void:
	var choice: HBoxContainer = chapter.runtime.settings_panel.controls[key]
	await click(choice.buttons[index].get_global_rect().get_center())
	await settle()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use the Godot native window for this capture")
		quit(1)
		return
	root.size = Vector2i(1600,900)
	var prefs: RefCounted = preload("res://scripts/story/story_preferences.gd").shared()
	prefs.reset()
	chapter = preload("res://scripts/story/continuation_chapter.gd").new()
	chapter.theme = load("res://ui/chapter1_theme.tres")
	root.add_child(chapter)
	chapter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chapter.narrative.enter_scene(10)
	chapter._refresh()
	await settle(2.2)
	await capture("toolbar-16-9")
	var gear: Button = chapter.runtime.hud.get_child(2)
	var movement := InputEventMouseMotion.new()
	movement.position = gear.get_global_rect().get_center()
	root.push_input(movement,true)
	await settle(0.2)
	check(is_equal_approx(gear.glyph.scale.x,1.08),"原生鼠标悬停动效")
	await click(gear.get_global_rect().get_center())
	await settle(0.3)
	check(chapter.runtime.settings_panel.visible,"原生点击齿轮打开设置")
	await capture("settings-16-9")
	var panel: Control = chapter.runtime.settings_panel
	var slider: Control = panel.controls.master
	await click(slider.get_global_rect().position+slider.size*Vector2(0.4,0.5))
	check(absf(prefs.values.master-0.4)<0.06,"原生鼠标实际改变音量")
	# A native fullscreen switch must really change DisplayServer mode.
	await choose_option("text_speed",2)
	check(prefs.values.text_speed == 2,"原生纸签选项切换文字速度")
	await choose_option("fullscreen",1)
	await settle()
	check(prefs.is_fullscreen(),"原生全屏模式真实生效")
	await choose_option("fullscreen",0)
	root.size = Vector2i(1600,1000)
	await settle()
	await choose_option("aspect",2)
	await settle(0.6)
	check(not prefs.is_fullscreen(),"原生窗口模式真实生效")
	check(prefs.values.aspect == 2,"原生纸签选项切换16:10")
	check(is_equal_approx(chapter.runtime.hud.get_global_rect().get_center().y,chapter.runtime.task_panel.get_global_rect().get_center().y),"原生16:10左右图标中心对齐")
	await capture("settings-16-10")
	panel.close_panel()
	await capture("toolbar-16-10")
	prefs.reset()
	chapter.queue_free()
	await process_frame
	print("NATIVE PAPER VISUAL CHECK: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
