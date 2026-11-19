extends Node
## Developer measurement only: no opponent, countdown, victory or racing HUD.
const OUTPUT := "user://stamina_tests/maze03.csv"
const COLUMNS := ["utc", "route", "mode", "seconds", "stamina_remaining", "sprint_seconds", "exhaustions", "barrier_recoveries", "chapel_visited", "court_visited", "mode_valid"]
var output_path := OUTPUT
var scene: Node
var actor: CharacterBody3D
var start_trigger: Area3D
var finish_trigger: Area3D
var route_id := "A"
var test_mode := "walk"
var armed := false
var running := false
var elapsed := 0.0
var last_result: Dictionary = {}
var previous_position := Vector3.ZERO
var baseline_sprint := 0.0
var baseline_exhaustions := 0
var baseline_barriers := 0

func install(level: Node) -> void:
	scene = level
	actor = scene.get_node("%Player")
	process_physics_priority = 30
	start_trigger = _marker("TimingStart", scene.maze_data.openings.entry.cell)
	finish_trigger = _marker("TimingFinish", scene.maze_data.openings.exit.cell)
	finish_trigger.body_entered.connect(func(body: Node3D):
		if body == actor:
			finish())
	actor.stamina.session_reset.connect(cancel)
	var menu := MenuButton.new()
	menu.name = "StaminaRouteTimingTools"
	menu.text = "路线测时（开发）"
	var popup := menu.get_popup()
	for route: String in ["A", "B"]:
		for mode: String in ["步行", "合理冲刺", "尽量持续冲刺"]:
			popup.add_item(route + " · " + mode)
	popup.add_separator()
	popup.add_item("取消本次测时", 6)
	popup.id_pressed.connect(_selected)
	scene.get_node("WalkControls").add_child(menu)

func _marker(id: String, cell: Array) -> Area3D:
	var area := Area3D.new()
	area.name = id
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = Vector3((float(cell[1])+0.5)*2.4, 0.8, (float(cell[0])+0.5)*2.4)
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 2.2, 1.9)
	var shape := CollisionShape3D.new()
	shape.shape = box
	area.add_child(shape)
	actor.get_parent().add_child(area)
	return area

func _selected(id: int) -> void:
	if id == 6:
		cancel()
		return
	arm("A" if id < 3 else "B", ["walk", "managed", "maximum"][id % 3])

func arm(route: String, mode: String) -> void:
	if route not in ["A", "B"] or mode not in ["walk", "managed", "maximum"]:
		return
	scene.reset_walk()
	scene.set_walk_mode(true)
	scene.select_route(route)
	route_id = route
	test_mode = mode
	elapsed = 0.0
	last_result.clear()
	previous_position = actor.global_position
	baseline_sprint = actor.stamina.sprint_seconds
	baseline_exhaustions = actor.stamina.exhaustion_count
	baseline_barriers = int(actor.stamina.restore_counts.get(&"barrier", 0))
	armed = true
	scene.get_node("%Status").text = "测时已准备：%s / %s。入口开始移动时自动计时，到出口记录结果。" % [route_id, test_mode]

func cancel() -> void:
	armed = false
	running = false
	elapsed = 0.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	var distance := Vector2(actor.global_position.x-previous_position.x, actor.global_position.z-previous_position.z).length()
	previous_position = actor.global_position
	var active: bool = actor.controls_enabled and not actor.visual.celebrating
	if armed and active and start_trigger.overlaps_body(actor) and distance > 0.0005 and distance < 0.5:
		armed = false
		running = true
	if running and active:
		elapsed += delta

func finish() -> void:
	if not running:
		return
	running = false
	var stamina = actor.stamina
	var sprint: float = stamina.sprint_seconds-baseline_sprint
	last_result = {"utc":Time.get_datetime_string_from_system(true), "route":route_id, "mode":test_mode,
		"seconds":snappedf(elapsed, 0.001), "stamina_remaining":snappedf(stamina.current, 0.01),
		"sprint_seconds":snappedf(sprint, 0.001), "exhaustions":stamina.exhaustion_count-baseline_exhaustions,
		"barrier_recoveries":int(stamina.restore_counts.get(&"barrier", 0))-baseline_barriers,
		"chapel_visited":&"chapel" in stamina.visited_zones, "court_visited":&"statue_court" in stamina.visited_zones,
		"mode_valid":test_mode != "walk" or sprint < 0.01}
	_write_result()
	scene.get_node("%Status").text = "测时已记录：路线 %s / %s · %.2f 秒 · 剩余体力 %.1f。" % [route_id, test_mode, elapsed, stamina.current]
	print("STAMINA ROUTE RESULT ", JSON.stringify(last_result), " file=", ProjectSettings.globalize_path(output_path))

func _write_result() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
	var exists := FileAccess.file_exists(output_path)
	var file := FileAccess.open(output_path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if file == null:
		push_error("Cannot write route timing CSV: " + str(FileAccess.get_open_error()))
		return
	if exists:
		file.seek_end()
	else:
		file.store_csv_line(PackedStringArray(COLUMNS))
	var values := PackedStringArray()
	for column: String in COLUMNS:
		values.append(str(last_result[column]))
	file.store_csv_line(values)
	file.close()
