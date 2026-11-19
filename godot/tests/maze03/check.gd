extends SceneTree
const Layout:=preload("res://scripts/maze03/layout.gd")
const OUT:="res://../outputs/review/"
var checks: Array=[]
var capture:=false
func _initialize() -> void:
	capture="--captures" in OS.get_cmdline_user_args()
	_run.call_deferred()
func frames(count: int) -> void:
	for i in count:await process_frame
func check(ok: bool,label: String,detail: Variant="") -> void:
	checks.append({"pass":ok,"test":label,"detail":detail})
	print(("PASS " if ok else "FAIL ")+label+" "+str(detail))
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var picker: Control=load("res://scenes/levels/MazeSelect.tscn").instantiate()
	root.add_child(picker);picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await frames(5)
	check(picker.get_node("%Maze03").text.contains("Maze 03"),"Existing picker includes Maze03")
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"10_maze_selection.png")
	picker.open_maze(2)
	await frames(8)
	var maze: Control=picker.active_level
	check(is_instance_valid(maze) and maze.loaded_ok,"Maze03 loads from existing picker")
	if not is_instance_valid(maze) or not maze.loaded_ok:quit(1);return
	if "--visual-only" in OS.get_cmdline_user_args():
		await captures(maze);picker.queue_free();await frames(3);quit();return
	var gen: Node3D=maze.get_node("%GeneratedMaze")
	var player: CharacterBody3D=maze.get_node("%Player")
	var sanctuary: Node3D=gen.sanctuary
	player.controls_enabled=false
	check(not gen.has_node("Entry") and not gen.has_node("Exit") and gen.marker_count==0,"No graybox start/exit circles or inspection markers")
	check(gen.barriers.size()==4,"All four former door positions are boost barriers")
	check(gen.find_children("*MovingGate*","",true,false).is_empty(),"No solid door leaf or gate animation remains")
	check(gen.find_children("*Niche*","",true,false).is_empty(),"All old niches removed")
	check(gen.find_children("*Courtyard*","",true,false).is_empty(),"Old independent courtyard removed")
	check(gen.find_children("*Goldfish*","",true,false).is_empty(),"Old pool and fish systems absent")
	check(gen.find_children("H4_*","",true,false).is_empty(),"Original southern bridge/terrace H4 is removed")
	check(Layout.config().surfaces.filter(func(s: Dictionary):return str(s.id).begins_with("H2_")).size()==Layout.Base.config().surfaces.filter(func(s: Dictionary):return str(s.id).begins_with("H2_")).size(),"Finished high bridge H2 and its ramps retained")
	check(sanctuary.rib_count>=100,"Dense structural white vertical fins",sanctuary.rib_count)
	check(sanctuary.shell.has_node("OpenCircularOculus"),"Open circular crown on central vertical axis")
	check(sanctuary.pads.size()>=12,"Separated pads have individual matching colliders",sanctuary.pads.size())
	check(sanctuary.find_children("*JointSupport*","",true,false).is_empty(),"No hidden continuous carrier under separated pads")
	check(float(gen.get_meta("unified_wall_count",0))>250,"Joined final walls have their overlapping/internal faces removed",gen.get_meta("unified_wall_count",0))
	# Graph checks and actual capsule sweeps through each additional opening.
	var original: Dictionary=maze.maze_data
	var base:=Layout.Base.patched_map(original)
	var expanded:=Layout.patched_map(original)
	check(Layout.openings().size()==6,"Six new meaningful corridor links")
	for opening: Dictionary in Layout.openings():
		var matrix: Array=base.grid.verticalWalls if opening.axis=="v" else base.grid.horizontalWalls
		check(matrix[int(opening.row)][int(opening.col)],opening.id+" removes a previously closed edge",opening.edge)
		var a:=Layout.cell_point(opening.edge[0]);var b:=Layout.cell_point(opening.edge[1])
		a.y=Layout.height_at(Vector2(a.x,a.z))+0.05;b.y=Layout.height_at(Vector2(b.x,b.z))+0.05
		var hit:=KinematicCollision3D.new();var blocked:=player.test_move(Transform3D(Basis.IDENTITY,a),b-a,hit)
		check(not blocked,opening.id+" actual capsule sweep passes",str(hit.get_collider().get_path()) if blocked else "clear")
	var pending: Array[Vector2i]=[Vector2i(0,18)];var seen: Dictionary={}
	while not pending.is_empty():
		var cell: Vector2i=pending.pop_front()
		if seen.has(cell):continue
		seen[cell]=true
		for dir: Array in [[Vector2i(0,-1),"north"],[Vector2i(0,1),"south"],[Vector2i(-1,0),"west"],[Vector2i(1,0),"east"]]:
			var next: Vector2i=cell+dir[0]
			if next.x>=0 and next.x<19 and next.y>=0 and next.y<19 and not expanded.grid.cellWalls[cell.y][cell.x][dir[1]] and not seen.has(next):pending.append(next)
	check(seen.has(Vector2i(18,0)) and seen.has(Vector2i(10,9)),"Start, exit and central region remain connected",seen.size())
	var path: Array=original.routes.A.cellPath;var blockers: Array=[]
	for i in range(1,path.size()):
		var start:=Layout.cell_point(path[i-1]);var finish:=Layout.cell_point(path[i])
		# The route crosses several non-linear ramp/landing profiles. Follow the
		# actual finished floor instead of sweeping a chord through the stone.
		for j in 24:
			var a:=start.lerp(finish,j/24.0);var b:=start.lerp(finish,(j+1)/24.0)
			a.y=Layout.height_at(Vector2(a.x,a.z))+0.09;b.y=Layout.height_at(Vector2(b.x,b.z))+0.09
			var hit:=KinematicCollision3D.new()
			if player.test_move(Transform3D(Basis.IDENTITY,a),b-a,hit):
				blockers.append({"edge":[path[i-1],path[i]],"body":str(hit.get_collider().get_path())});break
	check(blockers.is_empty(),"Entire original main route A remains physically open",blockers)
	# Cross the actual Area3D in both directions on every barrier.
	for barrier: Area3D in gen.barriers:
		player.clear_barrier_boost();player.position=barrier.global_position+barrier.global_basis.z*0.35+Vector3.UP*0.03
		await physics_frame;await physics_frame
		for step in 18:
			player.position-=barrier.global_basis.z*0.04
			await physics_frame
		check(player.boost_remaining>1.6 and is_equal_approx(player._movement_modifier(),1.35),barrier.name+" forward crossing actually accelerates")
		check(not player.test_move(Transform3D(Basis.IDENTITY,barrier.global_position+barrier.global_basis.z*0.4+Vector3.UP*0.04),-barrier.global_basis.z*0.8),barrier.name+" is non-blocking")
		for step in 18:
			player.position+=barrier.global_basis.z*0.04
			await physics_frame
		check(player.boost_remaining>1.6,barrier.name+" repeat/reverse crossing refreshes duration")
	player.position=Vector3(1.2,0.03,44.4)
	for i in 135:await physics_frame
	check(player.boost_remaining==0.0 and is_equal_approx(player._movement_modifier(),1.0),"Boost expires and restores the original speed")
	player.move_speed_multiplier=0.8;player.apply_barrier_boost(1.35,2);player.apply_barrier_boost(1.35,2)
	check(is_equal_approx(player._movement_modifier(),1.08),"Repeated boost never stacks and preserves the base modifier")
	player.reset_player();check(player.boost_remaining==0.0 and player.move_speed_multiplier==0.8,"Reset clears boost without rewriting base speed");player.move_speed_multiplier=1.0
	# Real input and inherited movement across the visible water gaps.
	var camera:=Camera3D.new();player.get_parent().add_child(camera);player.movement_camera=camera
	var key:=InputEventKey.new();key.physical_keycode=KEY_W
	for lane: Array in sanctuary.pad_paths:
		player.controls_enabled=false;player.clear_barrier_boost();player.position=lane[0]+Vector3.UP*0.03;player.velocity=Vector3.ZERO
		for i in 5:await physics_frame
		var lowest:=player.position.y;var reached:=true
		key.pressed=true;Input.parse_input_event(key);Input.flush_buffered_events();player.controls_enabled=true
		for target: Vector3 in lane.slice(1):
			var arrived:=false
			for step in 180:
				var delta:=Vector2(target.x-player.position.x,target.z-player.position.z)
				if delta.length()<0.07:arrived=true;break
				camera.look_at_from_position(player.position+Vector3.UP*1.4,Vector3(target.x,player.position.y+1.4,target.z))
				await physics_frame
				lowest=minf(lowest,player.position.y)
			if not arrived:reached=false;break
		key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events();player.controls_enabled=false
		check(reached and lowest>-0.12,"Actual player walks the separated pad path without falling",{"start":str(lane[0]),"lowest_y":lowest,"reached":reached,"end":str(player.position)})
	# Walk inside the new tall sanctuary, below the central light.
	var nave_hit:=KinematicCollision3D.new()
	check(not player.test_move(Transform3D(Basis.IDENTITY,Vector3(24,0.04,18.8)),Vector3(0,0,7.9),nave_hit),"North entry to south exit through the central nave is open")
	player.movement_camera=maze.get_node("%FollowRig").camera;camera.queue_free();player.reset_player()
	if capture:await captures(maze)
	picker.show_selection();await frames(5)
	check(picker.active_level==null and picker.get_node("%Picker").visible,"Return from Maze03 to the existing picker")
	for index in [0,1]:
		picker.open_maze(index);await frames(8)
		check(is_instance_valid(picker.active_level) and picker.active_level.loaded_ok,"Maze%02d still opens from the same menu"%(index+1))
		picker.show_selection();await frames(5)
	picker.queue_free();await frames(4)
	var host: Control=load("res://scenes/main.tscn").instantiate();root.add_child(host);await frames(8)
	host.get_node("%MazeButton").pressed.emit();await frames(4);host.active_scene.get_node("%Maze03").pressed.emit();await frames(8)
	check(host.active_id=="maze03" and host.active_scene.loaded_ok,"Actual main host dispatches Maze03 through its registered menu")
	host.get_node("%MazeButton").pressed.emit();await frames(4)
	check(host.active_id=="maze_select","Main host returns from Maze03")
	host.queue_free();await frames(4)
	var failed:=checks.filter(func(c: Dictionary):return not c["pass"])
	var result:={"checks":checks,"passed":checks.size()-failed.size(),"failed":failed.size(),"engine":Engine.get_version_info().string}
	var file:=FileAccess.open(OUT+"test_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("RESULT ",result.passed,"/",checks.size());quit(0 if failed.is_empty() else 1)

func shot(maze: Control,id: String,at: Vector3,aim: Vector3,ortho: bool=false,size: float=54.0,fov: float=54.0) -> void:
	var viewport: SubViewport=maze.get_node("%ViewportContainer/Viewport")
	var old:=viewport.get_camera_3d();var camera:=Camera3D.new();camera.cull_mask=7;camera.far=500;camera.near=0.04;camera.fov=fov
	viewport.get_node("World").add_child(camera);camera.position=at;camera.look_at(aim,Vector3.FORWARD if ortho else Vector3.UP)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL if ortho else Camera3D.PROJECTION_PERSPECTIVE;camera.size=size;camera.current=true
	await frames(10);await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUT+id+".png")
	camera.queue_free();old.current=true
