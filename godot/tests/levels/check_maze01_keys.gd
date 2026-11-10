extends "res://tests/levels/check_maze_01_greybox.gd"

const Level := preload("res://scenes/levels/maze_01_greybox.tscn")
const Keys := preload("res://modules/maze_keys/maze01_gate_keys.gd")
const Rabbit := preload("res://modules/maze_items/maze_item_controller.gd")
var items
var inventory
var pickup_points: Dictionary = {}

func run() -> void:
	Input.use_accumulated_input = false
	root.size = Vector2i(1440, 960)
	scene = Level.instantiate()
	root.add_child(scene)
	actor = scene.get_node("%Player")
	generator = scene.get_node("%GeneratedMaze")
	items = scene.get_node("MazeItems")
	inventory = items.inventory
	var input_camera := Camera3D.new()
	actor.get_parent().add_child(input_camera)
	actor.movement_camera = input_camera
	await ticks(75)
	var spawn := actor.position
	check(generator.switches.is_empty() and generator.gates.size() == 4, "All four old switches are absent from Maze 01")
	check(items.key_pickups.size() == 4 and items._routes.ready, "Four pickups share the existing navigation and inventory")
	for id: String in Keys.GATES:
		var pickup: Area3D = items.key_pickups[id]
		pickup_points[id] = pickup.position
		var start_y: float = pickup._display.position.y
		var start_turn: float = pickup._display.rotation.y
		await ticks(16)
		check(not is_equal_approx(start_y, pickup._display.position.y) and not is_equal_approx(start_turn, pickup._display.rotation.y), "Hover and rotation " + id)
		check(pickup.collision_layer == 0 and pickup.find_children("*", "PhysicsBody3D", true, false).is_empty(), "Pickup has no blocking body " + id)
		check(pickup._pool.visible and not pickup._sparkles.is_empty(), "Pickup has a floor glow and sparkles " + id)
	check(reachable(spawn, pickup_points.D1) and not reachable(spawn, approach("D3")), "Starting coin is accessible before the route bottleneck")
	generator.gates.D1.set_open_state(true)
	await ticks(5)
	for id: String in ["D2", "D3", "D4"]:
		check(reachable(spawn, pickup_points[id]), "Other pickups remain reachable while the later gates are closed: " + id)
	generator.gates.D1.set_open_state(false)
	await ticks(5)
	await place(approach("D1"))
	check(scene.get_node("%Status").text.contains("需要一枚幸运钱币"), "A closed door displays its actual requirement")
	await tap_e()
	check(not generator.gates.D1.is_open, "Empty inventory cannot unlock the entrance")

	await place(spawn)
	await walk_to(pickup_points.D1 + Vector3(0, 0, 1.1), "Approach the first coin", false)
	await ticks(13)
	check(items.key_pickups.D1._near > 0.38 and scene.get_node("%Status").text.contains("靠近拾取"), "A nearby pickup brightens and displays a hint")
	await snapshot("01_coin", pickup_points.D1, Vector3(0, 1.60, 1.65))
	await walk_to(pickup_points.D1, "Walk through the first coin sensor", false)
	check(inventory.quantity(Keys.COIN) == 1, "A physical approach grants one coin")
	await place(pickup_points.D3)
	check(inventory.quantity(Keys.COIN) == 2 and inventory.get_node("LuckyCoin").text.ends_with("×2"), "Both coin pickups stack in the same slot")
	await ticks(30)
	await place(pickup_points.D3)
	check(inventory.quantity(Keys.COIN) == 2, "Collected coins never regrant on reentry")
	await place(approach("D4"))
	await tap_e()
	check(not generator.gates.D4.is_open and inventory.quantity(Keys.COIN) == 2, "A coin cannot be spent on a horseshoe door")
	await place(pickup_points.D4 + Vector3(-1.08, 0, 0))
	if OS.get_cmdline_user_args().has("--capture"):
		await ticks(95)
	await snapshot("02_horseshoe", pickup_points.D4, Vector3(-1.55, 1.56, 0.32))
	await place(pickup_points.D4)
	await place(pickup_points.D2)
	check(inventory.quantity(Keys.HORSESHOE) == 2 and inventory.get_node("LuckyHorseshoe").text.ends_with("×2"), "Both horseshoes share their own slot")
	check(inventory.get_node("UseItem").disabled, "Passive keys do not claim the rabbit's Use button")

	# Change the order with test positioning to prove the keys are interchangeable.
	await open_and_check("D3", Keys.COIN, 1)
	await open_and_check("D1", Keys.COIN, 0)
	await walk_to(generator.gates.D1.to_global(Vector3(0, 0, -1.08)), "Walk across the fully opened entrance", false)
	await open_and_check("D2", Keys.HORSESHOE, 1)
	await open_and_check("D4", Keys.HORSESHOE, 0)
	generator.gates.D2.set_open_state(false)
	await ticks(5)
	check(scene.can_finish() and reachable(spawn, Layout.cell_point([0, 18])), "The unlocked maze still leads to the original exit with the optional shortcut closed")
	await place(Layout.cell_point([0, 18]))
	check(scene.completed, "The real exit trigger completes the new key progression")

	scene.reset_level()
	await ticks(8)
	check(not scene.completed and inventory.quantity(Keys.COIN) == 0 and inventory.quantity(Keys.HORSESHOE) == 0, "Reset clears the key inventory and completion")
	for id: String in Keys.GATES:
		check(not generator.gates[id].is_open and is_instance_valid(items.key_pickups[id]), "Reset restores gate and pickup " + id)
	await place(Rabbit.PICKUP_POINT)
	check(inventory.quantity(Rabbit.RABBIT) == 1 and not inventory.get_node("UseItem").disabled, "Rabbit uses the same inventory and still has its own active button")
	release()
	scene.queue_free()
	await process_frame
	print("MAZE 01 GATE KEYS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)

func reachable(from: Vector3, to: Vector3) -> bool:
	return items._routes.path_to_nearest(from, PackedVector3Array([to])).size() > 1

func approach(id: String) -> Vector3:
	return generator.gates[id].to_global(Vector3(0, 0, 1.10))

func place(point: Vector3) -> void:
	actor.position = point + Vector3.UP * 0.04
	actor.velocity = Vector3.ZERO
	await ticks(7)

func tap_e() -> void:
	key(KEY_E, true)
	await ticks(1)
	key(KEY_E, false)
	await ticks(2)

func open_and_check(id: String, item: StringName, remaining: int) -> void:
	await place(approach(id))
	check(scene._nearest_key_gate() == id and scene.get_node("%Status").text.contains("E · 使用"), "Correct door and item prompt " + id)
	var gate: Node3D = generator.gates[id]
	var collider: CollisionShape3D = gate.leaf.get_node("GateCollision")
	var finish = gate.get_node("DreamGateFinish")
	await tap_e()
	check(gate.is_open and inventory.quantity(item) == remaining and gate.has_node("KeyTransfer"), "E starts one unlock and spends one key " + id)
	check(not collider.disabled and is_zero_approx(gate.leaf.position.y), "Charge happens while the door still blocks " + id)
	await tap_e()
	check(inventory.quantity(item) == remaining, "Repeat input does not spend again " + id)
	await ticks(roundi(gate.opening_lead_time * 60.0 * 0.50))
	var elapsed: float = finish.inlay.get_shader_parameter("elapsed")
	check(elapsed > 0.0 and elapsed < 0.60, "Inlay is partway through its sequenced charge " + id)
	check(not finish.dust[0].emitting, "Stone dust waits for floor contact " + id)
	if id == "D1":
		await snapshot("03_symbol_charging", gate.position, Vector3(0.42, 1.58, 1.72))
	await ticks(roundi((gate.opening_lead_time * 0.50 + gate.descent_duration * 0.78) * 60.0))
	check(gate.leaf.position.y < -0.3 and not collider.disabled and finish.dust[0].emitting, "Weighted descent and floor dust before collision clears " + id)
	if id == "D1":
		await snapshot("04_door_descends", gate.position, Vector3(0.42, 1.58, 1.72))
	await ticks(28)
	check(collider.disabled and not gate.panel.visible and scene.get_node("%Status").text.contains("通道已解锁"), "Gate stays open with the collision cleared " + id)
	await tap_e()
	check(inventory.quantity(item) == remaining, "An open door cannot consume another item " + id)

func snapshot(id: String, point: Vector3, offset: Vector3) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	var camera := Camera3D.new()
	actor.get_parent().add_child(camera)
	camera.fov = 55.0
	camera.look_at_from_position(point + offset, point + Vector3.UP * 0.95)
	camera.make_current()
	actor.visual.hide()
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../.verification/maze01-keys")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(id + ".png")) == OK, "Capture " + id)
	actor.visual.show()
	camera.free()
	scene.get_node("%FollowRig").camera.make_current()
