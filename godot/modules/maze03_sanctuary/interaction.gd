extends Node
## One scene-local E interaction. The race manager owns the once-per-challenge entitlement.
const Vision := preload("res://modules/maze03_sanctuary/vision_adapter.gd")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
class GateMark extends Node3D:
 var is_open := false
var race: Node
var scene: Node
var actor: CharacterBody3D
var temple: Node3D
var cube: Node3D
var sensor: Area3D
var prompt: Label
var vision: Node3D
var active := false
var age := 0.0
var deadline := 6.0
var exit_at := -1.0
var last_duration := 0.0
var end_reason := ""
var global_route := PackedVector3Array()
var route_support_missing := 0
var gate_marks: Array[Node3D] = []
func install(manager: Node) -> void:
 name="CentralSanctuaryInteraction"
 race=manager
 scene=race.scene
 actor=race.actor
 temple=scene.get_node("%GeneratedMaze").sanctuary
 cube=temple.get_node("HoveringBlueCube")
 process_physics_priority=40
 process_priority=110
 sensor=Area3D.new()
 sensor.name="CubeInteractionRange"
 sensor.collision_layer=0
 sensor.collision_mask=2
 sensor.position=Vector3(cube.global_position.x,1.0,cube.global_position.z)
 var shape := CollisionShape3D.new()
 var cylinder := CylinderShape3D.new()
 cylinder.radius=race.settings.sanctuary_interaction_radius
 cylinder.height=2.4
 shape.shape=cylinder
 sensor.add_child(shape)
 actor.get_parent().add_child(sensor)
 prompt=Label.new()
 prompt.name="SanctuaryInteractionPrompt"
 prompt.text="E  激活圣堂"
 prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE
 prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 prompt.add_theme_font_size_override("font_size",18)
 prompt.add_theme_color_override("font_color",Color("f6fcff"))
 prompt.add_theme_color_override("font_shadow_color",Color(0.14,0.22,0.27,0.8))
 prompt.add_theme_constant_override("shadow_offset_x",1)
 prompt.add_theme_constant_override("shadow_offset_y",2)
 scene.get_node("%ViewportContainer").add_child(prompt)
 prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 prompt.offset_left=-150
 prompt.offset_right=150
 prompt.offset_top=-54
 prompt.offset_bottom=-20
 prompt.hide()
 for barrier: Area3D in scene.get_node("%GeneratedMaze").barriers:
  var marker := GateMark.new()
  add_child(marker)
  marker.global_transform=barrier.global_transform
  gate_marks.append(marker)
func inside_building() -> bool:
 var p: Vector3 = temple.get_node("FinSanctuary").to_local(actor.global_position)
 return absf(p.x)<3.5 and absf(p.z)<3.5 and p.y> -0.15 and p.y<2.5
func can_interact() -> bool:
 if not race.can_use_sanctuary() or not actor.controls_enabled or not scene.walk_mode:return false
 if actor.visual.celebrating or actor.visual._jumping or not actor.is_on_floor():return false
 if not inside_building() or not sensor.overlaps_body(actor):return false
 return Vector2(actor.global_position.x-cube.global_position.x,actor.global_position.z-cube.global_position.z).length()<=race.settings.sanctuary_interaction_radius
func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed(&"interact"):
  if try_activate():get_viewport().set_input_as_handled()
func try_activate() -> bool:
 if not can_interact() or not race.claim_sanctuary():return false
 active=true
 age=0.0
 deadline=clampf(race.settings.sanctuary_max_seconds,0.1,6.0)
 exit_at= -1.0
 last_duration=0.0
 end_reason=""
 prompt.hide()
 _ensure_vision()
 actor.stamina.restore(actor.stamina.settings.maximum,&"sanctuary")
 vision.activate_for(deadline)
 return true
func _ensure_vision() -> void:
 if is_instance_valid(vision):return
 _build_global_route()
 vision=Vision.new()
 vision.name="SanctuaryCapsuleVision"
 actor.get_parent().add_child(vision)
 var viewport: Control = scene.get_node("%ViewportContainer")
 vision.install(viewport,scene.wall_occlusion,_mark_targets,_vision_route,scene,func():return not scene.sound._muted)
 # The existing compositor grades the 3D game; stamina, race clock and other HUD stay above it.
 viewport.move_child(vision._screen,1)
 vision.add_character(actor)
 vision.add_opponent(race.mouse)
func _mark_targets() -> Dictionary:
 return {"gates":gate_marks,"pickups":[],"exits":[race.recorder.finish_trigger]}
func _vision_route() -> PackedVector3Array:
 return global_route
func _build_global_route() -> void:
 global_route=race.route.points.duplicate()
 var secondary := PackedVector3Array()
 var cells: Array = scene.maze_data.routes.B.cellPath
 var previous_y := 0.0
 route_support_missing=0
 var space := actor.get_world_3d().direct_space_state
 for i in cells.size()-1:
  var a := Layout.cell_point(cells[i])
  var b := Layout.cell_point(cells[i+1])
  var count := maxi(1,ceili(a.distance_to(b)/0.24))
  for j in count:
   var p := a.lerp(b,float(j)/count)
   var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*(previous_y+0.44),p+Vector3.UP*(previous_y-0.75),1))
   if hit.is_empty() or hit.normal.y<0.6:
    route_support_missing+=1
    continue
   previous_y=hit.position.y
   secondary.append(hit.position)
 secondary.append(race.route.points[-1])
 if route_support_missing==0:
  # B runs back from the common exit, so there is no fictitious diagonal link across the maze.
  secondary.reverse()
  global_route.append_array(secondary)
func _physics_process(delta: float) -> void:
 if not is_instance_valid(actor):return
 prompt.visible=can_interact()
 if not active:return
 if race.current_mode!="Race" or race.state!="RACING" or race.mouse_finished:
  finish("race_ended")
  return
 age=minf(deadline,age+delta)
 if exit_at<0.0 and not inside_building():
  exit_at=age
  deadline=minf(deadline,exit_at+clampf(race.settings.sanctuary_exit_seconds,0.0,3.0))
 var left := maxf(0.0,deadline-age)
 vision.advance(delta,left)
 if left<=0.000001:finish("exit" if exit_at>=0.0 and deadline<race.settings.sanctuary_max_seconds else "maximum")
func finish(reason: String) -> void:
 if not active:return
 active=false
 last_duration=age
 end_reason=reason
 if is_instance_valid(vision):vision.clear()
 race.finish_sanctuary()
func reset() -> void:
 finish("restart")
 age=0.0
 exit_at= -1.0
 last_duration=0.0
 if is_instance_valid(vision):
  vision.dispose()
  vision=null
 prompt.hide()
func _exit_tree() -> void:
 if is_instance_valid(vision):vision.dispose()
 if is_instance_valid(prompt):prompt.queue_free()
 if is_instance_valid(sensor):sensor.queue_free()
