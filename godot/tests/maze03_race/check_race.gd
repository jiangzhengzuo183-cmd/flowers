extends "res://tests/levels/check_maze_01_greybox.gd"
var race: Node
var samples: Array = []
var folder := "res://../.verification/maze03-race"
var visual_run := false
func shot(id: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder.path_join(id+".png")))
func wait_state(id: String, limit: int = 300) -> bool:
 for i in limit:
  if race.state==id:return true
  await ticks(1)
 check(false,"State timeout "+id+" actual "+race.state)
 return false
func start_race() -> void:
 release()
 race.pending_mode="Race"
 scene.reset_walk()
 await ticks(5)
 if race.state=="ERROR":check(false,race.route.error);return
 check(race.state=="PREPARATION","Preparation phase")
 check(race.mouse.current_clip==&"Scratch","Scratch in preparation")
 check(absf(actor.position.z-race.mouse.position.z)<0.09 and actor.position.x-race.mouse.position.x>0.65,"Side-by-side starting lanes")
 var p := actor.position
 key(KEY_W,true)
 key(KEY_SPACE,true)
 await ticks(10)
 check(actor.position.distance_to(p)<0.03 and not actor.controls_enabled,"Preparation locks actual movement and jumping")
 key(KEY_SPACE,false)
 release()
 scene.set_walk_mode(true)
 check(not actor.controls_enabled,"Switching view cannot bypass countdown lock")
 await wait_state("COUNTDOWN")
 await ticks(3)
 check(race.hud.headline.text=="3" and race.elapsed==0.0,"Countdown starts at 3, timer zero")
 await shot("countdown_3")
 await ticks(60)
 check(race.hud.headline.text=="2" and race.elapsed==0.0,"Countdown 2")
 await ticks(60)
 check(race.hud.headline.text=="1" and race.elapsed==0.0,"Countdown 1")
 await wait_state("RACING")
 check(actor.controls_enabled and race.elapsed==0.0 and race.mouse_cost==0.0,"GO unlocks both from the same zero clock")
 check(race.hud.headline.text=="GO!" and race.mouse.current_clip==&"Run","GO and running animation")
 await shot("go")
