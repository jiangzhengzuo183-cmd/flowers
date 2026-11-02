extends SceneTree

const MazeLoader := preload("res://scripts/maze/maze_loader.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var loaded := MazeLoader.load_map()
	check(loaded.ok, "原始地图必须通过校验：" + str(loaded.get("error", "")))
	if not loaded.ok:
		quit(1)
		return
	check(loaded.metrics.walls == 378, "必须还原 378 段墙")
	check(loaded.metrics.reachable == 361, "所有 361 个格子必须可达")
	var damaged: Dictionary = loaded.data.duplicate(true)
	damaged.grid.verticalWalls.pop_back()
	check(not MazeLoader.validate(damaged).is_empty(), "必须拒绝损坏的墙体矩阵")
	damaged = loaded.data.duplicate(true)
	damaged.openings.entry.side = "south"
	check(not MazeLoader.validate(damaged).is_empty(), "必须拒绝封闭的入口")
	damaged = loaded.data.duplicate(true)
	damaged.routes.A.cellPath[1] = loaded.data.openings.exit.cell.duplicate()
	check(not MazeLoader.validate(damaged).is_empty(), "必须拒绝不连续路线")
	check(not MazeLoader.load_map("res://data/missing.json").ok, "缺少地图时必须返回错误")
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.active_id == "story", "默认进入剧情")
	var story: Control = game.active_scene
	story.advance()
	check(story.index == 1, "剧情必须能推进")
	story.restart()
	check(story.index == 0, "剧情必须能重读")
	story.advance()
	story.advance()
	story.advance()
	await process_frame
	check(game.active_id == "maze", "剧情结束必须进入迷宫")
	var maze_scene: Control = game.active_scene
	check(maze_scene.loaded_ok, "迷宫场景必须成功加载")
	var generated: Node3D = maze_scene.get_node("%GeneratedMaze")
	check(generated.wall_count == 378, "生成的墙数必须与数据一致")
	check(generated.marker_count == 5, "必须包含入口出口和三个检查点")
	check(generated.get_node("WallCollisions").get_child_count() == 378, "墙体必须有对应碰撞形状")
	check(not generated.route_nodes.A.visible and not generated.route_nodes.B.visible, "默认隐藏全部路线")
	maze_scene.select_route("A")
	check(generated.route_nodes.A.visible and not generated.route_nodes.B.visible, "路线 A 开关必须生效")
	maze_scene.select_route("B")
	check(not generated.route_nodes.A.visible and generated.route_nodes.B.visible, "路线 B 开关必须生效")
	var original_wall_color: Color = generated.wall_material.albedo_color
	maze_scene.set_soft_palette(true)
	check(generated.wall_material.albedo_color != original_wall_color, "柔和配色必须生效")
	maze_scene.set_soft_palette(false)
	check(generated.wall_material.albedo_color == original_wall_color, "必须能返回原始灰盒配色")
	var camera: Node3D = maze_scene.get_node("%CameraRig")
	var player: CharacterBody3D = maze_scene.get_node("%Player")
	check(maze_scene.walk_mode and player.controls_enabled, "进入迷宫默认可步行")
	var start_position := player.position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	for frame in range(30):
		await physics_frame
	key.pressed = false
	Input.parse_input_event(key)
	check(player.position.z < start_position.z - 0.5, "W 必须能沿入口的开放通道前进")
	maze_scene.reset_walk()
	key = InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	for frame in range(40):
		await physics_frame
	key.pressed = false
	Input.parse_input_event(key)
	check(player.position.x < 2.0, "入口东侧墙必须阻挡人物，不能穿墙")
	maze_scene.reset_walk()
	check(player.position.distance_to(player.spawn_point) < 0.01, "回到入口必须恢复出生点")
	maze_scene.set_walk_mode(false)
	check(not player.controls_enabled and camera.camera.current, "全图查看必须停用人物操作并切换镜头")
	maze_scene.set_walk_mode(true)
	var viewing_direction: Vector3 = (camera.camera.global_position - camera.to_global(camera.center)).normalized().abs()
	check(viewing_direction.is_equal_approx(Vector3.ONE.normalized()), "等距初始视角的三个世界轴必须均匀缩短")
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	camera.handle_input(wheel)
	check(camera.zoom > 1, "滚轮必须能缩放")
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(50, 10)
	camera.handle_input(drag)
	check(not is_equal_approx(camera.yaw, PI / 4.0), "拖动必须能旋转")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	camera.handle_input(release)
	check(is_zero_approx(fposmod(camera.yaw - PI / 4.0, PI / 2.0)), "松开鼠标后必须回到对称等距方向")
	camera.reset_view()
	check(is_equal_approx(camera.zoom, 1) and is_equal_approx(camera.yaw, PI / 4.0), "镜头必须能重置")
	for i in range(3):
		game.show_scene("story")
		await process_frame
		game.show_scene("maze")
		await process_frame
		check(game.get_node("%SceneHost").get_child_count() == 1, "场景切换后不能留下重复场景")
	game.queue_free()
	await process_frame
	print("GODOT CHECK: %s | 19x19, 378 walls, 361 reachable, routes 60/92 | story, markers, collisions, route visibility, camera, scene lifecycle" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
