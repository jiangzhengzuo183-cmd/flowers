extends Node
## Scene-local coordinator. Explore creates neither an opponent nor a race readout.
signal race_started
signal mouse_arrived(seconds: float)
signal race_completed(result: Dictionary)
signal sanctuary_activated
signal sanctuary_ended
const Route := preload("res://modules/maze03_race/fixed_route.gd")
const Mouse := preload("res://modules/maze03_race/mouse.gd")
const Runner := preload("res://modules/maze03_race/runner_clock.gd")
const Presentation := preload("res://modules/maze03_race/opponent_visibility.gd")
const Hud := preload("res://modules/maze03_race/hud.gd")
@export var settings: Resource = preload("res://modules/maze03_race/default_settings.tres")
var scene: Node
var actor: CharacterBody3D
var recorder: Node
var mode_selector: OptionButton
var route := Route.new()
var route_ready := false
var runner: RefCounted
var presentation: RefCounted
var crossing_log: Array[Dictionary] = []
var sanctuary: Node
var sanctuary_used := false
var sanctuary_active := false
var mouse: Node3D
var hud: Control
var current_mode := "Explore"
var pending_mode := "Explore"
var state := "EXPLORE"
var elapsed := 0.0
var mouse_finished := false
var mouse_time := -1.0
var charlie_time := -1.0
var result: Dictionary = {}
var output_path := "user://race_tests/maze03.csv"
var mouse_speed_multiplier := 1.0
var mouse_paused := false
var mouse_cost := 0.0
var pause_remaining := 0.0
var hesitation_count := 0
var mouse_track_time := 0.0
var _phase_age := 0.0
var _go_age := 1.0
var _generation := 0
var entrance_active := false

func install(level: Node) -> void:
 name = "Maze03Race"
 scene = level
 actor = scene.get_node("%Player")
 recorder = scene.get_node("RouteTimingTest")
 process_physics_priority = 50
 mode_selector = OptionButton.new()
 mode_selector.name = "Maze03GameMode"
 mode_selector.add_item("探索模式",0)
 mode_selector.add_item("比赛模式",1)
 mode_selector.item_selected.connect(func(index: int):request_mode("Explore" if index==0 else "Race"))
 mode_selector.tooltip_text = "比赛进行中切换模式，将在点击回到入口后生效。"
 scene.get_node("Toolbar").add_child(mode_selector)
 scene.get_node("Toolbar").move_child(mode_selector,3)
 sanctuary=preload("res://modules/maze03_sanctuary/interaction.gd").new()
 add_child(sanctuary)
 sanctuary.install(self)

func request_mode(next: String) -> void:
 if next not in ["Explore","Race"]:return
 pending_mode = next
 mode_selector.select(0 if next=="Explore" else 1)
 if state in ["PREPARATION","COUNTDOWN","RACING"]:
  scene.get_node("%Status").text = "模式将在重开后切换。点击“回到入口”重新开始。"
  return
 scene.reset_walk()

func restart() -> void:
 sanctuary.reset()
 sanctuary_used=false
 sanctuary_active=false
 _generation += 1
 var token := _generation
 current_mode = pending_mode
 mode_selector.select(0 if current_mode=="Explore" else 1)
 elapsed = 0.0
 mouse_time = -1.0
 charlie_time = -1.0
 mouse_finished = false
 result.clear()
 mouse_cost = 0.0
 pause_remaining = 0.0
 hesitation_count = 0
 mouse_track_time = 0.0
 runner=null
 presentation=null
 crossing_log.clear()
 mouse_speed_multiplier = 1.0
 mouse_paused = false
 _phase_age = 0.0
 _go_age = 1.0
 if is_instance_valid(mouse):
  mouse.hide()
  mouse.queue_free()
  mouse = null
 if is_instance_valid(hud):
  hud.hide()
  hud.queue_free()
  hud = null
 var tools := scene.get_node("WalkControls/StaminaRouteTimingTools") as MenuButton
 tools.disabled = current_mode=="Race"
 if current_mode=="Explore":
  state = "EXPLORE"
  actor.controls_enabled = scene.walk_mode
  sync_controls()
  return
 state = "PREPARATION"
 actor.controls_enabled = false
 recorder.cancel()
 # Ensure collision bodies registered before querying the route for the first run.
 await get_tree().physics_frame
 await get_tree().physics_frame
 if token!=_generation:return
 route_ready = route.build(scene,settings)
 if not route_ready:
  state = "ERROR"
  scene.get_node("%Status").text = "竞速路线检查失败："+route.error
  push_error(route.error)
  actor.controls_enabled = scene.walk_mode
  return
 runner=Runner.new()
 runner.configure(route,settings,route.base_speed)
 presentation=Presentation.new()
 scene.set_walk_mode(true)
 actor.position.x = actor.spawn_point.x+0.35
 mouse = Mouse.new()
 mouse.name = "Algernon"
 actor.get_parent().add_child(mouse)
 mouse.setup(settings.mouse_height)
 mouse.position = route.points[0]
 mouse.face(route.points[1]-route.points[0],0.0,true)
 hud = Hud.new()
 scene.get_node("%ViewportContainer").add_child(hud)
 scene.get_node("%Status").text = "准备比赛：固定组合路线，阿尔吉侬目标 %.1f 秒。" % settings.target_seconds
 sync_controls()
 _update_hud()

