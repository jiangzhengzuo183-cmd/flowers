extends SceneTree
func _initialize() -> void:
	root.size=Vector2i(1600,900)
	_open.call_deferred()
func _open() -> void:
	var ids: Array=[]
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/report_book_catalog.json")).entries:ids.append(entry.id)
	var book=load("res://scripts/story/report_book.gd").new()
	book.request={"mode":"review","currentReport":"report1","unlocked":ids}
	book.finished.connect(func(_status: String) -> void:quit())
	root.add_child(book)
