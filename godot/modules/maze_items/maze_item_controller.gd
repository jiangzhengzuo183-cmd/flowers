extends Node
## Scene-local pickup, inventory and guide lifecycle. The level owns reset and exit rules.

const Inventory := preload("res://modules/maze_items/maze_inventory.gd")
const Pickup := preload("res://modules/maze_items/rabbit_pickup.gd")
const Routes := preload("res://modules/maze_items/walkable_routes.gd")
const Wisp := preload("res://modules/maze_items/route_wisp.gd")
const Icon := preload("res://modules/maze_items/rabbit_foot_icon.svg")
const Chime := preload("res://modules/maze_items/rabbit_pickup.wav")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const RABBIT := &"LuckyRabbitFoot"
const PICKUP_POINT := Vector3(39.60, 0.0, 39.60)
const PICKUP_PREVIEW := PICKUP_POINT + Vector3(-2.15, 0.0, 0.0)
const LEAD := 2.45
const REPLAN_INTERVAL := 0.35

var inventory: Inventory
var _actor: CharacterBody3D
var _world: Node3D
var _routes := Routes.new()
var _destinations := PackedVector3Array()
var _gates: Dictionary
var _switch_stops: Dictionary = {}
var _pickup: Pickup
var _guide: Wisp
var _sound: Callable
var _use_pending := false
var _duration: float
var _distance: float
var _remaining := 0.0
var _replan := 0.0
var _last_target := Vector3.INF
var _stop_point := Vector3.INF

func install(hud: VBoxContainer, actor: CharacterBody3D, architecture: Node3D, gates: Dictionary,
		exits: Array[Area3D], required_gates: Array, seconds: float, distance: float, pickup_sound: Callable) -> void:
	name = "MazeItems"
	_actor = actor
	_world = actor.get_parent()
	_duration = seconds
	_distance = distance
	_gates = gates
	_sound = pickup_sound
	hud.add_child(self)
	inventory = Inventory.new()
	inventory.name = "MazeInventory"
	hud.add_child(inventory)
	hud.move_child(inventory, hud.get_node("WalkControls").get_index())
	inventory.register_item(RABBIT, "幸运兔脚", Icon)
	inventory.use_requested.connect(_request_use)
	for exit: Area3D in exits:
		_destinations.append(exit.global_position)
		exit.body_entered.connect(_exit_entered)
	for door: Dictionary in Layout.config().doors:
		if door.id in required_gates:
			var point := Layout.cell_point(door.switch_cell)
			point.y = Layout.height_at(Vector2(point.x, point.z))
			_switch_stops[door.id] = point
	_routes.configure(actor, architecture, gates)
	_spawn_pickup()

func reset_items() -> void:
	cancel_guide()
	if is_instance_valid(_pickup):
		_pickup.queue_free()
	inventory.clear_items()
	_spawn_pickup()

func cancel_guide() -> void:
	_use_pending = false
	_remaining = 0.0
	if is_instance_valid(_guide):
		_guide.dissolve()

func _spawn_pickup() -> void:
	_pickup = _spawn_rabbit(PICKUP_POINT)

func _spawn_rabbit(point: Vector3) -> Pickup:
	var rabbit := Pickup.new()
	rabbit.name = "LuckyRabbitFoot"
	rabbit.actor = _actor
	rabbit.position = point
	rabbit.collected.connect(_picked_up)
	_world.add_child(rabbit, true)
	return rabbit

func _picked_up() -> void:
	inventory.grant(RABBIT)
	_sound.call(Chime)

func _request_use(id: StringName) -> void:
	if id == RABBIT and inventory.quantity(id) > 0:
		_use_pending = true

func _physics_process(delta: float) -> void:
	if not _routes.ready:
		_routes.build_batch()
	if _use_pending:
		_use_pending = false
		_activate()
	if not is_instance_valid(_guide) or _guide.fading:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_finish_guide("幸运兔脚的引路效果已结束")
		return
	if not _actor.controls_enabled:
		return
	var feet := _actor.global_position
	if feet.distance_to(_stop_point) < 0.65 and _routes.can_step(feet, _stop_point):
		_finish_guide("蓝色光团的提示到这里")
		return
	_replan -= delta
	if _replan <= 0.0:
		_replan = REPLAN_INTERVAL
		_replan_guide()
	if not _guide.advance(delta, _routes.can_step):
		_last_target = Vector3.INF

func _activate() -> void:
	if not _actor.controls_enabled:
		inventory.show_notice("返回行走视角后可使用")
		return
	if is_instance_valid(_guide):
		inventory.show_notice("蓝色光团正在引路")
		return
	if not _routes.ready:
		inventory.show_notice("正在确认迷宫通路，请稍后再试")
		return
	var path := _routes.path_to_nearest(_actor.global_position, _destinations)
	var distance := _distance
	if path.size() > 1:
		distance = minf(distance, _length(path) - 0.95)
	else:
		var switches := PackedVector3Array()
		for id: String in _switch_stops:
			if not _gates[id].is_open:
				switches.append(_switch_stops[id])
		path = _routes.path_to_nearest(_actor.global_position, switches)
	if path.size() < 2 or minf(distance, _length(path)) < 0.90:
		inventory.show_notice("这里暂无可提示的前路，兔脚已保留")
		return
	var segment := _limited_path(path, distance)
	if not inventory.consume(RABBIT):
		return
	_guide = Wisp.new()
	_guide.name = "BlueRouteWisp"
	_guide.position = path[0]
	_world.add_child(_guide)
	_remaining = _duration
	_replan = REPLAN_INTERVAL
	_stop_point = segment[-1]
	var lead := _limited_path(segment, LEAD)
	_last_target = lead[-1]
	_guide.follow(lead)
	inventory.show_notice("跟上蓝色光团，它会提示前面一小段")

func _replan_guide() -> void:
	var path := _routes.path_to_nearest(_actor.global_position, PackedVector3Array([_stop_point]))
	if path.size() < 2:
		_guide.follow(PackedVector3Array())
		_last_target = Vector3.INF
		return
	var target := _limited_path(path, LEAD)[-1]
	if target.distance_to(_last_target) < 0.22:
		return
	var movement := _routes.path_to_nearest(_guide.global_position, PackedVector3Array([target]))
	_last_target = target if not movement.is_empty() else Vector3.INF
	_guide.follow(movement)

func _limited_path(path: PackedVector3Array, distance: float) -> PackedVector3Array:
	var lead := PackedVector3Array([path[0]])
	for i in range(1, path.size()):
		var step := path[i-1].distance_to(path[i])
		if step >= distance:
			lead.append(path[i-1].lerp(path[i], distance / step))
			break
		lead.append(path[i])
		distance -= step
	return lead

func _length(path: PackedVector3Array) -> float:
	var distance := 0.0
	for i in range(1, path.size()):
		distance += path[i-1].distance_to(path[i])
	return distance

func _exit_entered(body: Node3D) -> void:
	if body == _actor and is_instance_valid(_guide) and not _guide.fading:
		_finish_guide("蓝色光团已抵达出口")

func _finish_guide(message: String) -> void:
	_guide.dissolve()
	inventory.show_notice(message)
