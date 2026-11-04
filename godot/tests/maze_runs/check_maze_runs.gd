extends SceneTree

const Base := preload("res://scenes/maze_runs/Maze01_Base.tscn")
const Preview := preload("res://scenes/maze_runs/maze_runs_preview.tscn")
const Config := preload("res://scripts/maze_runs/maze_run_config.gd")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
var failures := 0
var completions: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 3) -> void:
	for i in count:
		await physics_frame
		await process_frame

func geometry_signature(scene: Node) -> Array:
	var generated := scene.get_node("%GeneratedMaze")
	var signature: Array = []
	for mesh: MeshInstance3D in generated.find_children("*","MeshInstance3D",true,false):
		signature.append([stable_path(generated,mesh),mesh.transform,mesh.mesh.get_aabb(),mesh.mesh.get_surface_count()])
	for shape: CollisionShape3D in generated.find_children("*","CollisionShape3D",true,false):
		signature.append([stable_path(generated,shape),shape.transform,shape.shape.get_class()])
	return signature

func stable_path(ancestor: Node,node: Node) -> Array[int]:
	# Runtime-generated anonymous names contain process-wide instance counters.
	var indices: Array[int] = []
	while node!=ancestor:
		indices.push_front(node.get_index())
		node = node.get_parent()
	return indices

func gate_collision(scene: Node,id: String) -> CollisionShape3D:
	return scene.get_node("%GeneratedMaze").gates[id].leaf.get_node("GateCollision")

func capture_preview() -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../.verification/maze-runs")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join("three_runs_preview.png"))==OK,"Native preview capture")

