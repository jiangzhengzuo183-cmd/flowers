extends "res://tests/levels/check_maze_01_greybox.gd"
var race: Node
var records: Array = []
var folder := "res://../.verification/maze03-race"
var pause_samples := 0
var movement_samples := 0
func shot(id: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder.path_join(id+".png")))
func run() -> void:
 Input.use_accumulated_input=false
 root.size=Vector2i(1440,1000)
 scene=load("res://scenes/levels/Maze03.tscn").instantiate()
 root.add_child(scene)
 actor=scene.get_node("%Player")
 generator=scene.get_node("%GeneratedMaze")
 race=scene.race
 race.output_path=folder.path_join("full_runs.csv")
 var input_camera := Camera3D.new()
 actor.get_parent().add_child(input_camera)
 await ticks(10)
 for trial in 2:
  race.pending_mode="Race"
  scene.reset_walk()
  for i in 300:
   if race.state=="RACING":break
   await ticks(1)
  check(race.state=="RACING","Full race begins "+str(trial))
  actor.movement_camera=input_camera
  var cells: Array = scene.maze_data.routes.A.cellPath if trial==0 else race.route.cells
  var goals := PackedVector3Array()
  var raw: Array = cells.duplicate()
  if trial==0:
   # Use the existing open shortcut, then take clean diagonal corner approaches.
   var cut := -1
   for i in raw.size():
    if Layout.cell_key(raw[i])=="14,11":cut=i
   if cut>=0:raw=raw.slice(0,cut+1)+raw.slice(cut+4)
  for i in raw.size():
   var centre := Layout.cell_point(raw[i])
   if trial==0 and i>0 and i<raw.size()-1:
    var incoming := (centre-Layout.cell_point(raw[i-1])).normalized()
    var outgoing := (Layout.cell_point(raw[i+1])-centre).normalized()
    if absf(incoming.dot(outgoing))<0.01:
     goals.append(centre-incoming*0.38)
     goals.append(centre+outgoing*0.38)
    else:goals.append(centre)
   else:goals.append(centre)
  var goal_index := 1
  var active_keys: Array[int] = []
  key(KEY_SHIFT,true)
  var last_pause_count := 0
  var phases: Dictionary = {}
  var last_distance := 0.0
  var last_mouse = race.mouse.position
  var stuck := 0
  var prev_charlie := actor.position
  while race.state=="RACING" and race.elapsed<130.0:
   if goal_index<goals.size():
    var goal := goals[goal_index]
    var offset := Vector2(goal.x-actor.position.x,goal.z-actor.position.z)
    if offset.length()<0.065:
     goal_index+=1
    else:
     var wanted: Array[int] = []
     var x_active := absf(offset.x)>0.045
     var z_active := absf(offset.y)>0.045
     if trial==0 and x_active and z_active and minf(absf(offset.x),absf(offset.y))/maxf(absf(offset.x),absf(offset.y))>0.5:
      wanted.append(KEY_D if offset.x>0 else KEY_A)
      wanted.append(KEY_S if offset.y>0 else KEY_W)
     elif absf(offset.x)>absf(offset.y):wanted.append(KEY_D if offset.x>0 else KEY_A)
     else:wanted.append(KEY_S if offset.y>0 else KEY_W)
     for held_key in active_keys:
      if held_key not in wanted:key(held_key,false)
     for new_key in wanted:
      if new_key not in active_keys:key(new_key,true)
     active_keys=wanted
   await ticks(1)
   if actor.position.distance_to(prev_charlie)<0.001:stuck+=1
   else:stuck=0
   prev_charlie=actor.position
   if stuck>200:
    check(false,"Actual route blocked at "+str(actor.position)+" goal "+str(goals[mini(goal_index,goals.size()-1)]))
    break
   var progress: float = race.route.sample(race.mouse_cost).distance/race.route.length
   var phase := "start" if progress<0.16 else ("middle" if progress>0.30 and progress<0.62 else ("finish" if progress>0.82 else "transition"))
   if race.pause_remaining>0.02:
    pause_samples+=1
    check(race.mouse.current_clip==&"Turn","Turn animation only while hesitating")
    if last_pause_count!=race.hesitation_count:
     last_pause_count=race.hesitation_count
     await shot("hesitation_"+str(last_pause_count))
   elif not race.mouse_finished:
    movement_samples+=1
    var speed: float = race.mouse.position.distance_to(last_mouse)*60.0
    if not phases.has(phase):phases[phase]=[]
    phases[phase].append(speed)
   last_mouse=race.mouse.position
   if trial==0 and race.elapsed>1.0 and race.elapsed<1.03:await shot("race_actual_play")
   if race.elapsed>18 and race.elapsed<18.03:await shot("race_midway")
  release()
  check(race.state=="FINISHED","Actual full route reaches exit "+str(trial))
  var record: Dictionary = race.result.duplicate()
  record["test_player_route"]="A + existing shortcut + clean corners" if trial==0 else "A+branch"
  record["full_route_no_teleports"]=true
  record["barrier_recoveries"]=int(actor.stamina.restore_counts.get(&"barrier",0))
  record["phases"]={}
  for phase: String in ["start","middle","finish"]:
   if phases.has(phase):
    var sum := 0.0
    for speed in phases[phase]:sum+=speed
    record.phases[phase]=sum/phases[phase].size()
  records.append(record)
  print("FULL ACTUAL RACE ",JSON.stringify(record))
  if record.has("phases") and record.phases.has("finish"):
   check(record.phases.start>record.phases.middle*1.2 and record.phases.finish>record.phases.middle*1.2,"Fast-slow-fast measured actual motion")
  if race.mouse_finished:
   check(absf(race.mouse_time-race.settings.target_seconds)<0.03,"Full-run opponent actual arrival within required window")
  else:
   check(race.result.outcome=="charlie" and race.charlie_time<race.settings.target_seconds,"Winning before the opponent correctly cancels remaining race movement")
  await shot("actual_result_"+str(trial+1))
  await ticks(15)
 check(pause_samples>50 and movement_samples>3000,"Actual moving and hesitation animations sampled")
 var file := FileAccess.open(folder.path_join("full_runs.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(records,"  "))
 file.close()
 print("MAZE03 FULL RUNS ","PASS" if failures==0 else "FAIL"," failures=",failures)
 scene.queue_free()
 await ticks(5)
 quit(failures)
