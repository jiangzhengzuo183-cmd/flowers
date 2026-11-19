extends "res://tests/levels/check_maze_01_greybox.gd"
const System := preload("res://modules/stamina/stamina_system.gd")
const Levels := [preload("res://scenes/levels/maze_01_greybox.tscn"),preload("res://scenes/levels/Maze02.tscn"),preload("res://scenes/levels/Maze03.tscn")]
var folder := "res://../.verification/stamina"
func run() -> void:
	root.size = Vector2i(1500,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	unit_checks()
	for id in 3:
		scene = Levels[id].instantiate()
		root.add_child(scene)
		actor = scene.get_node("%Player")
		generator = scene.get_node("%GeneratedMaze")
		await ticks(16)
		check(actor.stamina is System and actor.get_node("StaminaSystem")==actor.stamina,"All levels use the same real stamina component "+str(id+1))
		check(scene.get_node("%ViewportContainer/StaminaDebugReadout")!=null,"Temporary debug readout installed")
		if id<2:
			for gate in generator.gates.values(): gate.set_open_state(true)
		else:
			scene.earthquakes.next_event = INF
			scene.earthquakes.minor_next = INF
		var camera := Camera3D.new()
		actor.get_parent().add_child(camera)
		actor.movement_camera = camera
		var lane := find_lane()
		check(not lane.is_empty(),"A real clear six-metre corridor exists")
		if not lane.is_empty():
			await place(lane[0])
			actor.stamina.current = 100.0
			key(KEY_D,true)
			await set_sprint(true)
			await ticks(60)
			check(actor.position.distance_to(lane[0])>2.3 and actor.stamina.current<84.0 and actor.stamina.current>79.0,"Actual sprint movement drains smoothly "+str(id+1))
			check(actor.stamina.is_sprinting,"Actual sprint state is exposed")
			release()
			var value: float = actor.stamina.current
			await ticks(28)
			check(absf(actor.stamina.current-value)<0.1,"Recovery waits after sprint stops")
			await ticks(65)
			check(actor.stamina.current>value+7.0 and actor.stamina.is_recovering,"Normal delayed recovery works")
			await place(lane[0])
			actor.stamina.current = 0.25
			actor.stamina.is_exhausted = false
			key(KEY_D,true)
			await set_sprint(true)
			await ticks(28)
			check(actor.stamina.is_exhausted and actor.stamina.exhaustion_count>0 and actor.velocity.length()<1.7,"Exhaustion falls back to walking, no Shift stutter "+str(id+1))
			release()
			await place(lane[0])
			await set_sprint(false)
			actor.stamina.current=60.0
			actor.stamina.since_sprint=0.0
			key(KEY_D,true)
			await ticks(60)
			release()
			check(actor.stamina.current>=60.0 and not actor.stamina.is_sprinting,"Ordinary walking never consumes stamina")
			var paused: float=actor.stamina.current
			actor.controls_enabled=false
			await ticks(60)
			check(is_equal_approx(actor.stamina.current,paused),"Development overview/disabled controls pause stamina")
			actor.controls_enabled=true
			await place(Vector3(0.32,0,44.4))
			actor.stamina.current=80.0
			var before_wall: float=actor.stamina.sprint_seconds
			key(KEY_A,true)
			await set_sprint(true)
			await ticks(60)
			release()
			check(actor.stamina.current>=80.0 and actor.stamina.sprint_seconds==before_wall,"Holding Shift against a wall does not drain stamina")
			actor.reset_player()
			await ticks(4)
			check(actor.stamina.current==100.0 and actor.stamina.exhaustion_count==0,"Reset clears depleted stamina and counters")
		if id<2:
			await zones_and_cakes(id)
		else:
			await barriers_and_recording()
		scene.show_top_view()
		await ticks(3)
		await capture("after_maze"+str(id+1)+"_top")
		print("STAMINA LEVEL ",id+1," completed failures=",failures)
		release()
		scene.queue_free()
		await process_frame
		await process_frame
	print("UNIFIED STAMINA ","PASS" if failures==0 else "FAIL"," failures=",failures)
	OS.delay_msec(120)
	quit(failures)

func unit_checks() -> void:
	var s := System.new()
	root.add_child(s)
	s.reset_session()
	s.step(1.0,true,true,true)
	check(is_equal_approx(s.current,82.0),"One second sprint has frame-independent cost")
	var before := s.current
	s.step(10.0,true,true,false)
	check(s.current==before,"Disabled controls pause stamina")
	s.step(0.8,false,false,true)
	check(s.current==before,"Delay boundary does not leak recovery")
	s.step(0.2,false,false,true)
	check(is_equal_approx(s.current,before+1.4),"Only the post-delay fraction of a frame recovers")
	s.step(10.0,true,true,true)
	check(s.current==0.0 and not s.can_sprint(),"Stamina clamps at zero and disables sprint")
	s.step(0.9,false,false,true)
	s.step(1.0,false,false,true)
	check(not s.can_sprint(),"Exhaustion remains latched below restart threshold")
	s.step(0.5,false,false,true)
	check(s.can_sprint(),"Enough recovery unlocks sprint again")
	s.current=20.0
	s.enter_zone(1,&"chapel")
	s.enter_zone(2,&"statue_court")
	s.step(1.0,false,false,true)
	check(is_equal_approx(s.current,55.0),"Overlapping recovery zones do not stack")
	s.leave_zone(1)
	check(not s.zones.is_empty(),"Leaving one overlap preserves the other")
	s.restore(1000.0,&"test")
	check(s.current==100.0 and s.percentage()==1.0,"External restore clamps at the maximum")
	s.restore(-20.0,&"test")
	check(s.current==100.0,"Restore cannot secretly drain stamina")
	s.queue_free()

func find_lane() -> Array:
	var space := actor.get_world_3d().direct_space_state
	for r in range(1,18):
		for c in range(1,15):
			var start := Layout.cell_point([r,c])
			if start.distance_to(Vector3(24,0,22.8))<8 or start.distance_to(Vector3(22.8,0,15.6))<6: continue
			var valid := true
			for z: float in [-0.34,0.0,0.34]:
				var a := start+Vector3(0,0.8,z)
				if not space.intersect_ray(PhysicsRayQueryParameters3D.create(a,a+Vector3.RIGHT*6.0,1)).is_empty(): valid=false
			for x: float in [0.0,2.0,4.0,6.0]:
				var a := start+Vector3(x,0.4,0)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a,a-Vector3.UP,1))
				if hit.is_empty() or absf(hit.position.y)>0.08: valid=false
			if generator.get("barriers") is Array:
				for barrier: Node3D in generator.barriers:
					var nearest := Geometry3D.get_closest_point_to_segment(barrier.global_position,start,start+Vector3.RIGHT*6.0)
					if nearest.distance_to(barrier.global_position)<1.6:valid=false
			if valid: return [start,start+Vector3.RIGHT*6.0]
	return []

