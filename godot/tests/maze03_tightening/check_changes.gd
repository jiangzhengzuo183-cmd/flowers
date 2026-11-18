extends "res://tests/stamina/check_stamina.gd"
var records: Array=[]
var output := "res://../.verification/maze03-tightening"
func raw_shift(pressed: bool, echo: bool = false) -> void:
 var event:=InputEventKey.new()
 event.physical_keycode=KEY_SHIFT
 event.pressed=pressed
 event.echo=echo
 Input.parse_input_event(event)
func tap_shift() -> void:
 raw_shift(false)
 await ticks(1)
 raw_shift(true)
 await ticks(1)
 raw_shift(false)
 await ticks(1)
func shot(id: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output.path_join(id+".png")))
func run() -> void:
 Input.use_accumulated_input=false
 root.size=Vector2i(1440,1000)
 for level in 3:
  scene=Levels[level].instantiate()
  root.add_child(scene)
  actor=scene.get_node("%Player")
  generator=scene.get_node("%GeneratedMaze")
  await ticks(16)
  var input_camera:=Camera3D.new()
  actor.get_parent().add_child(input_camera)
  actor.movement_camera=input_camera
  var lane:=find_lane()
  check(not lane.is_empty(),"Real corridor for level "+str(level+1))
  await place(lane[0])
  key(KEY_D,true)
  await ticks(15)
  print("WALK SAMPLE level=",level+1," lane=",lane," toggle=",actor.sprint_toggled," speed=",actor.velocity," boost=",actor.get("boost_remaining"))
  check(not actor.sprint_toggled and absf(Vector2(actor.velocity.x,actor.velocity.z).length()-1.6)<0.05,"Default walking "+str(level+1))
  key(KEY_D,false)
  await tap_shift()
  check(actor.sprint_toggled and not Input.is_physical_key_pressed(KEY_SHIFT),"One tap latches sprint after release "+str(level+1))
  await place(lane[0])
  actor.stamina.current=80.0
  key(KEY_D,true)
  await ticks(25)
  check(absf(actor.velocity.x-2.7)<0.02 and actor.stamina.current<74.0,"Latched sprint really moves and drains stamina "+str(level+1))
  await tap_shift()
  await ticks(3)
  check(not actor.sprint_toggled and absf(actor.velocity.x-1.6)<0.02,"Second tap immediately returns to walking")
  raw_shift(true)
  await ticks(1)
  for i in 12:
   raw_shift(true,true)
   await ticks(1)
  check(actor.sprint_toggled,"OS key repeat does not retrigger toggle")
  raw_shift(false)
  await ticks(1)
  check(actor.sprint_toggled,"Releasing Shift leaves sprint enabled")
  key(KEY_D,false)
  await ticks(3)
  var resting:float=actor.stamina.current
  await ticks(8)
  check(actor.stamina.current>=resting-0.01,"Latched sprint standing still has no cost")
  await place(lane[0])
  actor.stamina.current=0.25
  actor.stamina.is_exhausted=false
  key(KEY_D,true)
  await ticks(25)
  check(actor.sprint_toggled and actor.stamina.is_exhausted and absf(actor.velocity.x-1.6)<0.02,"Exhaustion stops running without corrupting toggle")
  key(KEY_D,false)
  actor.reset_player()
  await ticks(2)
  check(not actor.sprint_toggled and actor.stamina.current==100.0,"Reset clears sprint latch")
  actor.controls_enabled=false
  await tap_shift()
  actor.controls_enabled=true
  check(not actor.sprint_toggled,"Disabled controls cannot arm sprint")
  await place(lane[0])
  await tap_shift()
  key(KEY_D,true)
  key(KEY_SPACE,true)
  await ticks(6)
  key(KEY_SPACE,false)
  check(actor.position.y>lane[0].y+0.12 and actor.velocity.x>2.6,"Toggle sprint still supports jumping")
  release()
  await ticks(45)
  if level==2:
   actor.reset_player()
   await ticks(3)
   await place(lane[0])
   actor.stamina.current=40.0
   actor.apply_boost()
   key(KEY_D,true)
   await ticks(20)
   check(absf(actor.velocity.x-3.645)<0.02 and actor.stamina.current>=40.0,"Barrier gives free running speed with toggle off")
   await tap_shift()
   check(absf(actor.velocity.x-3.645)<0.02,"Toggle on does not stack barrier speed")
   await tap_shift()
   check(not actor.sprint_toggled and actor.stamina.current>=40.0,"Toggle off leaves free barrier boost active")
   release()
   await ticks(190)
   check(actor.boost_remaining==0.0 and not actor.sprint_toggled,"Boost expires to selected walking state")
   await map_and_vision(input_camera)
  records.append({"maze":level+1,"toggle":"pass"})
  release()
  raw_shift(false)
  scene.queue_free()
  await ticks(4)
  OS.delay_msec(80)
 print("MAZE TIGHTENING / THREE TOGGLES ","PASS" if failures==0 else "FAIL"," failures=",failures," results=",records)
 OS.delay_msec(150)
 quit(failures)