func run() -> void:
	root.size = Vector2i(1280,900)
	var layout_before := JSON.stringify(Layout.config())
	var controller = Preview.instantiate()
	root.add_child(controller)
	await frames()
	var first = controller.active_run
	check(first.loaded_ok,"Default run loads shared base")
	await capture_preview()
	var expected_geometry := geometry_signature(first)
	check(expected_geometry.size()>500,"Generated space and collision signature is populated")
	var snapshot: Dictionary = first.get_run_state()
	snapshot.gates.D1 = true
	check(not first.get_run_state().gates.D1,"Returned state is a detached snapshot")
	check(first.try_activate_gate("D1"),"First run can operate D1")
	check(not first.try_activate_gate("UNKNOWN"),"Unknown gate is rejected")
	await frames()
	for index in [1,2,0]:
		var previous_id: int = controller.active_run.get_instance_id()
		check(controller.start_run(index),"Select run "+str(index+1))
		await frames()
		var current = controller.active_run
		check(current.get_instance_id()!=previous_id,"Switch creates a fresh instance")
		check(controller.get_node("%RunHost").get_child_count()==1,"Only one active run exists")
		check(current.scene_file_path=="res://scenes/maze_runs/Maze01_Base.tscn","Every run uses the same PackedScene")
		check(geometry_signature(current)==expected_geometry,"All three runs have identical mesh/collision structure")
		check(not current.get_run_state().gates.D1,"Gate changes do not leak between runs or revisits")
		check(current.get_run_state().run_id=="maze_run_0"+str(index+1),"Correct run identity")
	var old_id: int = controller.active_run.get_instance_id()
	controller.retry_run()
	await frames()
	check(controller.active_run.get_instance_id()!=old_id,"Retry replaces the whole runtime state")
	check(not controller.start_run(-1) and not controller.start_run(3),"Invalid run selection is harmless")
	check(controller.active_index==0,"Invalid selection preserves current run")
	controller.next_run()
	check(controller.active_index==0,"Cannot advance before completing")
	var default_profile: Resource = load("res://data/maze_runs/run_01.tres")
	var untouched: Dictionary = default_profile.snapshot()
	# Simultaneous instances use independent environments, gate state and animation libraries.
	var custom = Config.new()
	custom.run_id = "isolation"
	custom.initial_gate_states.D1 = true
	custom.gate_interaction_enabled.D3 = false
	custom.required_exit_gates.assign(["D2"])
	custom.sun_energy = 0.3
	var alternate = Base.instantiate()
	alternate.run_config = custom
	alternate.run_completed.connect(func(id: String,result: Dictionary): completions.append({"id":id,"result":result}))
	root.add_child(alternate)
	alternate.get_node("%Player").controls_enabled = false
	controller.active_run.get_node("%Player").controls_enabled = false
	await frames()
	check(alternate.get_run_state().gates.D1 and gate_collision(alternate,"D1").disabled,"Initial open state has no blocking leaf")
	check(not is_instance_valid(alternate.get_node("%GeneratedMaze").gates.D1.tween),"Initial open state is immediate")
	check(alternate.find_children("*","AudioStreamPlayer",true,false).is_empty(),"Initial open state is silent")
	check(not alternate.try_activate_gate("D3"),"Disabled gate interaction is enforced")
	check(not alternate.can_finish(),"Custom exit condition waits for D2")
	var env: Environment = alternate.get_node("%WorldEnvironment").environment
	var other_env: Environment = controller.active_run.get_node("%WorldEnvironment").environment
	check(env!=other_env,"Environments are instance-local")
	var original_background := other_env.background_color
	env.background_color = Color.RED
	check(other_env.background_color==original_background,"Environment edits do not leak")
	check(is_equal_approx(alternate.get_node("%Player").get_parent().get_node("Sun").light_energy,0.3),"Per-run light profile applies")
	var actor_a = alternate.get_node("%Player").visual.animation_player
	var actor_b = controller.active_run.get_node("%Player").visual.animation_player
	check(actor_a.get_animation_library(&"")!=actor_b.get_animation_library(&""),"Charlie animation libraries stay independent")
	custom.required_exit_gates.clear()
	custom.initial_gate_states.D1 = false
	check(not alternate.can_finish(),"Editing profile data cannot mutate an already-running snapshot")
	alternate.get_node("%Player").position = Layout.cell_point([0,18],0.08)
	alternate.get_node("%Player").velocity = Vector3.ZERO
	await frames(5)
	check(not alternate.completed,"Exit trigger rejects unmet configured conditions")
	check(alternate.try_activate_gate("D2"),"Configured required gate can be activated")
	await frames(6)
	check(alternate.completed and completions.size()==1,"Opening final gate while in exit emits one completion")
	check(completions[0].id=="isolation" and completions[0].result.completed,"Completion includes run identity and final state")
	alternate.complete_level()
	check(completions.size()==1,"Completion is not emitted twice")
	alternate.reset_level()
	await frames(45)
	check(not alternate.completed and alternate.get_run_state().gates.D1 and not alternate.get_run_state().gates.D2,"Reset restores the captured initial states")
	check(not gate_collision(alternate,"D2").disabled,"Reset kills pending gate tween/collision callback")
	check(alternate.find_children("*","AudioStreamPlayer",true,false).is_empty(),"Reset removes stopped opening sounds")
	check(not controller.active_run.get_run_state().gates.D1,"Other live instance still unchanged")
	check(default_profile.snapshot()==untouched,"Shared profile resource remains unchanged")
	check(JSON.stringify(Layout.config())==layout_before,"Run configuration never mutates shared spatial data")
	root.remove_child(alternate)
	alternate.queue_free()
	# Complete through the real exit area, then check next/retry UI state.
	var active = controller.active_run
	for id: String in ["D1","D3","D4"]:
		active.try_activate_gate(id)
	active.get_node("%Player").position = Layout.cell_point([0,18],0.08)
	active.get_node("%Player").velocity = Vector3.ZERO
	await frames(6)
	check(active.completed and not controller.get_node("%Next").disabled,"Completion enables next run")
	active.reset_level()
	await frames()
	check(controller.results.is_empty() and controller.get_node("%Next").disabled,"Local reset invalidates old results and next permission")
	for id: String in ["D1","D3","D4"]:
		active.try_activate_gate(id)
	active.get_node("%Player").position = Layout.cell_point([0,18],0.08)
	await frames(6)
	controller.next_run()
	await frames()
	check(controller.active_index==1 and not controller.active_run.completed,"Next enters fresh second run")
	var bad = Config.new()
	bad.initial_gate_states.UNKNOWN = true
	check(not bad.validation_errors().is_empty(),"Unknown initial gate configuration is rejected")
	bad = Config.new()
	bad.gate_interaction_enabled.D1 = false
	check(not bad.validation_errors().is_empty(),"Impossible mandatory gate configuration is rejected")
	bad = Config.new()
	bad.countdown_rules = {"enabled":true}
	check(not bad.validation_errors().is_empty(),"Unimplemented mechanics cannot be silently enabled")
	controller.queue_free()
	await frames()
	print("MAZE RUNS: ","PASS" if failures==0 else "FAIL"," (",failures," failures): shared geometry, three profiles, reset, isolation, physical exit and transitions")
	quit(failures)
