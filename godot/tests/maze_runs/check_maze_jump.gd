extends SceneTree

const Preview := preload("res://scenes/maze_runs/maze_runs_preview.tscn")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
var failures := 0
var held: Array[int] = []
var controller
var scene
var actor: CharacterBody3D
var input_camera: Camera3D

func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func key(code: int,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	if pressed and not held.has(code):
		held.append(code)
	elif not pressed:
		held.erase(code)

func release() -> void:
	for code: int in held.duplicate():
		key(code,false)

func ticks(count: int) -> void:
	for frame in count:
		await physics_frame
		for code: int in held:
			var event := InputEventKey.new()
			event.physical_keycode = code
			event.pressed = true
			Input.parse_input_event(event)
		await process_frame

func attach() -> void:
	scene = controller.active_run
	actor = scene.get_node("%Player")
	input_camera = Camera3D.new()
	actor.get_parent().add_child(input_camera)
	actor.movement_camera = input_camera

func place(point: Vector3) -> void:
	release()
	actor.reset_player()
	actor.position = point+Vector3(0,0.07,0)
	actor.velocity = Vector3.ZERO
	scene.set_walk_mode(true)
	actor.movement_camera = input_camera
	await ticks(12)
	check(actor.is_on_floor(),"Test start is on real floor: "+str(point))
	root.gui_release_focus()

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../.verification/maze-jump")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(label+".png"))==OK,"Native jump capture")

func check_jump(label: String,point: Vector3) -> void:
	await place(point)
	var start_y := actor.position.y
	var peak := start_y
	var launches := 0
	var was_airborne := false
	key(KEY_SPACE,true)
	for frame in 80:
		await ticks(1)
		peak = maxf(peak,actor.position.y)
		if not actor.is_on_floor() and not was_airborne:
			launches += 1
		was_airborne = not actor.is_on_floor()
		if frame==10:
			check(actor.visual.animation_player.current_animation=="JumpInPlace","Physics jump uses authored in-place animation")
			var skeleton: Skeleton3D = actor.visual.find_child("Skeleton3D",true,false)
			if skeleton==null:
				skeleton = actor.visual.find_children("*","Skeleton3D",true,false)[0]
			check(skeleton.get_bone_pose_position(skeleton.find_bone("Root")).length()<0.001,"Animation does not add a second vertical lift")
			if label=="entry":
				await capture("jump_apex")
	release()
	check(peak-start_y>0.32 and peak-start_y<0.47,label+" rises about 40 cm; actual="+str(peak-start_y))
	check(launches==1,label+" held Space launches exactly once")
	check(actor.is_on_floor() and absf(actor.position.y-start_y)<0.04,label+" returns to its original floor")
	check(actor.visual.animation_player.current_animation=="Idle",label+" landing restores Idle")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Input.use_accumulated_input = false
	root.size = Vector2i(1280,900)
	controller = Preview.instantiate()
	root.add_child(controller)
	attach()
	await ticks(8)
	await check_jump("entry",Layout.cell_point([18,0]))
	await check_jump("bridge",Vector3(39.6,2.6,16.0))
	await check_jump("sunken corridor",Vector3(3.6,-0.6,21.6))
	await check_jump("arched underpass",Vector3(39.6,0,15.6))
	# A second press in the air is consumed; it cannot launch after landing.
	await place(Layout.cell_point([18,0]))
	key(KEY_SPACE,true)
	await ticks(4)
	key(KEY_SPACE,false)
	await ticks(1)
	key(KEY_SPACE,true)
	await ticks(8)
	check(actor.velocity.y<1.0,"Airborne second press does not reset upward velocity")
	await ticks(35)
	check(actor.is_on_floor() and not actor._physics_jumping,"No double jump or buffered landing jump")
	release()
	# Walking and running remain available in the air, with matching landing clips.
	for running in [false,true]:
		await place(Layout.cell_point([18,0]))
		var start := actor.position
		key(KEY_W,true)
		key(KEY_SHIFT,running)
		key(KEY_SPACE,true)
		await ticks(32)
		check(start.z-actor.position.z>(1.0 if running else 0.7),"Jump preserves horizontal movement speed")
		check(actor.is_on_floor(),"Moving jump lands")
		check(actor.visual.animation_player.current_animation==("Run" if running else "Walk"),"Landing resumes correct locomotion")
		release()
	# Existing low wall and closed gate remain blocking while airborne.
	await place(Layout.cell_point([18,0]))
	key(KEY_D,true)
	key(KEY_SHIFT,true)
	key(KEY_SPACE,true)
	await ticks(70)
	check(actor.position.x<2.05,"Jump cannot bypass entry wall")
	release()
	await place(Layout.cell_point([16,1]))
	key(KEY_W,true)
	key(KEY_SHIFT,true)
	key(KEY_SPACE,true)
	await ticks(70)
	check(actor.position.z>38.65 and not scene.get_run_state().gates.D1,"Jump cannot bypass closed D1")
	release()
	# Uphill collision remains continuous during a running jump.
	var ramp_x := 10.0
	await place(Vector3(ramp_x,Layout.height_at(Vector2(ramp_x,44.4)),44.4))
	key(KEY_D,true)
	key(KEY_SHIFT,true)
	key(KEY_SPACE,true)
	await ticks(80)
	release()
	await ticks(12)
	check(actor.is_on_floor() and actor.position.x>12,"Running jump lands on the real sloped/platform surface")
	check(absf(actor.position.y-Layout.height_at(Vector2(actor.position.x,actor.position.z)))<0.05,"Slope landing does not penetrate the floor")
	# Real capsule ceiling collision: a test-only low slab never changes map files.
	await place(Layout.cell_point([18,0]))
	var ceiling := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(1.8,0.2,1.8)
	shape.shape = slab
	ceiling.add_child(shape)
	ceiling.position = Vector3(1.2,2.0,44.4)
	actor.get_parent().add_child(ceiling)
	await ticks(3)
	var hit_ceiling := false
	var highest := actor.position.y
	key(KEY_SPACE,true)
	for frame in 45:
		await ticks(1)
		hit_ceiling = hit_ceiling or actor.is_on_ceiling()
		highest = maxf(highest,actor.position.y)
	check(hit_ceiling and highest<0.32,"Head collision stops ascent below a low ceiling")
	check(actor.is_on_floor(),"Head bump still returns safely to floor")
	release()
	ceiling.queue_free()
	await ticks(2)
	# Reset, inspection mode, and run changes must clear jump state.
	await place(Layout.cell_point([18,0]))
	key(KEY_SPACE,true)
	await ticks(6)
	check(actor._physics_jumping,"Reset scenario actually starts airborne")
	scene.reset_level()
	await ticks(10)
	check(actor.is_on_floor() and not actor._physics_jumping and actor.visual.animation_player.current_animation=="Idle","Midair reset clears physical and visual jump")
	check(actor.position.distance_to(actor.spawn_point)<0.1,"Midair reset returns to entry")
	release()
	scene.show_top_view()
	key(KEY_SPACE,true)
	await ticks(10)
	check(not actor._physics_jumping and not actor.visible,"Overview cannot initiate a jump")
	release()
	scene.set_walk_mode(true)
	await ticks(3)
	root.gui_release_focus()
	key(KEY_SPACE,true)
	await ticks(5)
	var old_actor: int = actor.get_instance_id()
	controller.start_run(1)
	release()
	attach()
	await ticks(10)
	check(actor.get_instance_id()!=old_actor and actor.is_on_floor() and not actor._physics_jumping,"Next run starts grounded with no old jump state")
	await check_jump("second run",Layout.cell_point([18,0]))
	controller.start_run(2)
	attach()
	await check_jump("third run",Layout.cell_point([18,0]))
	controller.queue_free()
	await ticks(3)
	print("MAZE JUMP: ","PASS" if failures==0 else "FAIL"," (",failures," failures): input, animation, floor, slope, bridge, wall, door, headroom, reset and three runs")
	quit(failures)