func map_and_vision(input_camera: Camera3D) -> void:
 scene.reset_walk()
 await ticks(6)
 var divider:Node3D=generator.get_node("VerticalWalls/WallSegment_V_4_12")
 var mesh:MeshInstance3D=divider.get_child(0)
 var bounds:AABB=mesh.global_transform*mesh.get_aabb()
 check(bounds.end.z>14.32 and bounds.position.z<9.6,"Requested northern wall reaches pool edge visibly")
 for z:float in [12.5,13.3,14.2]:
  var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(28.0,0.6,z),Vector3(29.5,0.6,z),1))
  check(not hit.is_empty() and hit.collider==divider,"Visible extension has matching collision at "+str(z))
 await place(Vector3(27.9,0,13.2))
 actor.movement_camera=input_camera
 key(KEY_D,true)
 await ticks(60)
 release()
 check(actor.position.x<28.37,"Player cannot cross the newly sealed shortcut")
 await place(Vector3(27.6,0,10.8))
 var rig=scene.get_node("%FollowRig")
 rig.distance=5.0
 rig.pitch=0.7
 rig.yaw= -PI*0.5+0.08
 await ticks(12)
 await shot("north_wall_after")
 var race=scene.race
 race.output_path=output.path_join("races.csv")
 race.request_mode("Race")
 for i in 300:
  if race.state=="RACING":break
  await ticks(1)
 check(race.route.error.is_empty(),"Mouse path still clears all walls")
 while race.elapsed<8.0:await ticks(1)
 check(not race.mouse.visible,"Normal midrace mouse is hidden before sanctuary")
 await place(Vector3(24,0,23.6))
 key(KEY_E,true)
 await ticks(1)
 key(KEY_E,false)
 await ticks(60)
 var vision=race.sanctuary.vision
 check(race.sanctuary.active and vision.opponent_cue!=null,"Sanctuary creates real mouse silhouette")
 await create_timer(0.0).timeout
 var cue:MeshInstance3D=vision.opponent_cue.copies[0]
 var source:MeshInstance3D=vision.opponent_cue.sources[0]
 check(cue.visible and cue.global_transform.is_equal_approx(source.global_transform),"Hidden opponent outline remains at actual current position")
 check(cue.skin==source.skin and cue.mesh==source.mesh and cue.material_override.shader==preload("res://modules/maze02_items/vision_pickup.gdshader"),"Mouse uses original skinned pill silhouette style")
 check(not race.mouse.visible,"Vision does not unhide normal mouse model")
 scene.show_top_view()
 await ticks(4)
 await shot("global_vision_mouse")
 scene.set_walk_mode(true)
 var camera:=Camera3D.new()
 actor.get_parent().add_child(camera)
 camera.fov=48.0
 camera.look_at_from_position(race.mouse.global_position+Vector3(0.5,0.85,1.0),race.mouse.global_position+Vector3.UP*0.32)
 camera.make_current()
 await ticks(4)
 await shot("mouse_outline_close")
 camera.free()
 scene.get_node("%FollowRig").camera.make_current()
 for i in 400:
  if not race.sanctuary.active:break
  await ticks(1)
 check(not vision._screen.visible and not race.mouse.visible,"Effect ends without revealing normally hidden mouse")
 # Fresh run: no sanctuary, unchanged physical route and deterministic 58-second finish.
 race.pending_mode="Race"
 scene.reset_walk()
 for i in 300:
  if race.state=="RACING":break
  await ticks(1)
 while not race.mouse_finished and race.elapsed<62.0:await ticks(1)
 check(absf(race.mouse_time-58.0)<0.03,"Actual complete opponent run arrives at 58 seconds")
 check(race.crossing_log.size()==4 and race.hesitation_count==2,"Same four boosts and two hesitations")
 records.append({"mouse_finish":race.mouse_time,"north_wall_end":bounds.end.z,"mouse_outline":"pass"})
