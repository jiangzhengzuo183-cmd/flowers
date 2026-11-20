extends SceneTree
const Book := preload("res://scripts/story/report_book.gd")
var screenshots := ProjectSettings.globalize_path("res://").path_join("../.verification/native-report-book").simplify_path()+"/"
var book: Control

func _initialize() -> void:
	root.size=Vector2i(1600,900)
	_run.call_deferred()

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(screenshots+name+".png")!=OK:
		push_error("Native screenshot failed")
		quit(1)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(screenshots)
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/report_book_catalog.json"))
	var ids: Array=[]
	for entry: Dictionary in catalog.entries:
		ids.append(entry.id)
		if entry.id=="report9":break
	book=Book.new();book.request={"mode":"review","currentReport":"report1","unlocked":ids};root.add_child(book)
	await create_timer(0.4,true).timeout
	await capture("closed")
	book.frame.open_cover()
	await create_timer(0.6,true).timeout
	await capture("opening")
	await create_timer(0.8,true).timeout
	assert(book.frame.phase=="reading")
	await capture("march3")
	book.frame._flip(1)
	await create_timer(0.45,true).timeout
	await capture("turning")
	await create_timer(0.6,true).timeout
	assert(book.frame.current==1)
	assert(book.frame.get_children().filter(func(n: Node) -> bool:return n is Button).size()==2)
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	click.position=Vector2(400,400);book.frame._gui_input(click)
	await create_timer(1.0,true).timeout
	assert(book.frame.current==0)
	click.position=Vector2(1100,400)
	book.frame._gui_input(click);book.frame._gui_input(click);book.frame._gui_input(click)
	await create_timer(1.0,true).timeout
	assert(book.frame.current==1,"Rapid page clicks must produce only one turn")
	root.size=Vector2i(1280,720)
	await create_timer(0.2,true).timeout
	assert(is_equal_approx(book.frame.scale.x,0.8) and is_equal_approx(book.frame.scale.y,0.8))
	root.size=Vector2i(1600,900)
	await create_timer(0.2,true).timeout
	for id: String in ["03-29"]:
		for i in book.frame.reports.size():
			if book.frame.reports[i].id==id:
				book.frame.current=i;book.frame.target=i;book.frame._page(i,"left");book.frame._page(i,"right");book.frame.queue_redraw()
		await create_timer(0.2,true).timeout
		await capture(id)
	var completed: Array=[]
	book.finished.connect(func(status: String) -> void:completed.append(status))
	book.frame._action()
	await create_timer(0.6,true).timeout
	await capture("closing")
	await create_timer(0.8,true).timeout
	assert(completed==["closed"])
	assert(not paused)
	book.queue_free()
	await process_frame
	book=Book.new();book.request={"mode":"story","currentReport":"report3","unlocked":["report3"]};root.add_child(book)
	await create_timer(1.5,true).timeout
	assert(book.frame.leaves["03-16_03-17_照片-right"].content.is_empty())
	assert(not book.frame.leaves["03-16_03-17_照片-left"].content.is_empty())
	assert(book.frame.reports.size()==1)
	await capture("partial-march16")
	book.queue_free()
	await process_frame
	print("PASS native Godot book through report 9: opening/closing shadows, forward/back page clicks, rapid clicks, resize, partial unlocks, pause restoration")
	quit()
