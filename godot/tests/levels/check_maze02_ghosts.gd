extends SceneTree
## Actual physics/scene integration regression; run with --fixed-fps 60.
const SELECT := preload("res://scenes/levels/MazeSelect.tscn")
const Ghost := preload("res://modules/maze02_ghosts/ghost_actor.gd")
const SourceMaterial := preload("res://art/maze02/memory_shade/MemoryShadeMaterial.tres")
var failures := 0
var transitions: Array[int] = []
var bridge_requests := 0
var finished := 0
var dissolve_finishes := 0

func _initialize() -> void:
	call_deferred("run")
func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error(description)
func ticks(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func clear_body(body: CharacterBody3D) -> bool:
	var collider := body.get_node("Body") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.collision_mask = 1
	query.transform = collider.global_transform.translated(Vector3.UP * 0.04)
	return body.get_world_3d().direct_space_state.intersect_shape(query).is_empty()

func run() -> void:
	var selector := SELECT.instantiate()
	root.add_child(selector)
	selector.get_node("%Maze02").pressed.emit()
	await ticks(210)
	var level: Node = selector.get_node("%LevelHost").get_child(0)
	var actor: CharacterBody3D = level.get_node("%Player")
	var event: Node3D = actor.get_parent().get_node("Maze02GhostEvent")
	var church: CharacterBody3D = event.church
	var bridge: CharacterBody3D = event.bridge
	var dissolve: Node3D = church.get_node("WindDissolve")
	var before_material: Variant = SourceMaterial.get_shader_parameter("body_color")
	check(level.loaded_ok and event.visible, "Maze02 installs its independent ghost event")
	check(level._key_items.guidance_routes().ready, "Existing collision-derived navigation is ready")
	check(event.find_children("Ghost_*", "CharacterBody3D", false, false).size() == 2, "Exactly two ghosts")
	check(church.shade.scene_file_path == bridge.shade.scene_file_path and church.shade.scene_file_path.ends_with("/memory_shade/MemoryShade.tscn"), "Both reuse the finished MemoryShade scene")
	check(church.shade.surface_material != bridge.shade.surface_material and church.shade.surface_material != SourceMaterial, "Ghost materials are instance-owned")
	check(church.shade.opacity > 0.24 and church.shade.surface_material.get_shader_parameter("body_color").b > church.shade.surface_material.get_shader_parameter("body_color").r * 4, "Ghosts have stronger blue and opacity")
	check(church.is_on_floor() and bridge.is_on_floor() and clear_body(church) and clear_body(bridge), "Ghost feet are grounded and capsules clear the book, walls and bridge")
	check(not event.has_node("AtlasGlobeEffect") and not dissolve.active and dissolve.cloud == null, "No globe effect; farewell particles remain dormant before arrival")
	check(event.find_children("*", "Control", true, false).is_empty(), "No dialogue UI or placeholder text")
	check(actor.get_parent().find_children("*", "WorldEnvironment", true, false).size() == 1, "No extra environment")
	print("GHOST_PLACEMENTS church=", church.global_position, " bridge=", bridge.global_position)
	church.state_changed.connect(func(_old: int, next: int): transitions.append(next))
	church.guidance_finished.connect(func(_ghost): finished += 1)
	bridge.dialogue_requested.connect(func(_ghost, _player): bridge_requests += 1)
	church.dissolved.connect(func(_ghost): dissolve_finishes += 1)
	level.set_walk_mode(true)
	actor.set_physics_process(false)
	var bridge_origin := bridge.transform
	actor.global_position = Vector3(39.75, 2.65, 15.65)
	await ticks(12)
	check(bridge_requests == 0, "Bridge approach cannot trigger through the overhead bridge slab")
	actor.global_position = Vector3(38.8, 0.04, 16.05)
	await ticks(15)
	check(bridge_requests == 1 and bridge.state == Ghost.State.Idle and bridge.transform.is_equal_approx(bridge_origin), "Bridge approach emits only the reserved signal; never moves or changes state")
	check(church.state == Ghost.State.Idle and not dissolve.active, "Bridge approach does not affect church or farewell")
	actor.global_position = Vector3(25.4, 0.04, 24.95)
	await ticks(22)
	check(church.state == Ghost.State.LookAtPlayer and church.approach_count == 1, "Physical Area detects the player once and looks before walking")
	check(not paused and actor.controls_enabled, "Player controls remain available, with no pause")
	await ticks(60)
	check(church.state == Ghost.State.WalkingToAtlas and church.route.size() >= 3, "Ghost starts its actual walk animation and collision-safe route")
	check(church.shade.player.current_animation.begins_with("walk"), "Existing walk animation is playing")
	# The player can move freely while the NPC walks; only this test injects a key.
	var player_before := actor.global_position
	actor.set_physics_process(true)
	Input.use_accumulated_input = false
	var movement := InputEventKey.new()
	movement.physical_keycode = KEY_D
	movement.pressed = true
	Input.parse_input_event(movement)
	await ticks(8)
	movement = InputEventKey.new()
	movement.physical_keycode = KEY_D
	movement.pressed = false
	Input.parse_input_event(movement)
	check(actor.global_position.distance_to(player_before) > 0.08, "Real player movement remains available during guidance")
	actor.set_physics_process(false)
	print("GUIDANCE_ROUTE ", church.route)
	for i in range(1, church.route.size()):
		check(level._key_items.guidance_routes().can_step(church.route[i-1], church.route[i]), "Route segment is traversable: " + str(i))
	var clean_path := true
	var travelled_without_teleport := true
	var previous := church.global_position
	for i in 1200:
		await ticks(1)
		clean_path = clean_path and clear_body(church)
		travelled_without_teleport = travelled_without_teleport and church.global_position.distance_to(previous) < 0.04
		previous = church.global_position
		if church.state == Ghost.State.Arrived:
			break
	check(church.state == Ghost.State.Arrived and finished == 1 and church.arrival_count == 1, "Ghost physically reaches Atlas exactly once")
	check(clean_path and travelled_without_teleport, "Entire movement stays clear of walls, never teleports or clips")
	check(church.global_position.distance_to(church._destination) < 0.08 and church.is_on_floor(), "Arrival matches stop point with grounded feet")
	check(church.shade.state == 2 and not dissolve.active, "Arrival first holds a quiet idle without a globe")
	await ticks(30)
	check(church.state == Ghost.State.Arrived and church.shade.visible, "Ghost pauses beside Atlas before dissolving")
	await ticks(60)
	check(church.state == Ghost.State.Dissolving and dissolve.active and dissolve.play_count == 1, "Arrival triggers one wind dissolution after a short hold")
	check(dissolve._points.size() == 260 and dissolve.cloud.multimesh.instance_count == 260
		and dissolve.glow_cloud.multimesh.instance_count == 260, "Light cores and soft halos originate on the existing posed character mesh")
	var low := INF
	var high := -INF
	for sample: Vector3 in dissolve._points:
		low = minf(low, sample.y)
		high = maxf(high, sample.y)
	check(low > -0.06 and high > 1.1 and high < 1.6, "Sampled points cover the full correctly grounded body")
	var point: Vector3 = dissolve.cloud.multimesh.get_instance_transform(0).origin
	await ticks(90)
	check(not church.shade.visible and dissolve.active and dissolve.cloud.visible, "Body disappears into lingering small grains")
	if DisplayServer.get_name() != "headless":
		check(dissolve.cloud.multimesh.get_instance_transform(0).origin.x > point.x + 0.3, "Rendered particle instances travel sideways with the scene's +X wind")
	await ticks(100)
	check(church.state == Ghost.State.Dissolved and dissolve.completed and not dissolve.cloud.visible
		and not dissolve.glow_cloud.visible and dissolve_finishes == 1, "Wind particles and halos fade completely and finish once")
	var to_statue: Vector3 = church._statue - church.global_position
	check(church.basis.z.normalized().dot(to_statue.normalized()) > 0.98, "Arrived ghost faces Atlas")
	church.begin_wind_dissolve()
	church.start_guidance()
	actor.global_position = Vector3(25.4, 0.04, 24.95)
	await ticks(12)
	check(church.approach_count == 1 and finished == 1 and dissolve.play_count == 1, "Repeated entry and calls never replay a completed event")
	check(bridge.transform.is_equal_approx(bridge_origin) and bridge.state == Ghost.State.Idle, "Bridge ghost remains independent throughout the event")
	check(SourceMaterial.get_shader_parameter("body_color") == before_material, "Original ghost material is unchanged")
	# Future dialogue mode: approach waits indefinitely, then resumes via the public method.
	actor.global_position = Vector3(1.2,0.04,44.4)
	level.reset_level()
	church.auto_start_guidance = false
	await ticks(8)
	actor.global_position = Vector3(25.4,0.04,24.95)
	await ticks(90)
	check(church.state == Ghost.State.LookAtPlayer and not dissolve.active, "Future dialogue mode waits without UI or movement")
	church.start_guidance()
	await ticks(5)
	check(church.state == Ghost.State.WalkingToAtlas, "Future completion signal can call start_guidance directly")
	var weak_event: WeakRef = weakref(event)
	selector.show_selection()
	await ticks(4)
	check(weak_event.get_ref() == null, "Scene switching frees ghosts, triggers and wind particles")
	selector.get_node("%Maze01").pressed.emit()
	await ticks(90)
	var first: Node = selector.get_node("%LevelHost").get_child(0)
	check(first.loaded_ok and not first.get_node("%Player").get_parent().has_node("Maze02GhostEvent"), "Maze01 still runs with no Maze02 ghosts or effect")
	selector.queue_free()
	await ticks(4)
	print("MAZE02_GHOSTS ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
