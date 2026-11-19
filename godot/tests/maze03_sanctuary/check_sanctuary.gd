extends "res://tests/levels/check_maze_01_greybox.gd"
const PillVision := preload("res://modules/maze02_items/vision.gd")
var race: Node
var effect: Node
var folder := "res://../.verification/maze03-sanctuary"
var activated := 0
var ended := 0
var initial_buses := 0
var measurements: Array = []
func shot(id: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder.path_join(id+".png")))
func place(point: Vector3) -> void:
 actor.position=point+Vector3.UP*0.03
 actor.velocity=Vector3.ZERO
 await ticks(6)
func press_e() -> void:
 key(KEY_E,true)
 await ticks(1)
 key(KEY_E,false)
 await ticks(1)
func start_race() -> void:
 release()
 race.pending_mode="Race"
 scene.reset_walk()
 for i in 300:
  if race.state=="RACING":break
  await ticks(1)
 check(race.state=="RACING","New race starts")
 actor.movement_camera=root.find_child("SanctuaryTestInput",true,false)
func activate_near_cube() -> void:
 await place(Vector3(24,0,23.6))
 check(effect.prompt.visible and effect.can_interact(),"Nearby cube shows active E prompt")
 await press_e()
 check(effect.active and race.sanctuary_used and race.sanctuary_active,"E atomically activates one use")
func wait_end(limit: int = 410) -> void:
 for i in limit:
  if not effect.active:return
  await ticks(1)
 check(false,"Sanctuary expiry timeout")
