extends "res://tests/levels/check_maze_01_greybox.gd"
const Clock := preload("res://modules/maze03_race/runner_clock.gd")
var race: Node
var folder := "res://../.verification/maze03-mouse-boost"
var records: Array = []
func shot(id: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder.path_join(id+".png")))
func start_race() -> void:
 race.pending_mode="Race"
 scene.reset_walk()
 for i in 300:
  if race.state=="RACING":return
  await ticks(1)
 check(false,"Race starts")
func run() -> void:
 root.size=Vector2i(1440,1000)
 scene=load("res://scenes/levels/Maze03.tscn").instantiate()
 root.add_child(scene)
 actor=scene.get_node("%Player")
 generator=scene.get_node("%GeneratedMaze")
 race=scene.race
 race.output_path=folder.path_join("logic_results.csv")
 await ticks(10)
 check(race.current_mode=="Explore" and race.mouse==null and race.hud==null,"Explore still has no opponent or race overlay")
 await start_race()
 check(race.mouse.collision_layer==0 and race.mouse.collision_mask==0,"Opponent cannot block or trigger Charlie-specific Areas")
 check(race.route.barrier_events.size()==4,"Actual route intersects four energy barriers")
 # Same deterministic integrator, different frame steps and real-time speed windows.
 for fps: int in [30,60,120]:
  var clock := Clock.new()
  clock.configure(race.route,race.settings,race.route.base_speed)
  var first_boost_at := -1.0
  var first_expiry := -1.0
  for frame in fps*80:
   var before: float = clock.boost_remaining
   clock.advance(1.0/fps)
   if first_boost_at<0 and clock.crossing_count>0:first_boost_at=clock.seconds
   if first_boost_at>0 and first_expiry<0 and before>0 and clock.boost_remaining<=0:first_expiry=clock.seconds
   if clock.finished:break
  check(absf(clock.seconds-race.settings.target_seconds)<0.03,"Arrival stable at physics rate "+str(fps))
  check(clock.crossing_count==4 and clock.hesitation_count==2,"Same crossings/pauses at "+str(fps))
  check(absf(first_expiry-first_boost_at-race.route.barrier_seconds)<0.04,"Barrier really lasts configured seconds")
  records.append({"physics_fps":fps,"arrival":clock.seconds,"crossings":clock.crossing_count,"first_boost_at":first_boost_at,"first_expiry":first_expiry})
 var hidden_sample := -1.0
 for repeat in (1 if OS.get_cmdline_user_args().has("--once") else 2):
  if repeat>0:await start_race()
  var initial = race.mouse.position
  var crossing_count := 0
  var unboosted_speed := 0.0
  var boosted_speed := 0.0
  var previous = race.mouse.position
  while not race.mouse_finished and race.elapsed<67.0:
   await ticks(1)
   var speed = race.mouse.position.distance_to(previous)*60.0
   previous=race.mouse.position
   if race.elapsed>0.3 and race.elapsed<1.3:unboosted_speed=maxf(unboosted_speed,speed)
   if race.elapsed>2.0 and race.elapsed<3.2:boosted_speed=maxf(boosted_speed,speed)
   if race.crossing_log.size()>crossing_count:
    crossing_count=race.crossing_log.size()
    if crossing_count==1:
     var first: Area3D = race.route.barrier_events[0].barrier
     check(race.mouse.speed_ribbons.stamp_count>0,"Opening boost emits bounded blue pose afterimages")
     check(not first.stamina_recovery_used,"Mouse boost does not spend Charlie's one-time recovery")
     check(first.touching.is_empty(),"Mouse is not treated as Charlie by existing trigger")
     await shot("mouse_first_barrier")
   if race.presentation.phase=="HIDDEN" and hidden_sample<0:
    hidden_sample=race.elapsed
    check(not race.mouse.is_visible_in_tree() and race.runner.cost>0.0,"Hidden mesh still has live path progress")
    var at_hide = race.mouse.position
    await ticks(30)
    check(not race.mouse.is_visible_in_tree() and race.mouse.position.distance_to(at_hide)>0.5,"Continues physically along path while invisible")
    await shot("mouse_hidden")
  print("VERIFY COMPLETED LIVE ROUND ",repeat+1)
  check(absf(race.mouse_time-race.settings.target_seconds)<0.03,"Live full path with boosts still arrives on time")
  check(boosted_speed>unboosted_speed*1.30,"Actual crossing increases live movement speed by 1.35")
  check(unboosted_speed>4.3,"Opening burst is faster than Charlie's 3.645 maximum barrier sprint")
  check(race.crossing_log.size()==4,"Each crossing accounted exactly once")
  check(race.mouse.is_visible_in_tree() and race.mouse.opacity>0.99 and race.mouse.current_clip==&"Dance","Reappears and dances at finish")
  check(race.presentation.hidden_under_cover and race.presentation.hidden_gap>6.0,"Opening hide occurs under cover after a real gap")
  check(race.presentation.revealed_time>race.settings.target_seconds-9.0 and race.presentation.revealed_time<race.settings.target_seconds-4.0,"Returns roughly seven seconds before finish")
  check(race.state=="RACING" and actor.controls_enabled,"Mouse finish still lets Charlie continue")
  records.append({"repeat":repeat+1,"arrival":race.mouse_time,"opening_speed":unboosted_speed,"barrier_speed":boosted_speed,"hidden_at":race.presentation.hidden_time,"reveal_at":race.presentation.revealed_time,"crossings":race.crossing_log.duplicate(true)})
  await shot("mouse_finish_visible")
 # Restart clears all boost/presentation state and preserves side-by-side preparation.
 race.pending_mode="Race"
 scene.reset_walk()
 await ticks(6)
 check(race.presentation.phase=="OPENING" and race.mouse.opacity==1.0 and race.crossing_log.is_empty(),"Restart clears invisibility and crossing history")
 check(race.runner.boost_remaining==0.0 and race.runner.cost==0.0,"Restart clears opponent boost and path")
 await shot("side_by_side_reset")
 race.pending_mode="Explore"
 scene.reset_walk()
 await ticks(4)
 check(race.mouse==null and race.hud==null and actor.controls_enabled,"Explore restores full original state")
 var file := FileAccess.open(folder.path_join("measurements.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(records,"  "))
 file.close()
 print("MOUSE BOOST / HIDE ","PASS" if failures==0 else "FAIL"," failures=",failures," samples=",JSON.stringify(records))
 scene.queue_free()
 await ticks(4)
 OS.delay_msec(150)
 quit(failures)