func zones_and_cakes(id: int) -> void:
	var s = actor.stamina
	await place(Vector3(25.35,0,23.2))
	check(&"chapel" in s.zones.values(),"Chapel interior is a real recovery Area3D")
	s.current=20.0
	s.since_sprint=0.0
	await ticks(60)
	check(s.current>47.0 and s.current<57.0,"Chapel continuously recovers at a faster rate, not instant refill")
	await capture("maze"+str(id+1)+"_chapel_recovery")
	await place(Vector3(24,0,18.0))
	check(&"chapel" not in s.zones.values(),"Chapel trigger does not spill outside the building")
	await place(Vector3(21.25,0,15.2))
	check(&"statue_court" in s.zones.values(),"Statue courtyard is a real recovery Area3D")
	s.current=20.0
	s.since_sprint=0.0
	await ticks(60)
	check(s.current>47.0,"Courtyard continuously restores stamina")
	await capture("maze"+str(id+1)+"_court_recovery")
	await place(Vector3(18.5,0,15.6))
	check(s.zones.is_empty(),"Courtyard trigger stays out of the adjacent passage")
	var perks=scene._perks
	var expected := [Vector3(13.2,0,8.4),Vector3(42,0,30)] if id==0 else [Vector3(8.4,0.9,13.2),Vector3(44.4,0,25.2)]
	check(perks.pickups.size()==(4 if id==0 else 2),"Pickup counts unchanged")
	for i in 2:
		var pickup=perks.pickups[i]
		check(pickup.position.is_equal_approx(expected[i]),"Marked cake position "+str(pickup.position))
		var query:=PhysicsRayQueryParameters3D.create(expected[i]+Vector3.UP*2.0,expected[i]-Vector3.UP*0.3,1)
		var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y-expected[i].y)<0.08,"Cake rests at the actual walkable floor height")
		var items=scene.get_node("MazeItems")
		check((items.guidance_routes() if items.has_method("guidance_routes") else items._routes).path_to_nearest(actor.spawn_point,PackedVector3Array([pickup.position])).size()>1,"New cake position is connected to the entrance")
		s.current=20.0
		s.since_sprint=0.0
		items.inventory.clear_items()
		await place(pickup.position)
		check(s.restore_counts.get(&"cake",0)==i,"Stored pickup does not restore stamina before use")
		items.inventory.select_item(&"ChocolateCake")
		items.inventory.request_selected_use()
		check(pickup.claimed and s.restore_counts.get(&"cake",0)==i+1,"Active cake use calls the shared restore interface once")
		check(s.current>=64.9 and s.current<=67.0 and actor.move_speed_multiplier==1.3,"Cake restores 45 and retains the existing 1.3x boost")
		await ticks(15)
		check(s.restore_counts.get(&"cake",0)==i+1,"Claimed cake cannot restore twice")