func run() -> void:
 Input.use_accumulated_input=false
 root.size=Vector2i(1440,1000)
 scene=load("res://scenes/levels/Maze03.tscn").instantiate()
 root.add_child(scene)
 actor=scene.get_node("%Player")
 generator=scene.get_node("%GeneratedMaze")
 race=scene.race
 race.output_path=folder.path_join("results.csv")
 await ticks(15)
 check(race.current_mode=="Explore" and race.state=="EXPLORE","Explore is default")
 check(race.mouse==null and race.hud==null and actor.controls_enabled,"Explore has no opponent, countdown or race UI")
 var initial := actor.position
 var input_camera := Camera3D.new()
 actor.get_parent().add_child(input_camera)
 actor.movement_camera=input_camera
 key(KEY_W,true)
 key(KEY_SHIFT,true)
 await ticks(25)
 release()
 check(actor.position.distance_to(initial)>0.5 and actor.stamina.current<99.0,"Explore retains actual sprint and stamina")
 race.request_mode("Race")
 await start_race()
 check(race.route.error.is_empty() and race.route.clearance_checks>1300,"Every sampled segment passes capsule collision sweep")
 check(race.route.cells!=scene.maze_data.routes.A.cellPath and race.route.cells!=scene.maze_data.routes.B.cellPath,"Route is not a copy of A or B")
 check(race.route.cells.any(func(c):return Layout.cell_key(c)=="3,13") and race.route.cells.any(func(c):return Layout.cell_key(c)=="18,10"),"A main route plus northern branch")
 var points: Array = []
 for point in race.route.points:points.append([point.x,point.y,point.z])
 var report := {"metres":race.route.length,"base_speed":race.route.base_speed,"fast_start":race.route.base_speed*race.settings.fast_start,"middle":race.route.base_speed*race.settings.relaxed_middle,"finish":race.route.base_speed*race.settings.fast_finish,"checks":race.route.clearance_checks,"points":points}
 var file := FileAccess.open(folder.path_join("route.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(report))
 file.close()
 # No input while mouse completes: there is deliberately no deadline loss.
 while not race.mouse_finished and race.elapsed<67.0:
  await ticks(1)
 check(race.mouse_finished and absf(race.mouse_time-race.settings.target_seconds)<0.025,"First full real route finishes at target")
 check(race.hesitation_count==2 and race.mouse.current_clip==&"Dance","Two hesitations and finish dance")
 check(race.state=="RACING" and race.result.is_empty() and actor.controls_enabled,"Mouse finish alone never ends race or locks Charlie")
 var clock = race.elapsed
 await ticks(ceili(maxf(3.0,66.0-race.elapsed)*60.0))
 check(race.elapsed>clock+1.4,"Clock keeps counting beyond mouse arrival")
 # Future sanctuary interfaces affect the opponent only; not wired to a trigger.
 check(race.has_signal("sanctuary_activated") and race.has_signal("sanctuary_ended"),"Sanctuary signals reserved")
 await shot("mouse_first_clock_continues")
 # Deliver Charlie to the existing finish through actual local movement (not a synthetic finish signal).
 actor.position=Vector3(44.4,0.03,3.6)
 actor.velocity=Vector3.ZERO
 actor.movement_camera=input_camera
 key(KEY_W,true)
 key(KEY_SHIFT,true)
 for i in 200:
  if race.state=="FINISHED":break
  await ticks(1)
 release()
 check(race.state=="FINISHED" and race.result.outcome=="mouse","Charlie actually enters exit and records loss")
 check(race.charlie_time>race.mouse_time and race.charlie_time>65.0,"No forced 65-second loss; actual Charlie time")
 samples.append(race.result.duplicate())
 var finish_time = race.elapsed
 await ticks(20)
 check(race.elapsed==finish_time,"Timer stops at Charlie finish")
 await shot("result_mouse_wins")
 # Requests during an active race apply on restart, without mutating current state.
 await start_race()
 await ticks(100)
 var saved_cost = race.mouse_cost
 var saved_pos = race.mouse.position
 race.pause_mouse()
 await ticks(20)
 check(race.mouse.position.is_equal_approx(saved_pos) and race.mouse_cost==saved_cost and actor.controls_enabled,"Pause interface stops only mouse")
 race.resume_mouse()
 race.set_mouse_speed_multiplier(0.5)
 await ticks(30)
 check(race.mouse_cost>saved_cost and race.elapsed>0.0,"Mouse slowdown interface resumes path with live clock")
 race.set_mouse_speed_multiplier(1.0)
 race.request_mode("Explore")
 check(race.current_mode=="Race" and race.pending_mode=="Explore" and race.state=="RACING","Mode changes wait for restart")
 scene.reset_walk()
 await ticks(5)
 check(race.current_mode=="Explore" and race.mouse==null and race.hud==null and actor.controls_enabled,"Explore restart removes all race state")
 check(actor.stamina.current==actor.stamina.settings.maximum,"Restart resets stamina")
 # Test full fixed path again, at original unmodified speed, with the real common clock.
 await start_race()
 while not race.mouse_finished and race.elapsed<67.0:await ticks(1)
 check(absf(race.mouse_time-race.settings.target_seconds)<0.025,"Second full route has identical arrival")
 actor.position=Vector3(44.4,0.03,3.6)
 actor.velocity=Vector3.ZERO
 actor.movement_camera=input_camera
 key(KEY_W,true)
 key(KEY_SHIFT,true)
 for i in 200:
  if race.state=="FINISHED":break
  await ticks(1)
 release()
 samples.append(race.result.duplicate())
 # Early player win must not be overwritten by a later mouse event.
 await start_race()
 actor.position=Vector3(44.4,0.03,3.6)
 actor.velocity=Vector3.ZERO
 actor.movement_camera=input_camera
 key(KEY_W,true)
 key(KEY_SHIFT,true)
 for i in 200:
  if race.state=="FINISHED":break
  await ticks(1)
 release()
 check(race.result.outcome=="charlie" and race.mouse_time<0.0,"Immediate Charlie victory while mouse unfinished")
 var snapshot = race.result.duplicate()
 await ticks(4000)
 check(race.result==snapshot,"Later ticks cannot overwrite Charlie win")
 # Tie evaluated using actual finish volume in a shared physics tick.
 await start_race()
 while race.elapsed<race.settings.target_seconds-0.05:await ticks(1)
 actor.position=Vector3(44.4,0.03,1.8)
 actor.velocity=Vector3.ZERO
 await ticks(4)
 check(race.state=="FINISHED" and race.result.outcome in ["charlie","tie"],"Near simultaneous finish resolves once")
 file=FileAccess.open(folder.path_join("smoke_results.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(samples,"  "))
 file.close()
 race.pending_mode="Explore"
 scene.reset_walk()
 await ticks(3)
 check(race.mouse==null and race.hud==null,"No leftover opponent or overlay after repeated resets")
 print("MAZE03 RACE INTEGRATION ","PASS" if failures==0 else "FAIL"," failures=",failures," results=",samples)
 scene.queue_free()
 await ticks(3)
 quit(failures)