func captures(maze: Control) -> void:
	maze.get_node("%ViewportContainer").stretch=false;maze.get_node("%ViewportContainer/Viewport").size=Vector2i(1600,1100)
	maze.set_walk_mode(false);maze.get_node("%Player").hide()
	await shot(maze,"01_overall",Vector3(55,41,60),Vector3(23,3,22.8),false,54,55)
	var pins: Array[Node]=[]
	for opening: Dictionary in Layout.openings():
		var label:=Label3D.new();label.text=opening.id;label.font_size=64;label.pixel_size=0.021;label.modulate=Color("247c9d")
		label.position=(Layout.cell_point(opening.edge[0])+Layout.cell_point(opening.edge[1]))*0.5+Vector3.UP*4.5
		maze.get_node("%GeneratedMaze").add_child(label);pins.append(label)
	await shot(maze,"02_overhead",Vector3(22.8,90,22.8),Vector3(22.8,0,22.8),true,51)
	for pin: Node in pins:pin.queue_free()
	await shot(maze,"03_ribbed_sanctuary",Vector3(37.3,9.2,34.5),Vector3(24,4.6,22.8),false,54,58)
	await shot(maze,"04_inside_oculus",Vector3(24,1.5,25.5),Vector3(24,2.5,22.8),false,54,104)
	await shot(maze,"05_mirror_pool",Vector3(37.5,9.3,35.5),Vector3(24,1.1,22.8),false,54,61)
	await shot(maze,"06_separated_pads",Vector3(31.2,3.8,27.6),Vector3(30.9,0.3,22.8),false,54,65)
	await shot(maze,"07_surreal_horizon",Vector3(25,7,17),Vector3(-43,24,-61),false,54,68)
	var barrier: Area3D=maze.get_node("%GeneratedMaze").barriers[0];var origin:=barrier.global_position
	await shot(maze,"08_energy_barrier",origin+barrier.global_basis.z*2.2+Vector3.UP*1.55,origin+Vector3.UP*1.2,false,54,75)
	var player: CharacterBody3D=maze.get_node("%Player");player.show();player.controls_enabled=false
	player.clear_barrier_boost();player.position=origin+barrier.global_basis.z*0.35+Vector3.UP*0.03
	await physics_frame;await physics_frame
	for i in 18:
		player.position-=barrier.global_basis.z*0.04
		await physics_frame
	await shot(maze,"09_crossing_feedback",origin+barrier.global_basis.z*2.0+Vector3.UP*1.7,origin+Vector3.UP*0.9,false,54,80)
	player.clear_barrier_boost();player.hide()
