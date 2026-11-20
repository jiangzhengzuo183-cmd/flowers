extends SceneTree
const Preferences := preload("res://scripts/story/story_preferences.gd")
var failures := 0
func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		push_error(why)
func frames() -> void:
	await process_frame
	await process_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var prefs: RefCounted = Preferences.shared()
	if "--save-probe" in OS.get_cmdline_user_args():
		for entry: Array in [["master",0.41],["music",0.22],["effects",0.63],["aspect",2],["text_speed",2]]: prefs.set_value(entry[0],entry[1])
		check(prefs.save_error == OK,"写入重启保存探针")
		print("PREFERENCES WRITE: ","PASS" if failures == 0 else "FAIL")
		quit(0 if failures == 0 else 1)
		return
	if "--restore-probe" in OS.get_cmdline_user_args():
		check(is_equal_approx(prefs.values.master,0.41) and is_equal_approx(prefs.values.music,0.22) and is_equal_approx(prefs.values.effects,0.63),"新Godot进程恢复三个音量")
		check(prefs.values.aspect == 2 and prefs.values.text_speed == 2,"新Godot进程恢复比例和文字速度")
		print("PREFERENCES RESTART RESTORE: ","PASS" if failures == 0 else "FAIL")
	prefs.reset()
	var chapter := preload("res://scripts/story/continuation_chapter.gd").new()
	root.add_child(chapter)
	await frames()
	var runtime: Control = chapter.runtime
	runtime.set_process(false)
	runtime._process(0)
	check(runtime.hud.get_child_count() == 3,"只保留三个纸艺按钮")
	check(runtime.hud.get_child(0).accessibility_name == "对话记录","气泡沿用对话记录功能")
	check(runtime.hud.get_child(1).accessibility_name == "进步报告","书本沿用报告功能")
	for child: Button in runtime.hud.get_children():
		check(child.glyph.material.shader.resource_path.ends_with("paper_icon_edge.gdshader"),"仅清理透明边缘，不重绘、染色或加白边")
		var image: Image = child.artwork.atlas.get_image()
		check(image.get_pixel(0,0).a == 0,"直接使用透明PNG")
	check(runtime.audio.players[0].bus == Preferences.MUSIC_BUS,"音乐路由至音乐总线")
	check(chapter.machine_audio.bus == Preferences.EFFECTS_BUS,"剧情旋钮音频路由至音效总线")
	var index: int = chapter.narrative.index
	runtime.menu()
	await frames()
	check(chapter.day01_view.has_modal() and not runtime.reading(),"设置打开时阻止主线输入与逐字计时")
	runtime.letters = 1
	runtime._process(1)
	check(runtime.letters == 1 and chapter.narrative.index == index,"设置不改变当前台词或显示进度")
	var panel: Control = runtime.settings_panel
	panel.controls.master.value = 0.37
	panel.controls.music.value = 0.21
	panel.controls.effects.value = 0.58
	for entry: Array in [["Master",0.37],[Preferences.MUSIC_BUS,0.21],[Preferences.EFFECTS_BUS,0.58]]:
		check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(entry[0]))),entry[1]),"音量滑块真正改变总线："+entry[0])
	panel.controls.aspect.item_selected.emit(2)
	await frames()
	runtime._process(0)
	check(root.content_scale_size == Vector2i(1600,1000),"16:10使用真实显示画布")
	check(chapter.stage.size == Vector2(1600,900) and chapter.stage.position.y == 50,"剧情等比居中留白，不裁切或拉伸")
	check(is_equal_approx(runtime.hud.get_global_rect().get_center().y,runtime.task_panel.get_global_rect().get_center().y),"16:10左右UI共享视觉中心线")
	panel.controls.text_speed.item_selected.emit(2)
	var reload: RefCounted = load("res://scripts/story/story_preferences.gd").new()
	check(reload.values.master == 0.37 and reload.values.aspect == 2 and reload.values.text_speed == 2,"新实例从文件恢复设置")
	panel.close_panel()
	await frames()
	runtime.letters = 0
	runtime._process(0.1)
	var fast: float = runtime.letters
	prefs.set_value("text_speed",0)
	runtime.letters = 0
	runtime._process(0.1)
	check(fast > runtime.letters*2,"文字速度接入实际逐字显示")
	runtime.menu()
	panel.reset_button.pressed.emit()
	check(panel.reset_actions.visible and prefs.values.master == 0.37,"恢复默认先确认")
	panel.reset_actions.get_child(1).pressed.emit()
	await frames()
	check(prefs.values == Preferences.DEFAULTS,"确认后恢复音频、比例、窗口与文字默认值")
	check(root.content_scale_size == Vector2i(1600,900),"恢复默认保持原16:9适配")
	panel.close_panel()
	check(chapter.narrative.index == index,"设置全过程不推进剧情")
	chapter.queue_free()
	await frames()
	check(root.content_scale_size == Vector2i(1600,900),"退出视觉小说恢复其他模块画布")
	print("PAPER SETTINGS CHECK: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