func set_entrance_active(value: bool) -> void:
 entrance_active=value
 sync_controls()
 _update_hud()

func sync_controls() -> void:
 if entrance_active or (current_mode=="Race" and state in ["PREPARATION","COUNTDOWN"]):
  actor.controls_enabled = false
  actor.velocity.x = 0.0
  actor.velocity.z = 0.0

func _physics_process(delta: float) -> void:
 if entrance_active:
  sync_controls()
  _update_hud()
  return
 if current_mode!="Race" or not is_instance_valid(mouse):return
 sync_controls()
 if state=="PREPARATION":
  _phase_age += delta
  if _phase_age>=settings.preparation_seconds:
   _phase_age = 0.0
   state = "COUNTDOWN"
 elif state=="COUNTDOWN":
  _phase_age += delta
  if _phase_age>=3.0:
   elapsed = 0.0
   state = "RACING"
   actor.controls_enabled = scene.walk_mode
   mouse.run(route.base_speed*settings.fast_start*settings.opening_multiplier)
   _go_age = 0.0
   race_started.emit()
 elif state=="RACING":
  elapsed += delta
  _go_age += delta
  if not mouse_finished and not mouse_paused and mouse_speed_multiplier>0.0:
   _advance_mouse(delta)
  presentation.update(self,delta)
  # Shared existing physical exit volume, with a check after this tick's movement.
  if recorder.finish_trigger.overlaps_body(actor):
   _charlie_arrived()
 _update_hud()

func _advance_mouse(delta: float) -> void:
 var factor := effective_mouse_speed_multiplier()
 var consumed: float = runner.advance(delta*factor)
 mouse_cost=runner.cost
 pause_remaining=runner.pause_remaining
 hesitation_count=runner.hesitation_count
 mouse_track_time=runner.seconds
 var sample := route.sample(mouse_cost)
 var old := mouse.position
 mouse.position=sample.position
 mouse.face(sample.direction,delta*factor)
 var opening_boost: float = maxf(0.0,settings.opening_seconds+settings.opening_ease_seconds-runner.seconds)
 mouse.boost_remaining=maxf(runner.boost_remaining,opening_boost)
 if pause_remaining>0.000001:
  mouse.hesitate(settings.hesitation_seconds/maxf(0.001,factor))
 else:
  mouse.run(old.distance_to(mouse.position)/maxf(consumed,0.000001),factor)
 for index: int in runner.last_crossings:_cue_mouse_barrier(index)
 if runner.finished:_mouse_arrived(elapsed-delta+consumed/factor)

func _cue_mouse_barrier(index: int) -> void:
 var event: Dictionary = route.barrier_events[index]
 crossing_log.append({"id":event.id,"seconds":runner.seconds,"distance":event.distance})
 # Hidden movement grants the same actual speed, without revealing the route through remote flashes/sound.
 if not mouse.is_visible_in_tree() or mouse.opacity<0.9:return
 var barrier: Area3D = event.barrier
 var contact: Vector3 = barrier.to_local(event.point+Vector3.UP*0.32)
 barrier.pulse=1.0
 barrier.ripple_age=0.0
 barrier.finish.set_shader_parameter("contact_uv",Vector2(clampf(contact.x/1.97+0.5,0.05,0.95),clampf(contact.y/2.45,0.05,0.95)))
 barrier.burst.position=Vector3(contact.x,contact.y,0)
 barrier.burst.emission_box_extents=Vector3(0.16,0.25,0.025)
 barrier.burst.restart()
 barrier.burst.emitting=true
 if actor.position.distance_to(mouse.position)<9.0:barrier.crossed.emit()

