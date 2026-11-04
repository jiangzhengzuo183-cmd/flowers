extends SceneTree

const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const Loader := preload("res://scripts/maze/maze_loader.gd")
const Room := preload("res://scripts/levels/round_hall.gd")
var failures := 0
var held: Array[int] = []
var scene
var actor: CharacterBody3D
var generator
var highest := 0.0
var camera_samples := 0
var max_pitch_error := 0.0
var max_yaw_error := 0.0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	if pressed and not held.has(code):
		held.append(code)
	elif not pressed:
		held.erase(code)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
		for code: int in held:
			var event := InputEventKey.new()
			event.physical_keycode = code
			event.pressed = true
			Input.parse_input_event(event)
		await process_frame
		if is_instance_valid(actor):
			highest = maxf(highest,actor.position.y)
		if is_instance_valid(scene):
			var rig = scene.get_node("%FollowRig")
			if rig.enabled and rig.distance<12 and rig.indoor_blend<0.001 and not rig.inside_building:
				var boom: Vector3 = rig.camera.global_position-rig.global_position
				if boom.length()>0.1:
					max_pitch_error = maxf(max_pitch_error,absf(atan2(boom.y,Vector2(boom.x,boom.z).length())-rig.pitch))
					max_yaw_error = maxf(max_yaw_error,absf(angle_difference(atan2(boom.x,boom.z),rig.yaw)))
					camera_samples += 1

func release() -> void:
	for code: int in held.duplicate():
		key(code,false)

func walk_to(goal: Vector3, label: String, running: bool = true) -> bool:
	key(KEY_SHIFT,running)
	var code := 0
	var reached := false
	# A two-cell walking check takes about 180 physics steps. Keep enough
	# scheduling margin for native capture runs without relaxing the destination.
	for frame in 340:
		var offset := Vector2(goal.x-actor.position.x,goal.z-actor.position.z)
		if offset.length()<0.055:
			reached = true
			break
		var next := (KEY_D if offset.x>0 else KEY_A) if absf(offset.x)>absf(offset.y) else (KEY_S if offset.y>0 else KEY_W)
		if next != code:
			if code != 0:
				key(code,false)
			code = next
			key(code,true)
		await ticks(1)
	if code != 0:
		key(code,false)
	key(KEY_SHIFT,false)
	await ticks(3)
	if not reached:
		print("ACTOR STATE floor=",actor.is_on_floor()," wall=",actor.is_on_wall()," velocity=",actor.velocity," normal=",actor.get_floor_normal()," max=",actor.floor_max_angle)
		var probe := KinematicCollision3D.new()
		var flat := Vector3(goal.x-actor.position.x,0,goal.z-actor.position.z).normalized()*0.1
		if actor.test_move(actor.global_transform,flat,probe):
			print("MOTION PROBE ",probe.get_collider().get_path()," normal=",probe.get_normal()," point=",probe.get_position())
		for index in actor.get_slide_collision_count():
			var collision := actor.get_slide_collision(index)
			print("BLOCK DETAIL ",collision.get_collider().get_path()," normal=",collision.get_normal()," point=",collision.get_position())
	check(reached,label+" reached; actual="+str(actor.position)+" goal="+str(goal))
	return reached

func operate(id: String) -> void:
	await ticks(3)
	check(scene.closest_switch == generator.switches[id],"Nearest usable switch must be "+id)
	key(KEY_E,true)
	await ticks(1)
	key(KEY_E,false)
	await ticks(45)
	check(generator.gates[id].is_open and generator.switches[id].used,"E opens and latches "+id)
	check(generator.gates[id].leaf.get_node("GateCollision").disabled,"Open gate collision removed "+id)

func ray(a: Vector3,b: Vector3) -> Dictionary:
	return actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))