func barriers_and_recording() -> void:
	var s=actor.stamina
	var barrier: Area3D=generator.barriers[0]
	var frame:=barrier.get_parent()
	var movement:=Camera3D.new()
	actor.get_parent().add_child(movement)
	actor.movement_camera=movement
	var start: Vector3=frame.to_global(Vector3(0,0,1.6))
	start.y=frame.global_position.y
	await place(start)
	s.current=20.0
	s.since_sprint=0.0
	var direction: Vector3=-frame.global_basis.z
	var code:=KEY_W if absf(direction.z)>0.5 else KEY_A
	if (Vector3.FORWARD if code==KEY_W else Vector3.LEFT).dot(direction)<0: code=KEY_S if code==KEY_W else KEY_D
	key(code,true)
	await ticks(40)
	check(actor in barrier.touching and not barrier.stamina_recovery_used,"Entering the sensor on one side without crossing cannot restore")
	release()
	var opposite:=KEY_S if code==KEY_W else KEY_W if code==KEY_S else KEY_D if code==KEY_A else KEY_A
	key(opposite,true)
	await ticks(32)
	release()
	check(not barrier.stamina_recovery_used and s.restore_counts.get(&"barrier",0)==0,"Entering and backing away on the same side cannot restore")
	key(code,true)
	await ticks(85)
	release()
	check(barrier.stamina_recovery_used and int(s.restore_counts.get(&"barrier",0))==1,"Physical barrier crossing restores exactly once")
	check(actor.boost_remaining>0.0,"Existing barrier speed boost remains active")
	await capture("maze3_barrier_restore")
	key(opposite,true)
	await ticks(70)
	release()
	check(s.restore_counts.get(&"barrier",0)==1,"Returning through the same barrier cannot farm stamina")
	scene.reset_walk()
	await ticks(5)
	check(not barrier.stamina_recovery_used and s.restore_counts.is_empty(),"New challenge resets per-barrier allowance")
	for index in generator.barriers.size():
		var other: Area3D = generator.barriers[index]
		var portal := other.get_parent()
		await place(portal.to_global(Vector3(0,0,1.6)))
		s.current = 20.0
		await walk_to(portal.to_global(Vector3(0,0,-1.6)),"Cross actual stamina barrier "+str(index+1),false)
		check(other.stamina_recovery_used and s.restore_counts.get(&"barrier",0)==index+1,"Each of the six barrier instances has its own allowance")
	scene.reset_walk()
	await ticks(5)
	var timing=scene.get_node("RouteTimingTest")
	timing.output_path="res://../.verification/stamina/route_smoke.csv"
	timing.arm("B","managed")
	await ticks(10)
	check(timing.armed and not timing.running,"Timer waits for real movement at the entrance")
	actor.movement_camera=movement
	key(KEY_W,true)
	await ticks(10)
	release()
	check(timing.running and timing.elapsed>0.0,"Moving out of the entrance starts measurement")
	# Teleport only to exercise the finish trigger; this is not a measured route run.
	await place(timing.finish_trigger.position-Vector3.UP*0.8)
	check(not timing.running and timing.last_result.has("stamina_remaining"),"Real finish Area records results once")
	check(timing.last_result.get("route","")=="B" and FileAccess.file_exists(timing.output_path),"Route/mode and metrics persist to CSV")
	for route: String in ["A","B"]:
		for mode: String in ["walk","managed","maximum"]:
			timing.arm(route,mode)
			check(timing.armed and timing.test_mode==mode,"All six route/mode combinations arm")
	scene.reset_walk()
	check(not timing.running and not timing.armed,"Reset cancels unfinished timing")

func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder.path_join(id+".png")))

func place(point: Vector3) -> void:
	actor.position=point+Vector3.UP*0.03
	actor.velocity=Vector3.ZERO
	await ticks(8)
