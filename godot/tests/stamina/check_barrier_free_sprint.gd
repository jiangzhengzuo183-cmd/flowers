extends "res://tests/stamina/check_stamina.gd"
func run() -> void:
	scene=Levels[2].instantiate()
	root.add_child(scene)
	actor=scene.get_node("%Player")
	generator=scene.get_node("%GeneratedMaze")
	await ticks(16)
	scene.earthquakes.next_event=INF
	scene.earthquakes.minor_next=INF
	var movement:=Camera3D.new()
	actor.get_parent().add_child(movement)
	actor.movement_camera=movement
	var lane:=find_lane()
	check(not lane.is_empty(),"Find a real clear corridor for speed measurements")
	if lane.is_empty(): quit(1); return
	var s=actor.stamina
	var walking_boost:=0.0
	for shift in [false,true]:
		await place(lane[0])
		s.current=55.0
		s.since_sprint=0.0
		s.is_exhausted=false
		var sprint_before: float=s.sprint_seconds
		actor.apply_boost()
		key(KEY_D,true)
		await set_sprint(shift)
		await ticks(25)
		var speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
		check(absf(speed-3.645)<0.02,"Barrier uses the running boost speed with Shift="+str(shift)+" actual="+str(speed))
		check(s.current>=54.99 and s.sprint_seconds==sprint_before,"Neither input drains stamina during the boost")
		check(actor.speed_ribbons.stamp_count>0,"Fast movement still produces the existing afterimages")
		if not shift: walking_boost=speed
		else: check(absf(walking_boost-speed)<0.01,"Walking and sprint input receive identical boost speed")
		actor.apply_boost()
		await ticks(5)
		check(absf(Vector2(actor.velocity.x,actor.velocity.z).length()-3.645)<0.02,"Refresh does not stack speed")
		release()
		await ticks(190)
		check(actor.boost_remaining==0.0,"Boost still expires after its configured duration")
		check(s.current>55.0,"Ordinary delayed regeneration still works while sprint cost is waived")
		await place(lane[0])
		key(KEY_D,true)
		await set_sprint(shift)
		var before: float=s.current
		await ticks(20)
		check(absf(Vector2(actor.velocity.x,actor.velocity.z).length()-(2.7 if shift else 1.6))<0.02,"Normal walk/run speed resumes after expiry")
		if shift: check(s.current<before-4.0,"Manual sprint cost resumes after expiry")
		release()
	await place(lane[0])
	s.current=0.0
	s.is_exhausted=true
	actor.apply_boost()
	key(KEY_D,true)
	await set_sprint(true)
	await ticks(15)
	check(absf(Vector2(actor.velocity.x,actor.velocity.z).length()-3.645)<0.02 and s.current>=0.0,"An exhausted player still receives the full free barrier boost")
	release()
	scene.reset_walk()
	await ticks(4)
	check(actor.boost_remaining==0.0 and s.current==100.0,"Restart clears the free boost and resets stamina")
	print("FREE BARRIER SPRINT ","PASS" if failures==0 else "FAIL"," failures=",failures)
	scene.queue_free()
	await process_frame
	await process_frame
	quit(failures)