func capture(id: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	actor.movement_camera = scene.get_node("%FollowRig").camera
	await ticks(18)
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../.verification/greybox")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(id+".png"))==OK,"Screenshot "+id)
	actor.movement_camera = get_root().find_child("TestInputCamera",true,false)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Input.use_accumulated_input = false
	root.size = Vector2i(1280,900)
	var original := Loader.load_map().data as Dictionary
	# Git may convert LF to CRLF on Windows; only normalize that checkout difference.
	var original_text := FileAccess.get_file_as_string("res://data/maze_01.json").replace("\r\n","\n")
	check(original_text.sha256_text()=="f186db1678d73b5f90821290d09a31abc8516bf1b9aa4a7e10a65f4ea0f87bfb","Original JSON preserved (allowing Git checkout line endings)")
	check(Loader.validate(Layout.patched_map(original)).is_empty(),"Patched planar source has consistent walls and retains A/B")
	check(Layout.reachable(original,["D1","D2","D3","D4"]).has("16,1"),"S1 reachable with every door closed")
	var closed_final := Layout.reachable(original,["D2","D3","D4"])
	check(closed_final.has("15,13") and closed_final.has("7,15") and closed_final.has("9,18") and not closed_final.has("0,18"),"All remaining switches reachable before the mandatory doors")
	check(not Layout.reachable(original,["D4"]).has("0,18"),"Upper D4 cannot be bypassed through the lower crossing or new courtyard")
	check(not Layout.reachable(original,["D3"]).has("0,18"),"D3 cannot be bypassed through the circular hall")
	check(Layout.reachable(original,["D2"]).has("0,18"),"D2 optional")
	check(Layout.reachable(original,[]).size()==362,"All 361 original cells and the separate lower crossing reachable")
	scene = load("res://scenes/levels/maze_01_greybox.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	actor = scene.get_node("%Player")
	generator = scene.get_node("%GeneratedMaze")
	await ticks(6)
	check(generator.gates.size()==4 and generator.switches.size()==4,"Four paired gate/switch mechanisms")
	var wall_total := 378
	for patch: Dictionary in Layout.config().wall_patches:
		wall_total += 1 if patch.wall else -1
	check(generator.wall_count==wall_total,"Only approved wall patches applied")
	for id: String in ["G1","G2","G3","G4","G5","G6","G7","G8"]:
		check(generator.architecture.has_node(id),"Arch "+id)
	check(generator.architecture.has_node("CentralRoundHall"),"Circular main hall built independently")
	check(not generator.has_node("FloorCollision"),"Continuous base floor removed from the sunken footprint")
	check(not generator.has_node("HorizontalWalls/WallSegment_H_8_10"),"Low board below the repaired facade removed")
	check(generator.removed_rail_wall_count>8,"Redundant walls relieved alongside existing collidable guardrails")
	check(not generator.has_node("HorizontalWalls/WallSegment_H_19_6") and not generator.has_node("VerticalWalls/WallSegment_V_7_17"),"Full guard-covered wall panels removed from H1 and H2")
	for height: float in [0.5,1.4,2.5,3.6,5.2]:
		for step in 28:
			var x := 23.8+step*0.1
			check(not ray(Vector3(x,height,18.7),Vector3(x,height,21.4)).is_empty(),"Circle/porch facade sealed across its full height")
	check(scene.wall_occlusion.faded_mesh_count>40,"Local fading registered maze walls and architectural obstructions")
	check(generator.get_node("WallCollisions").collision_layer==1,"Wall collision remains active while the camera can look through locally")
	check(generator.high_wall_count>=32 and generator.high_wall_count<=50,"Arch clusters and central outward wall groups retained without enclosing all routes")
	check(generator._wall_height(0,18,false)<1.5 and generator._wall_height(1,18,true)<1.5,"Exit approach remains open and low")
	check(generator._wall_height(19,0,false)<1.5 and generator._wall_height(18,1,true)<1.5,"Entry front and spawn-side walls remain low")
	check(float(Layout.config().building.eave)>=5.8 and float(Layout.config().building.ridge)>=11.2,"Round chapel is a tall, pointed landmark")
	var input_camera := Camera3D.new()
	input_camera.name = "TestInputCamera"
	actor.get_parent().add_child(input_camera)
	actor.movement_camera = input_camera
	check_revision_geometry()
	await check_manual_camera()
	await check_h6_walk()
	if OS.get_cmdline_user_args().has("--revision-only"):
		print("H6 / VAULT / MANUAL CAMERA / SEAMS: ","PASS" if failures==0 else "FAIL"," (",failures," failures)")
		scene.queue_free()
		await ticks(3)
		quit(failures)
		return
	scene.reset_level()
	actor.movement_camera = input_camera
	await capture("entry")
	check(scene.get_node("%FollowRig").camera.global_position.distance_to(scene.get_node("%FollowRig").global_position)>2.4,"High-wall entry camera retains enough distance to see Charlie")
	var manual_rig = scene.get_node("%FollowRig")
	var zoom_event := InputEventMouseButton.new()
	zoom_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	zoom_event.pressed = true
	for i in 6:
		manual_rig.handle_input(zoom_event)
	check(absf(manual_rig.camera.global_position.distance_to(manual_rig.global_position)-float(manual_rig.distance))<0.01,"Manual wheel zoom responds immediately instead of waiting for collision smoothing")
	manual_rig.reset_view()
	scene.inspect_location(17)
	await ticks(2)
	check(generator.round_hall.get_node("Roof").visible,"Chapel exterior overview shows the pointed roof")
	scene.show_top_view()
	await ticks(2)
	check(not generator.round_hall.get_node("Roof").visible,"Top view removes roof to reveal the circular space")
	await ticks(18)
	check(scene.wall_occlusion.strength<0.001,"Overview restores all wall opacity")
	scene.inspect_location(10)
	await ticks(2)
	check(generator.round_hall.get_node("Roof").visible,"Walking inside keeps the building roof solid")
	scene.reset_level()
	actor.movement_camera = input_camera
	if OS.get_cmdline_user_args().has("--visual-only"):
		await visual_review()
		scene.queue_free()
		await ticks(3)
		quit(failures)
		return
	check_grey_materials()
	await check_sight_transparency()
	await check_indoor_camera()
	# Real closed-gate collision, not just an abstract graph assertion.
	actor.position = Layout.cell_point([16,1],0.02)
	await ticks(3)
	key(KEY_W,true)
	key(KEY_SHIFT,true)
	await ticks(50)
	release()
	check(actor.position.z>38.75,"Closed D1 blocks a running capsule")
	actor.position = Layout.cell_point([7,16],2.64)
	await ticks(6)
	key(KEY_W,true)
	key(KEY_SHIFT,true)
	await ticks(45)
	release()
	check(actor.position.z>17.15 and absf(actor.position.y-2.6)<0.1,"Closed D4 blocks the upper bridge physically")
	actor.position = Layout.cell_point([7,16],2.64)
	await ticks(6)
	key(KEY_D,true)
	key(KEY_SHIFT,true)
	await ticks(40)
	release()
	check(actor.position.x<40.3 and actor.position.y>2.5,"Bridge guard alone stops a running capsule after adjacent wall removal")
	var guard_hit := ray(Vector3(39.6,3.1,18.0),Vector3(42.0,3.1,18.0))
	check(not guard_hit.is_empty() and str(guard_hit.collider.name).begins_with("GuardRail"),"Bridge lateral blocker is the guard itself")
	actor.position = Vector3(14.4,1.24,44.4)
	await ticks(6)
	key(KEY_S,true)
	key(KEY_SHIFT,true)
	await ticks(40)
	release()
	check(actor.position.z<45.1 and actor.position.y>1.1,"H1 guard alone prevents leaving the raised route")
	actor.reset_player()
	await ticks(3)
	for route_id: String in ["A","B"]:
		scene.reset_level()
		actor.movement_camera = input_camera
		await ticks(4)
		var path: Array = original.routes[route_id].cellPath
		var completed := 0
		for i in range(1,path.size()):
			if not await walk_to(Layout.cell_point(path[i]),"Route "+route_id+" "+str(path[i])):
				break
			completed += 1
			if Layout.cell_key(path[i]) == "16,1":
				await operate("D1")
			if Layout.cell_key(path[i]) == "9,18":
				await operate("D4")
			if route_id == "A" and Layout.cell_key(path[i]) == "14,12":
				await walk_to(Layout.cell_point([15,12]),"S2 branch entry")
				await walk_to(Layout.cell_point([15,13]),"S2 approach")
				await operate("D2")
				await capture("switch_d2")
				await walk_to(Layout.cell_point([15,12]),"S2 return")
				await walk_to(Layout.cell_point([14,12]),"A rejoin")
			if Layout.cell_key(path[i]) == "7,16":
				await walk_to(Layout.cell_point([7,15]),"Upper S3 platform")
				check(absf(actor.position.y-2.6)<0.09,"S3 reached on real +2.6m collision")
				await operate("D3")
				await capture("bridge_switch")
				await walk_to(Layout.cell_point([7,16]),"Upper bridge rejoin")
			if route_id == "A" and Layout.cell_key(path[i]) == "18,6":
				check(absf(actor.position.y-1.2)<0.08,"H1 capsule stands on +1.2m platform")
				await capture("raised_walkway")
			if Layout.cell_key(path[i]) == "6,16":
				check(absf(actor.position.y-2.6)<0.09,"Upper crossing stays on bridge")
		check(completed==int(original.routes[route_id].moveCount),"Full real-input route "+route_id)
		check(scene.completed,"Exit trigger completes route "+route_id)
		print("GREYBOX ROUTE ",route_id,": ",completed,"/",original.routes[route_id].moveCount,"; actual upper surfaces and switch detours")
	check(highest>2.55,"Real movement ascended both levels without position snapping")
	# Both structures must also support turning around and walking back uphill.
	actor.position = Layout.cell_point([18,8],0.02)
	await ticks(4)
	for cell: Array in [[18,7],[18,6],[18,5],[18,4],[18,3]]:
		await walk_to(Layout.cell_point(cell),"H1 reverse "+str(cell))
	check(absf(actor.position.y)<0.09,"H1 reverse returns to ground")
	actor.position = Layout.cell_point([4,17],0.02)
	await ticks(4)
	for cell: Array in [[4,16],[5,16],[6,16],[7,16],[8,16],[8,17],[8,18]]:
		await walk_to(Layout.cell_point(cell),"H2 reverse "+str(cell))
	check(absf(actor.position.y)<0.09,"H2 reverse returns to ground")
	# Real bidirectional courtyard traversal: no teleport between route cells.
	actor.position = Layout.cell_point([5,0],0.04)
	await ticks(4)
	for cell: Array in Layout.config().northwest.mainPath.slice(1):
		await walk_to(Layout.cell_point(cell),"NW main "+str(cell))
		check(absf(actor.position.y-Layout.height_at(Vector2(actor.position.x,actor.position.z)))<0.1,"NW actual floor height "+str(cell))
	var backward: Array = Layout.config().northwest.mainPath.duplicate()
	backward.reverse()
	for cell: Array in backward.slice(1):
		await walk_to(Layout.cell_point(cell),"NW reverse "+str(cell))
	check(absf(actor.position.y)<0.09,"NW reverse returns to ground")
	for route_name: String in ["groundBypass","northGroundPath","lowerLoop"]:
		var local_path: Array = Layout.config().northwest[route_name]
		var first := Layout.cell_point(local_path[0])
		first.y = Layout.height_at(Vector2(first.x,first.z))+0.04
		actor.position = first
		await ticks(4)
		for cell: Array in local_path.slice(1):
			await walk_to(Layout.cell_point(cell),"NW "+route_name+" "+str(cell))
			if route_name!="lowerLoop":
				check(absf(actor.position.y)<0.09,"NW bypass stays on ground")
	check(not ray(Vector3(1.2,0.9,8.4),Vector3(1.2,0.9,10.8)).is_empty(),"Observation window is not a shortcut")
	check(not ray(Vector3(3.6,0.3,13.2),Vector3(6,0.3,13.2)).is_empty(),"Lower court cannot enter upper gallery through retaining wall")
	# The original indoor B bend and every external door in both directions.
	for door_path: Array in [[[7,9],[8,9],[9,9],[9,10],[8,10],[8,11],[7,11]],[[7,9],[8,9],[9,9],[9,10],[10,10],[11,10]]]:
		actor.position = Layout.cell_point(door_path[0],0.04)
		await ticks(4)
		for cell: Array in door_path.slice(1):
			await walk_to(Layout.cell_point(cell),"Round hall "+str(cell))
		door_path.reverse()
		for cell: Array in door_path.slice(1):
			await walk_to(Layout.cell_point(cell),"Round hall reverse "+str(cell))
	for raised_path: Array in [[[12,14],[12,15],[12,16]],[[11,10],[12,10],[12,9],[12,8]]]:
		actor.position = Layout.cell_point(raised_path[0],0.04)
		await ticks(4)
		for cell: Array in raised_path.slice(1):
			await walk_to(Layout.cell_point(cell),"New platform "+str(cell))
		raised_path.reverse()
		for cell: Array in raised_path.slice(1):
			await walk_to(Layout.cell_point(cell),"New platform reverse "+str(cell))
	# Isolated collision probes and actual E/W traversal under the bridge.
	scene.reset_level()
	actor.movement_camera = input_camera
	actor.position = Layout.cell_point([6,15],0.02)
	await ticks(6)
	check(ray(Vector3(37.2,0.9,15.6),Vector3(42,0.9,15.6)).is_empty(),"Both underpass wall openings are physically clear")
	check(not ray(Vector3(39.6,0.9,15.6),Vector3(39.6,0.9,13.2)).is_empty(),"Lower passage cannot join the upper N/S route")
	check(not ray(Vector3(39.6,3.4,15.6),Vector3(42,3.4,15.6)).is_empty(),"Upper guardrail blocks walking off the bridge")
	for cell: Array in [[6,16],[6,17],[7,17],[7,18],[8,18]]:
		await walk_to(Layout.cell_point(cell),"Underpass loop "+str(cell))
		check(absf(actor.position.y)<0.09,"Ground crossing remains on ground "+str(cell))
	actor.position = Layout.cell_point([6,15],0.02)
	scene.get_node("%FollowRig").reset_view()
	await capture("underpass")
	actor.position = Layout.cell_point([6,16],0.02)
	scene.get_node("%FollowRig").reset_view()
	await ticks(6)
	check(scene.get_node("%FollowRig").camera.global_position.y<2.38,"Camera stays below the actual bridge ceiling")
	check(camera_samples>500 and max_pitch_error<0.001 and max_yaw_error<0.001,"Real route traversal never forces camera pitch or yaw")
	print("STABLE CAMERA: ",camera_samples," frames; pitch error=",max_pitch_error," yaw error=",max_yaw_error)
	print("WALL DISTRIBUTION: ",generator.high_wall_count," high ordinary wall segments; arch structures and church retained")
	print("RAIL RELIEF: ",generator.removed_rail_wall_count," wall panels removed or trimmed; guards retain collision")
	release()
	scene.queue_free()
	await process_frame
	print("MAZE 01 GREYBOX: %s (%d failures)"%["PASS" if failures==0 else "FAIL",failures])
	quit(0 if failures==0 else 1)

func check_sight_transparency() -> void:
	actor.position = Layout.cell_point([3,5],0.04)
	var rig = scene.get_node("%FollowRig")
	rig.reset_view()
	rig.yaw = PI/2
	await ticks(24)
	var wall: StaticBody3D = generator.get_node("VerticalWalls/WallSegment_V_3_6")
	var id := str(wall.get_instance_id())
	check(scene.wall_occlusion.last_blockers.has(id),"Camera rays hit the actual intervening high wall")
	check(absf(float(scene.wall_occlusion.groups[id].opacity)-0.22)<0.01,"Hit wall becomes genuinely alpha transparent")
	await capture("wall_blocks_camera_transparent")
	var partial_found := false
	for step in 120:
		rig.yaw = -PI+TAU*step/120
		rig._update_pose()
		scene.wall_occlusion.sight_blockers(rig.camera.global_position)
		if scene.wall_occlusion.last_hidden_fraction>0.1 and scene.wall_occlusion.last_hidden_fraction<0.8:
			partial_found = true
			break
	check(partial_found,"Found a camera angle exposing a meaningful part of Charlie")
	await ticks(35)
	check(scene.wall_occlusion.last_blockers.is_empty() and scene.wall_occlusion.strength<0.001,"Partial body occlusion keeps walls fully opaque")
	await capture("partial_block_stays_opaque")
	rig.yaw = -PI/2
	await ticks(30)
	check(not scene.wall_occlusion.last_blockers.has(id),"Nearby wall outside camera sight rays is not selected")
	check(float(scene.wall_occlusion.groups[id].opacity)>0.999,"Same nearby wall restores full opacity after camera turns")
	check(wall.collision_layer&1,"Transparent wall retains physical collision")
	await capture("near_wall_not_blocking_opaque")
	actor.position = Layout.cell_point([16,1],0.04)
	rig.reset_view()
	rig.yaw = PI
	await ticks(24)
	check(scene.wall_occlusion.last_hidden_fraction<0.85,"Gate movement box is not mistaken for an opaque visual wall")
	scene.reset_level()
	actor.movement_camera = root.find_child("TestInputCamera",true,false)
	await ticks(4)

func _coplanar_cover(parent: Node,axis: int,plane: float,point: Vector2) -> int:
	var count := 0
	for mesh: MeshInstance3D in parent.find_children("*","MeshInstance3D",true,false):
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var a: Vector3 = mesh.global_transform*faces[i]
			var b: Vector3 = mesh.global_transform*faces[i+1]
			var c: Vector3 = mesh.global_transform*faces[i+2]
			if absf(a[axis]-plane)>0.00001 or absf(b[axis]-plane)>0.00001 or absf(c[axis]-plane)>0.00001:
				continue
			var aa := Vector2(a.x,a.z) if axis==1 else (Vector2(a.z,a.y) if axis==0 else Vector2(a.x,a.y))
			var bb := Vector2(b.x,b.z) if axis==1 else (Vector2(b.z,b.y) if axis==0 else Vector2(b.x,b.y))
			var cc := Vector2(c.x,c.z) if axis==1 else (Vector2(c.z,c.y) if axis==0 else Vector2(c.x,c.y))
			var denominator := (bb-aa).cross(cc-aa)
			if absf(denominator)<0.0000001:
				continue
			var u := (point-aa).cross(cc-aa)/denominator
			var v := (bb-aa).cross(point-aa)/denominator
			if u>0.000001 and v>0.000001 and u+v<0.999999:
				count += 1
	return count

func check_revision_geometry() -> void:
	check(generator.floor_material.albedo_color.is_equal_approx(Color("c3c8c7")),"Original light-grey floor palette preserved")
	check(generator.architecture.has_node("SunkenCorridor/H6_InvestigationAnchor"),"H6 retains one optional investigation anchor")
	check(generator.architecture.has_node("ArchedUnderpass"),"Bridge has a collision-matched arch vault")
	for z: float in [15.6,17.3,19.3,21.6,23.9,25.9,27.6]:
		var hit := ray(Vector3(3.6,1.0,z),Vector3(3.6,-1.2,z))
		check(not hit.is_empty() and absf(float(hit.position.y)-Layout.corridor_height(z))<0.015,"H6 visible floor has the matching negative physical height at "+str(z))
		if not hit.is_empty():
			check(str(hit.collider.name)=="RaisedSurfaceCollision","Original zero-height slab does not cover H6")
	var niche := ray(Vector3(3.6,0.0,21.6),Vector3(5.1,0.0,21.6))
	var panel := ray(Vector3(3.6,0.0,22.5),Vector3(5.1,0.0,22.5))
	check(not niche.is_empty() and absf(float(niche.position.x)-4.75)<0.015,"Middle niche is physically recessed, not a coplanar decal")
	check(not panel.is_empty() and absf(float(panel.position.x)-4.65)<0.015,"H6 wall retains its original inner face between niches")
	check(not ray(Vector3(3.6,-0.3,21.6),Vector3(1.2,-0.3,21.6)).is_empty(),"Lower corridor west retaining wall prevents crossing into the adjacent lane")
	check(not ray(Vector3(3.6,0.0,21.6),Vector3(6.0,0.0,21.6)).is_empty(),"Niche back does not create a shortcut")
	var crown := ray(Vector3(39.6,1.7,15.9),Vector3(39.6,2.7,15.9))
	var shoulder := ray(Vector3(39.6,1.7,15.07),Vector3(39.6,2.7,15.07))
	check(not crown.is_empty() and not shoulder.is_empty(),"Arch has a collidable crown and shoulders")
	if not crown.is_empty() and not shoulder.is_empty():
		check(float(crown.position.y)>2.38 and float(shoulder.position.y)<2.15,"Bridge underside is curved instead of rectangular")
	# Probe rendered triangles, rather than the polygon construction helper.
	for point: Vector2 in [Vector2(27.173,20.357),Vector2(25.173,20.357)]:
		check(_coplanar_cover(generator.round_hall,1,0.024,point)==1,"Round hall/porch floor overlaps render exactly once")
	check(_coplanar_cover(generator.round_hall,1,5.98,Vector2(27.173,20.357))==1,"Overlapping porch roofs render a single top surface")
	check(_coplanar_cover(generator.round_hall,0,28.74,Vector2(20.357,2.173))==1,"G7 shared outer wall has one visible face")
	var cover := _coplanar_cover(generator.round_hall,0,21.9,Vector2(19.317,1.173))
	cover += _coplanar_cover(generator.architecture.get_node("G6"),0,21.9,Vector2(19.317,1.173))
	check(cover==1,"G6 porch wall and door jamb do not overlap")
	check(_coplanar_cover(generator.round_hall,2,19.5,Vector2(25.123,0.133))==1,"Plinth cap does not flicker over the porch wall")
	check(_coplanar_cover(generator.round_hall,2,19.5,Vector2(25.481,5.713))==1,"Cornice cap does not flicker over the porch wall")

func check_manual_camera() -> void:
	var rig = scene.get_node("%FollowRig")
	actor.position = Vector3(3.6,-0.56,21.6)
	rig.reset_view()
	await ticks(8)
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(0,-float(rig.pitch)/0.007)
	rig.handle_input(drag)
	await ticks(8)
	var boom: Vector3 = rig.camera.global_position-rig.global_position
	check(absf(float(rig.pitch))<0.0001 and absf(boom.y)<0.001,"Actual mouse drag reaches a level character view")
	await capture("manual_eye_level")
	drag.relative = Vector2(0,-0.18/0.007)
	rig.handle_input(drag)
	await ticks(8)
	boom = rig.camera.global_position-rig.global_position
	check(float(rig.pitch)<-0.17 and boom.y<0,"Actual mouse drag permits a slight upward-looking angle")
	check(rig.camera.global_position.y>Layout.height_at(Vector2(rig.camera.global_position.x,rig.camera.global_position.z))+0.1,"Low-angle camera stays above the floor")
	await capture("manual_upward_view")
	rig.distance = 70
	rig._update_pose()
	boom = rig.camera.global_position-rig.global_position
	check(atan2(boom.y,Vector2(boom.x,boom.z).length())<0,"Manual low angle is not replaced by automatic zoom-out top-down pitch")
	rig.reset_view()
	check(absf(float(rig.pitch)-0.68)<0.0001 and not rig.manual_pitch,"Reset restores the original default main view")
	scene.reset_level()
	actor.movement_camera = root.find_child("TestInputCamera",true,false)

func check_h6_walk() -> void:
	var path: Array = [[11,0],[11,1],[10,1],[9,1],[8,1],[7,1],[6,1],[6,0]]
	actor.position = Layout.cell_point(path[0],0.04)
	await ticks(5)
	for cell: Array in path.slice(1):
		await walk_to(Layout.cell_point(cell),"H6 northbound run "+str(cell))
		check(absf(actor.position.y-Layout.height_at(Vector2(actor.position.x,actor.position.z)))<0.09,"H6 running follows the actual sloped floor")
	path.reverse()
	for cell: Array in path.slice(1):
		await walk_to(Layout.cell_point(cell),"H6 southbound walk "+str(cell),false)
		check(absf(actor.position.y-Layout.height_at(Vector2(actor.position.x,actor.position.z)))<0.09,"H6 walking follows the actual sloped floor")
	check(absf(actor.position.y)<0.09,"H6 returns to the original ground-level connector")
	for z: float in [15.3,16.4]:
		actor.position = Vector3(37.2,0.04,z)
		await ticks(4)
		await walk_to(Vector3(42,0,z),"Arched passage offset crossing "+str(z))
		await walk_to(Vector3(37.2,0,z),"Arched passage offset reverse "+str(z),false)
	scene.reset_level()
	actor.movement_camera = root.find_child("TestInputCamera",true,false)

func check_indoor_camera() -> void:
	var rig = scene.get_node("%FollowRig")
	actor.position = Vector3(24,0.04,22.8)
	rig.reset_view()
	await ticks(20)
	check(rig.indoor_blend>0.99 and rig.camera.fov>64,"Indoor follow profile uses a comfortable wider field of view")
	check(generator.round_hall.get_node("Roof").visible,"Indoor camera keeps the roof visible")
	for mesh: MeshInstance3D in generator.round_hall.find_children("*","MeshInstance3D",true,false):
		check(not mesh.material_override is ShaderMaterial,"Building materials never use wall transparency")
	for step in 8:
		rig.yaw = step*TAU/8
		await ticks(12)
		var p: Vector3 = rig.camera.global_position
		check(Room.contains(Vector2(p.x,p.z),Layout.config().building),"Indoor orbit camera remains inside the room")
		var result := actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.global_position+Vector3(0,1.1,0),p,4))
		check(result.is_empty(),"Indoor camera has a clear path to Charlie without transparent walls")
	check(rig.camera.global_position.distance_to(rig.global_position)>1.5,"Main room camera retains useful framing distance")
	await capture("indoor_follow_opaque")
	for path: Array in [[[7,9],[8,9],[9,9]],[[7,11],[8,11],[8,10],[9,10]],[[11,10],[10,10],[9,10]]]:
		actor.position = Layout.cell_point(path[0],0.04)
		rig.reset_view()
		await ticks(4)
		for cell: Array in path.slice(1):
			await walk_to(Layout.cell_point(cell),"Indoor opaque entry "+str(cell))
			await ticks(12)
			var p: Vector3 = rig.camera.global_position
			var sight := actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.global_position+Vector3(0,1.1,0),p,4))
			check(sight.is_empty(),"Camera enters through the doorway without passing through solid walls")
			check(rig.camera.global_position.distance_to(actor.global_position+Vector3(0,1.1,0))>0.7,"Doorway camera avoids an extreme head close-up")
			await capture("doorway_%d_%d"%[int(cell[0]),int(cell[1])])
		var final_point: Vector3 = rig.camera.global_position
		check(Room.contains(Vector2(final_point.x,final_point.z),Layout.config().building),"Camera has followed all the way indoors after entering")
		path.reverse()
		for cell: Array in path.slice(1):
			await walk_to(Layout.cell_point(cell),"Indoor opaque exit "+str(cell))
	scene.reset_level()
	actor.movement_camera = root.find_child("TestInputCamera",true,false)

