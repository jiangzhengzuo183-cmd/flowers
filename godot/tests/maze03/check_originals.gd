extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for path: String in ["res://scenes/levels/maze_01_greybox.tscn","res://scenes/levels/Maze02.tscn"]:
		var scene: Control=load(path).instantiate()
		root.add_child(scene)
		for i in 30:await process_frame
		print("ORIGINAL ",path," loaded=",scene.loaded_ok)
		scene.queue_free()
		for i in 30:await process_frame
	quit()
