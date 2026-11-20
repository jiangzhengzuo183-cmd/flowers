extends SceneTree
var novel: Control
var day: Control
var steps:=0
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func finish_reading() -> void:
	while is_instance_valid(day) and day.flow.phase=="reading" and steps<400:
		steps+=1
		await frames(3)
		day.runtime.letters=100000
		day.runtime.focused=true
		day.runtime._process(0.0)
		day.runtime.request_advance()
		await frames(3)
func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720)
	root.position=Vector2i(-2600,-1800)
	novel=load("res://modules/visual_novel/VisualNovel.tscn").instantiate()
	root.add_child(novel)
	current_scene=novel
	await frames(8)
	day=novel.story.bakery
	await finish_reading()
	print("DAY01_PEOPLE ",day.flow.phase)
	for id in ["gimpy","karp","donner"]:
		day.start_talk(id)
		await finish_reading()
	day.continue_main()
	print("DAY01_OBJECTS ",day.flow.phase)
	for id in ["bread","orders","notebook"]:
		day.start_object(id)
		await finish_reading()
	day.continue_main()
	await finish_reading()
	await frames(110)
	print("DAY01_REPORT ",day.flow.phase," reading_steps=",steps)
	if not is_instance_valid(day.report_book):
		push_error("DAY01 did not reach the new report book")
		quit(1)
		return
	day.report_book.frame._action()
	await frames(130)
	var next: Control=novel.story.bakery
	var passed: bool=steps<400 and next.get_script().resource_path.ends_with("continuation_chapter.gd")
	print("DAY01_COMPLETE_PASS=",passed," next_scene=",next.narrative.scene().id if passed else "failed")
	novel.queue_free()
	await frames(4)
	for child in root.get_children(): child.queue_free()
	await frames(4)
	quit(0 if passed else 1)