func _mouse_arrived(at: float) -> void:
 if mouse_finished or state!="RACING":return
 mouse_finished = true
 sanctuary.finish("opponent_finished")
 mouse_time = at
 mouse.position = route.points[-1]
 mouse.face(route.points[-2]-route.points[-1],0.0,true)
 mouse.play(&"Dance")
 mouse.boost_remaining=0.0
 mouse_arrived.emit(mouse_time)
 print("MAZE03 MOUSE FINISH seconds=",snappedf(mouse_time,0.0001)," pauses=",hesitation_count," route_m=",route.length)
 # The clock and Charlie deliberately keep running.

func _charlie_arrived() -> void:
 if state!="RACING" or charlie_time>=0.0:return
 charlie_time = elapsed
 actor.velocity=Vector3.ZERO
 actor.visual.play_victory_dance()
 var outcome := "charlie"
 if mouse_finished:
  if absf(charlie_time-mouse_time)<=settings.tie_seconds:outcome="tie"
  elif mouse_time<charlie_time:outcome="mouse"
 state = "FINISHED"
 sanctuary.finish("player_finished")
 result = {"outcome":outcome,"title":{"charlie":"查理获胜","mouse":"阿尔吉侬获胜","tie":"平局"}[outcome],"charlie_time":charlie_time,"mouse_time":mouse_time,"route":"A-main+northern-branch","hesitations":hesitation_count}
 if not mouse_finished:
  mouse.play(&"Scratch")
  mouse.boost_remaining=0.0
  mouse.controls_enabled=false
  mouse.speed_ribbons.clear()
 _write_result()
 hud.show_result(result)
 race_completed.emit(result.duplicate())

func _update_hud() -> void:
 if not is_instance_valid(hud):return
 var count := ""
 if state=="PREPARATION":count="准备"
 elif state=="COUNTDOWN":count=str(maxi(1,3-floori(_phase_age)))
 elif state=="RACING" and _go_age<0.55:count="GO!"
 hud.update_race(state,elapsed,"" if entrance_active else count,mouse_finished)

func set_mouse_speed_multiplier(value: float) -> void:
 var previous := effective_mouse_speed_multiplier()
 mouse_speed_multiplier = clampf(value,0.0,3.0)
 if is_instance_valid(mouse):
  mouse.animation_player.speed_scale *= effective_mouse_speed_multiplier()/maxf(0.001,previous)

func pause_mouse() -> void:
 mouse_paused = true
 if is_instance_valid(mouse):mouse.suspend_animation(true)

func resume_mouse() -> void:
 mouse_paused = false
 if is_instance_valid(mouse):mouse.suspend_animation(false)

func effective_mouse_speed_multiplier() -> float:
 return mouse_speed_multiplier*(settings.sanctuary_mouse_speed if sanctuary_active else 1.0)

func can_use_sanctuary() -> bool:
 return current_mode=="Race" and state=="RACING" and not mouse_finished and not sanctuary_used

func claim_sanctuary() -> bool:
 if not can_use_sanctuary():return false
 var previous := effective_mouse_speed_multiplier()
 sanctuary_used=true
 sanctuary_active=true
 if is_instance_valid(mouse):mouse.animation_player.speed_scale *= effective_mouse_speed_multiplier()/maxf(0.001,previous)
 notify_sanctuary_activated()
 return true

func finish_sanctuary() -> void:
 if not sanctuary_active:return
 var previous := effective_mouse_speed_multiplier()
 sanctuary_active=false
 if is_instance_valid(mouse):mouse.animation_player.speed_scale *= effective_mouse_speed_multiplier()/maxf(0.001,previous)
 notify_sanctuary_ended()

# Shared race signals, now emitted by the single-use sanctuary state.
func notify_sanctuary_activated() -> void:
 sanctuary_activated.emit()
func notify_sanctuary_ended() -> void:
 sanctuary_ended.emit()

func _write_result() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
 var exists := FileAccess.file_exists(output_path)
 var file := FileAccess.open(output_path,FileAccess.READ_WRITE if exists else FileAccess.WRITE)
 if file==null:
  push_error("无法保存比赛测试记录："+output_path)
  return
 if exists:file.seek_end()
 else:file.store_csv_line(PackedStringArray(["utc","route","charlie_seconds","mouse_seconds","outcome","hesitations","stamina"]))
 file.store_csv_line(PackedStringArray([Time.get_datetime_string_from_system(true),result.route,str(snappedf(charlie_time,0.001)),str(snappedf(mouse_time,0.001)),result.outcome,str(hesitation_count),str(snappedf(actor.stamina.current,0.01))]))
 file.close()
 print("MAZE03 RACE RESULT ",JSON.stringify(result))
