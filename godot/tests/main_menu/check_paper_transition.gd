extends SceneTree
var novel: Control
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720)
	novel=load("res://modules/visual_novel/VisualNovel.tscn").instantiate()
	root.add_child(novel)
	current_scene=novel
	await frames(12)
	var day: Control=novel.story.bakery
	day.runtime.focused=true
	day.flow.section="home"
	day.flow._begin(day.flow.data.home)
	day._refresh()
	await frames(4)
	print("PAPER_HOME_BEGIN lines=",day.flow.queue.size())
	while day.flow.phase=="reading":
		print("PAPER_LINE ",day.flow.index," ",day.flow.current_line().text)
		day.runtime.letters=100000
		day.runtime._process(0.0)
		await frames(5)
		day.runtime.request_advance()
		await frames(5)
	print("PAPER_AFTER_MONOLOGUE ",day.flow.phase)
	await frames(150)
	print("REPORT_INSTANCE ",is_instance_valid(day.report_book))
	if is_instance_valid(day.report_book):
		print("REPORT_FRAME_PHASE ",day.report_book.frame.phase)
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.verification/story-handoff/paper-report-open.png"))
		day.report_book.frame._action()
		await frames(150)
	print("AFTER_REPORT old_flow=",day.flow.phase if is_instance_valid(day) else "released")
	var next: Control=novel.story.bakery
	print("PAPER_TRANSITION_RESULT next=",next.get_script().resource_path)
	var passed: bool=next.get_script().resource_path.ends_with("continuation_chapter.gd")
	print("PAPER_TRANSITION_PASS=",passed)
	quit(0 if passed else 1)
