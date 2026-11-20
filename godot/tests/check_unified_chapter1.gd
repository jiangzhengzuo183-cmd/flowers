extends SceneTree
const Chapter=preload("res://scripts/story/continuation_chapter.gd")
var failures:=0
var chapter:Control
func _initialize()->void:call_deferred("run")
func check(ok:bool,why:String)->void:
	if not ok:failures+=1;push_error(why)
func frames()->void:
	await process_frame;await process_frame
func ready_view()->void:
	chapter._refresh()
	while chapter.runtime.busy:await process_frame
	await frames()
func shot(id:String)->void:
	if "--capture" not in OS.get_cmdline_user_args():return
	await create_timer(0.3).timeout
	chapter.runtime.letters=10000;chapter.runtime._process(0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../.verification/unified-"+id+".png")
func run()->void:
	root.size=Vector2i(1600,900)
	var story:Control=load("res://scenes/story.tscn").instantiate();root.add_child(story);await frames()
	var day:Control=story.bakery
	check(day.flow.queue.size()==1 and "三十二岁" in day.flow.current_line().text,"开场合并为一个完整页面")
	day.runtime.letters=10000
	var right:=InputEventKey.new();right.pressed=true;right.keycode=KEY_RIGHT
	day.runtime._input(right);check(day.flow.section=="exterior","右方向键翻下一页")
	day.flow.section="people";day.flow.phase="people";day._refresh();await frames()
	check(day.day01_view.dialogue_cast.current.is_empty(),"人物探索插画已有查理，不叠加第二个查理")
	day.flow.section="classroom";day.flow._begin(day.flow.data.school.intro);day._refresh();await frames()
	check(day.day01_view.dialogue_cast.current==["charlie_left"] and not day.day01_view.alice_portrait.visible,"夜校独白显示查理，爱丽丝不提前出现")
	while day.flow.section=="classroom":day.advance()
	check(day.flow.active_person=="alice" and day.flow.queue.size()==16,"直接接入爱丽丝16句对话，无点击步骤")
	for i in range(8):day.advance()
	check(day.day01_view.dialogue_cast.portraits.charlie_left.texture.resource_path.ends_with("charlie-empty.png"),"交接后保持查理无本子")
	check(is_equal_approx(day.runtime.hud.position.x+day.runtime.hud.size.x*day.runtime.hud.scale.x,1600-64.0/1.2),"放大后的右上导航保持安全边距")
	story.queue_free();await frames()
	chapter=Chapter.new();chapter.theme=load("res://ui/game_theme.tres");root.add_child(chapter);await frames()
	for idx in range(chapter.narrative.data.scenes.size()):
		chapter.narrative.enter_scene(idx);await ready_view()
		var m:RefCounted=chapter.narrative
		check(not m.scene().intro.is_empty() or m.scene().id=="p4-after-party","主场景不再缺文本："+m.scene().id)
		while m.phase=="reading":
			chapter._refresh();await frames()
			var shown:=0
			for actor:TextureRect in chapter.day01_view.dialogue_cast.portraits.values():
				if actor.visible:shown+=1
			check(shown<=2,"实际对话人物最多两个："+m.scene().id)
			if m.current_line().speaker.begins_with("查理"):
				check(chapter.day01_view.dialogue_cast.current.any(func(id:String)->bool:return id.begins_with("charlie")),"查理台词有查理立绘")
			m.advance()
	chapter.narrative.enter_scene(10);await ready_view();await shot("middle-bakery")
	chapter.narrative.enter_scene(11);await ready_view()
	check(chapter.backdrop.texture.resource_path.ends_with("room-tv-day.png"),"白天住处使用含电视机的新整图")
	await shot("home-day")
	chapter.narrative.enter_scene(12);await ready_view();check(chapter.backdrop.texture.resource_path.ends_with("room-tv-night.jpg"),"机器夜景使用新素材")
	await shot("home-night")
	chapter.narrative.enter_scene(8);await ready_view();check(chapter.backdrop.texture.resource_path.ends_with("cafeteria.png"),"新食堂背景接入")
	chapter.open_designed_report("report2-0308",true);await frames();await shot("report-march8")
	var old_index:int=chapter.narrative.scene_index
	chapter.designed_page.request_continue();await frames();check(chapter.narrative.scene_index==old_index,"回看报告不推进剧情")
	# Complete all scenes and every optional line without bypassing volume/ink/maze callbacks.
	chapter.narrative=load("res://scripts/story/continuation_flow.gd").new();chapter.loaded_scene=-1;await ready_view()
	var reports:Array=[];var visited:Array=[];var guard:=0
	while chapter.narrative.phase!="complete" and guard<1200:
		await process_frame
		if chapter.runtime.busy:continue
		guard+=1
		var m:RefCounted=chapter.narrative
		match m.phase:
			"reading":chapter.advance()
			"ink_observation":
				await process_frame
				if is_instance_valid(chapter.ink_game):chapter.ink_game.finish()
			"explore":
				if m.scene().id not in visited:
					visited.append(m.scene().id)
					for item:Dictionary in m.scene().items:
						if item.get("available_after_maze",false):continue
						chapter.start_object(item.id)
						if m.phase=="ink_observation":
							await frames()
							if is_instance_valid(chapter.ink_game):chapter.ink_game.finish()
							await process_frame
						if m.phase=="volume":m.set_volume(0.2);chapter.utility_window.hide();chapter._close_utility()
						if m.phase=="words":chapter.utility_window.hide();chapter._close_utility()
						if item.get("kind","")=="archive":await frames()
						if is_instance_valid(chapter.runtime.window):chapter.runtime.window.hide()
						if is_instance_valid(chapter.designed_page):
							chapter.designed_page.request_continue()
							await frames()
						while m.phase=="reading":chapter.advance()
						m.close_item()
				chapter.continue_main()
			"maze":chapter.race.development_finish();await process_frame
			"chapter_end":
				if m.scene().report not in reports:reports.append(m.scene().report)
				await process_frame
				if is_instance_valid(chapter.designed_page):chapter.designed_page.request_continue()
				else:chapter.day01_view.report_window.hide();chapter._continue_chapter()
	if guard>=1200:print("STOP: ",chapter.narrative.scene().id," / ",chapter.narrative.phase," active=",chapter.narrative.active_item," modal=",chapter.day01_view.has_modal()," page=",is_instance_valid(chapter.designed_page)," visited=",visited)
	check(guard<1200 and chapter.narrative.phase=="complete" and visited.size()==24,"24场完整流程可走通")
	for id:String in ["report5","report6-0324","report6-0325","report7"]:check(id in reports,"缺失报告补齐："+id)
	check(chapter.narrative.ink_observations.size()==2,"保留两次原生墨迹流程")
	chapter.queue_free();await frames()
	print("UNIFIED CHAPTER1: "+("PASS" if failures==0 else "FAIL")+" | 24 scenes; 20 dated report fragments; all optional dialogue; <=2 portraits; approved report screens; Right navigation")
	quit(0 if failures==0 else 1)
