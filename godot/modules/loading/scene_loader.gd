extends RefCounted
## Small routing API: begin -> fetch -> instantiate in the existing host -> finish.
const Screen := preload("res://modules/loading/loading_screen.gd")
const LOCK := &"paper_loading_screen"

static func begin(tree: SceneTree, owner: Node = null) -> CanvasLayer:
	if tree.has_meta(LOCK): return null
	var screen := Screen.new()
	tree.set_meta(LOCK, screen)
	if owner != null: owner.tree_exiting.connect(screen.queue_free, CONNECT_ONE_SHOT)
	tree.root.add_child.call_deferred(screen)
	return screen

static func fetch(screen: CanvasLayer, path: String) -> PackedScene:
	if not screen.is_node_ready(): await screen.ready
	var tree := screen.get_tree()
	# Finish the short reveal before heavy destination resources are requested.
	if not screen._revealed: await screen.revealed
	await tree.process_frame
	await tree.process_frame
	if not is_instance_valid(screen) or not screen.is_inside_tree(): return null
	var error := ResourceLoader.load_threaded_request(path, "PackedScene")
	if error != OK:
		push_error("Loading request failed: %s (%s)" % [path, error])
		return null
	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(path) as PackedScene
			if not is_instance_valid(screen) or not screen.is_inside_tree(): return null
			# Wait before mounting the destination so gameplay clocks do not run behind the paper.
			await screen.wait_for_display_time()
			return packed if is_instance_valid(screen) and screen.is_inside_tree() else null
		if status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			push_error("Loading scene failed: " + path)
			return null
		await tree.process_frame
	return null

static func finish(screen: CanvasLayer) -> void:
	if not is_instance_valid(screen) or not screen.is_inside_tree(): return
	var tree := screen.get_tree()
	await screen.finish()
	if tree.has_meta(LOCK) and tree.get_meta(LOCK) == screen:
		tree.remove_meta(LOCK)

static func change_scene(tree: SceneTree, path: String) -> Error:
	var screen := begin(tree)
	if screen == null: return ERR_BUSY
	var packed := await fetch(screen, path)
	var error := ERR_CANT_OPEN
	if packed != null:
		error = tree.change_scene_to_packed(packed)
		if error == OK: await tree.process_frame
	await finish(screen)
	return error