func check_grey_materials() -> void:
	var target_color: Color = generator.wall_material.albedo_color
	var rails := 0
	for mesh: MeshInstance3D in generator.architecture.find_children("*","MeshInstance3D",true,false):
		var part := str(mesh.get_meta("greybox_part",""))
		if part.begins_with("GuardRail") or part in ["GalleryBalustrade","GalleryBaluster","Housing"] or part.begins_with("Bar") or part=="Crossbar":
			var material: Material = mesh.material_override
			var color: Color = material.get_shader_parameter("stone_color") if material is ShaderMaterial else material.albedo_color
			check(color.is_equal_approx(target_color),"Non-building gate/rail matches the wall grey: "+part)
			rails += 1
	check(rails>40,"Verified gate bars, switch housings and raised-route rails")

func visual_review() -> void:
	check_grey_materials()
	await check_sight_transparency()
	await check_indoor_camera()
	scene.inspect_location(7)
	scene.get_node("%FollowRig").yaw = PI/2
	await capture("northwest_walk_stable")
	actor.position = Layout.cell_point([3,0],0.04)
	scene.get_node("%FollowRig").reset_view()
	scene.get_node("%FollowRig").yaw = -PI/2
	await capture("high_wall_local_fade")
	scene.inspect_location(1)
	await ticks(5)
	await capture("tutorial_gate")
	await operate("D1")
	await capture("tutorial_gate_open")
	scene.inspect_location(6)
	await walk_to(Layout.cell_point([18,5]),"H1 native climb")
	scene.get_node("%FollowRig").distance = 6
	await capture("raised_walkway")
	scene.inspect_location(4)
	await ticks(4)
	await capture("bridge_switch")
	scene.inspect_location(5)
	scene.get_node("%FollowRig").yaw = -PI/2
	await capture("underpass")
	scene.inspect_location(4)
	scene.get_node("%FollowRig").enabled = false
	var view := Camera3D.new()
	actor.get_parent().add_child(view)
	view.position = Vector3(49,15,27)
	view.look_at(Vector3(39.6,1.3,15.6),Vector3.UP)
	view.fov = 50
	view.current = true
	await capture("bridge_overview")
	scene.inspect_location(11)
	scene.get_node("%FollowRig").enabled = false
	view.current = true
	view.position = Vector3(37,17,37)
	view.look_at(Vector3(24,4.8,22.8),Vector3.UP)
	await capture("round_hall_exterior")
	view.position = Vector3(55,42,60)
	view.look_at(Vector3(22.8,2.8,22.8),Vector3.UP)
	await capture("whole_level_landmark")
	scene.set_walk_mode(false)
	scene.get_node("%CameraRig").top_down = true
	view.current = true
	view.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.size = 12.5
	view.position = Vector3(24,18,22.8)
	view.look_at(Vector3(24,0,22.8),Vector3.FORWARD)
	await capture("round_hall_plan")
	view.size = 13.5
	view.position = Vector3(12,18,20)
	view.look_at(Vector3(4.8,0,9.6),Vector3.UP)
	await capture("northwest_overview")
	view.size = 12
	view.position = Vector3(4.8,18,9.6)
	view.look_at(Vector3(4.8,0,9.6),Vector3.FORWARD)
	await capture("northwest_plan")
	scene.inspect_location(10)
	scene.get_node("%FollowRig").enabled = false
	view.current = true
	view.projection = Camera3D.PROJECTION_PERSPECTIVE
	view.position = Vector3(24.0,1.65,24.1)
	view.look_at(Vector3(24.2,1.3,20.2),Vector3.UP)
	await capture("round_hall_interior")
	scene.set_walk_mode(false)
	scene.get_node("%CameraRig").top_down = false
	view.current = true
	view.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.size = 11.5
	view.position = Vector3(22,14,21)
	view.look_at(Vector3(13.2,1.0,10.8),Vector3.UP)
	await capture("arch_wall_cluster")
	view.projection = Camera3D.PROJECTION_PERSPECTIVE
	view.fov = 50
	view.position = Vector3(24.8,4.0,14.0)
	view.look_at(Vector3(25.0,2.9,19.8),Vector3.UP)
	await capture("facade_seam_repaired")
	scene.inspect_location(19)
	check(scene.get_node("%CameraRig").camera.current,"Facade inspection preset uses its overview camera")
	await capture("facade_inspection_preset")
	scene.inspect_location(20)
	check(scene.get_node("%CameraRig").camera.current,"Bridge inspection preset uses its overview camera")
	await capture("bridge_inspection_preset")
	print("NATIVE GREYBOX VISUAL CHECK: ","PASS" if failures==0 else "FAIL")