func run() -> void:
 Input.use_accumulated_input=false
 root.size=Vector2i(1440,1000)
 initial_buses=AudioServer.bus_count
 scene=load("res://scenes/levels/Maze03.tscn").instantiate()
 root.add_child(scene)
 actor=scene.get_node("%Player")
 generator=scene.get_node("%GeneratedMaze")
 race=scene.race
 effect=race.sanctuary
 race.output_path=folder.path_join("race_results.csv")
 race.sanctuary_activated.connect(func():activated+=1)
 race.sanctuary_ended.connect(func():ended+=1)
 var input_camera := Camera3D.new()
 input_camera.name="SanctuaryTestInput"
 actor.get_parent().add_child(input_camera)
 await ticks(12)
 # The shared HUD music bus is intentionally application-scoped; only focus buses are scene-local.
 initial_buses=AudioServer.bus_count
 check(InputMap.has_action("interact") and InputMap.action_get_events("interact").size()>0,"Existing input map gains E interact action")
 check(effect.cube==generator.sanctuary.get_node("HoveringBlueCube"),"Uses the original cube instance")
 check(effect.sensor.collision_layer==0 and effect.sensor.collision_mask==2,"Interaction Area is a nonblocking player-only sensor")
 await place(Vector3(24,0,23.6))
 await press_e()
 check(not effect.active and not effect.prompt.visible and race.mouse==null and effect.vision==null,"Explore has no sanctuary activation, opponent or focus mix")
 check(AudioServer.bus_count==initial_buses,"Explore adds no focus audio buses")
 await start_race()
 await press_e()
 check(not race.sanctuary_used and not effect.active,"E at spawn cannot activate")
 # Actual movement from the north doorway into the central interaction area.
 await place(Vector3(24,0,19.65))
 actor.movement_camera=input_camera
 await press_e()
 check(not race.sanctuary_used,"Inside church but too far from cube does not activate")
 check(await walk_to(Vector3(24,0,23.6),"Actual church walk to cube",false),"Existing floor remains walkable")
 check(effect.prompt.visible and not effect.active,"Approaching the cube alone never activates")
 await shot("before_activation")
 key(KEY_SPACE,true)
 await ticks(3)
 key(KEY_SPACE,false)
 await press_e()
 check(not race.sanctuary_used,"Jumping prevents conflicting interaction")
 await ticks(40)
 actor.stamina.current=20.0
 await press_e()
 check(effect.active and actor.stamina.current>=99.0,"Activation restores through existing stamina system")
 check(int(actor.stamina.restore_counts.get(&"sanctuary",0))==1,"Restoration occurs once")
 check(activated==1 and not effect.prompt.visible,"Single activation signal and prompt is hidden")
 check(effect.route_support_missing==0 and effect.global_route.size()>2000,"Global A/branch and B routes follow actual supported floors")
 var vision=effect.vision
 check(vision is PillVision,"Exact original pill vision is the inherited implementation")
 check(vision._screen_material.shader==preload("res://modules/maze02_items/vision_screen.gdshader"),"Same original screen shader")
 check(vision._silhouette.shader==preload("res://modules/maze02_items/vision_pickup.gdshader"),"Same original outline mask")
 check(vision._trail.instance_count>2000 and vision._mesh.get_surface_count()==1,"Global route, six thresholds and exit are marked")
 check(vision._pickups.get_child_count()==0,"Cube has no extra vision highlight")
 check(scene.game_hud.hud.layer>0 and race.hud.get_parent()==scene.game_hud.hud.get_node("HUDRoot/RaceOverlay"),"Shared HUD and race start/result stay above the vision overlay")
 check(vision._screen.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Vision does not intercept camera or player input")
 check(vision.character_cue.copies.size()==1 and vision.character_cue.skeletons.size()==1,"Charlie has one live skinned silhouette, no duplicate actor")
 var source: MeshInstance3D=vision.character_cue.sources[0]
 var copy: MeshInstance3D=vision.character_cue.copies[0]
 check(copy.mesh==source.mesh and copy.skin==source.skin,"Character outline preserves original mesh and skin")
 var start_clock: float=race.elapsed
 var start_track: float=race.runner.seconds
 var player_start := actor.position
 key(KEY_D,true)
 await ticks(30)
 key(KEY_D,false)
 check(absf(actor.position.distance_to(player_start)-0.8)<0.08,"Charlie still moves at ordinary 1.6m/s")
 check(absf((race.elapsed-start_clock)-0.5)<0.04,"Race clock continues at real-time rate")
 check(absf((race.runner.seconds-start_track)-0.025)<0.004,"Opponent's internal time advances at 5 percent")
 check(race.mouse.animation_player.speed_scale>0.0 and race.mouse.animation_player.speed_scale<0.21,"Run animation slows with motion, no minimum-speed clamp")
 check(is_equal_approx(Engine.time_scale,1.0),"Global engine time scale unchanged")
 await ticks(40)
 check(vision._screen_material.get_shader_parameter("strength")>0.95 and vision._screen_material.get_shader_parameter("cue_strength")>0.95,"Original gradual attack reaches full pill effect")
 check(copy.global_transform.is_equal_approx(source.global_transform),"Charlie outline tracks actual world pose")
 await shot("active_player_view")
 scene.show_top_view()
 await ticks(4)
 check(copy.visible,"Charlie remains located in the global vision overview")
 await shot("active_global_overview")
 scene.set_walk_mode(true)
 actor.movement_camera=input_camera
 await press_e()
 check(int(actor.stamina.restore_counts.get(&"sanctuary",0))==1,"Repeated E never restores again or extends time")
 while effect.active and effect.age<5.55:await ticks(1)
 check(effect.active and vision._screen_material.get_shader_parameter("strength")<0.75,"Original pill fade is inside six-second deadline")
 await shot("fading")
 await wait_end()
 check(absf(effect.last_duration-6.0)<0.02 and race.sanctuary_used and not race.sanctuary_active,"Strict 6-second cap, used state persists")
 check(not vision._screen.visible and scene.wall_occlusion.guide_blockers.is_empty(),"Vision releases overlay and wall fades")
 check(is_equal_approx(race.effective_mouse_speed_multiplier(),1.0),"Mouse normal speed restored")
 check(activated==1 and ended==1,"Matching activation/end signals exactly once")
 await place(Vector3(24,0,23.6))
 await press_e()
 check(not effect.active and not effect.prompt.visible,"Returning to cube cannot reuse sanctuary")
 actor.reset_player()
 await ticks(3)
 check(race.sanctuary_used,"Player reposition/reset does not reset race entitlement")
 measurements.append({"case":"stay_inside","seconds":effect.last_duration})
 # Let the actual opponent finish after losing six seconds at 5 percent.
 while not race.mouse_finished and race.elapsed<69.0:await ticks(1)
 check(race.mouse_finished and absf(race.mouse_time-(race.settings.target_seconds+5.7))<0.03,"Stasis creates a real 5.7-second delay; no catch-up to configured finish")
 measurements.append({"case":"full_mouse_with_stasis","seconds":race.mouse_time})
 await place(Vector3(24,0,23.6))
 await press_e()
 check(not effect.active,"Mouse arrival prevents a new activation")
 # Early exit: first departure starts a single three-second deadline; reentry cannot renew it.
 await start_race()
 check(not race.sanctuary_used and effect.vision==null,"A new race resets entitlement and old vision resources")
 await activate_near_cube()
 await ticks(60)
 await place(Vector3(24,0,27.2))
 check(effect.exit_at>0.9 and effect.exit_at<1.2,"First real church exit is recorded")
 var first_exit: float=effect.exit_at
 var first_deadline: float=effect.deadline
 await place(Vector3(24,0,23.6))
 await press_e()
 await place(Vector3(24,0,27.2))
 await place(Vector3(24,0,23.6))
 check(effect.exit_at==first_exit and effect.deadline==first_deadline,"Reentering/exiting never refreshes the deadline")
 await wait_end()
 check(absf(effect.last_duration-first_exit-3.0)<0.035 and effect.last_duration<4.3,"Early exit ends after three seconds even after reentry")
 measurements.append({"case":"early_exit_reentry","seconds":effect.last_duration,"first_exit":first_exit})
 # Late exit: the six-second total wins over another three seconds.
 await start_race()
 await activate_near_cube()
 await ticks(300)
 await place(Vector3(24,0,27.2))
 await wait_end()
 check(absf(effect.last_duration-6.0)<0.02,"Late exit cannot extend past six seconds")
 measurements.append({"case":"late_exit","seconds":effect.last_duration})
 # Slowdown composes with any existing actor-specific rate and restores that rate.
 await start_race()
 race.set_mouse_speed_multiplier(0.8)
 await activate_near_cube()
 check(is_equal_approx(race.effective_mouse_speed_multiplier(),0.04),"Stasis composes with external mouse multiplier")
 await wait_end()
 check(is_equal_approx(race.effective_mouse_speed_multiplier(),0.8),"Prior multiplier preserved after stasis")
 # Active reset / mode switch must restore audio, overlay, speed and once flag correctly.
 await start_race()
 await activate_near_cube()
 race.request_mode("Explore")
 check(effect.active and race.current_mode=="Race","Pending mode selection alone cannot cancel or reset sanctuary")
 scene.reset_walk()
 await ticks(8)
 check(race.current_mode=="Explore" and not race.sanctuary_used and not race.sanctuary_active and effect.vision==null,"Restart into Explore clears active state")
 check(AudioServer.bus_count==initial_buses,"Reset releases original pill audio routing")
 check(not effect.prompt.visible and is_equal_approx(Engine.time_scale,1.0),"Explore has no leftover prompt or time changes")
 var file:=FileAccess.open(folder.path_join("measurements.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(measurements,"  "))
 file.close()
 print("SANCTUARY INTEGRATION ","PASS" if failures==0 else "FAIL"," failures=",failures," measurements=",JSON.stringify(measurements))
 scene.queue_free()
 await ticks(5)
 OS.delay_msec(180)
 check(AudioServer.bus_count==initial_buses,"Scene exit releases all focus buses")
 quit(failures)
