extends RefCounted
## Hide only after the opening separation; presentation never changes route progress or timing.
var phase := "OPENING"
var opacity := 1.0
var hidden_time := -1.0
var revealed_time := -1.0
var hidden_gap := 0.0
var hidden_under_cover := false
var _reveal_wait := 0.0
func covered(race: Node) -> bool:
 var camera: Camera3D = race.scene.get_node("%FollowRig").camera
 var center: Vector3 = race.mouse.global_position+Vector3.UP*0.34
 if not camera.is_position_in_frustum(center):return true
 var space = race.actor.get_world_3d().direct_space_state
 for lift: float in [0.16,0.36,0.59]:
  var target: Vector3 = race.mouse.global_position+Vector3.UP*lift
  var query := PhysicsRayQueryParameters3D.create(camera.global_position,target,1)
  var hit = space.intersect_ray(query)
  if hit.is_empty() or hit.position.distance_to(target)<0.12:return false
  var occlusion: Node = race.scene.wall_occlusion
  var group: String = occlusion._collider_groups.get(hit.collider.get_instance_id(),"")
  if not group.is_empty() and occlusion.groups[group].opacity<0.85:return false
 return true
func update(race: Node, delta: float) -> void:
 var gap: float = race.mouse.global_position.distance_to(race.actor.global_position)
 var distance: float = race.route.sample(race.mouse_cost).distance
 var behind_cover := covered(race)
 if phase=="OPENING" and race.elapsed>=race.settings.hide_after_seconds and gap>=race.settings.hide_minimum_gap:
  if behind_cover or (race.elapsed>=10.0 and gap>=12.0):
   phase="HIDING"
   hidden_time=race.elapsed
   hidden_gap=gap
   hidden_under_cover=behind_cover
 elif phase=="HIDDEN" and race.route.length-distance<=race.settings.reveal_remaining_metres:
  _reveal_wait+=delta
  if behind_cover or _reveal_wait>=1.5 or race.mouse_finished:
   phase="REVEALING"
   revealed_time=race.elapsed
 if phase=="HIDING":
  opacity=move_toward(opacity,0.0,delta/race.settings.visibility_fade_seconds)
  if opacity<=0.0:phase="HIDDEN"
 elif phase=="REVEALING":
  opacity=move_toward(opacity,1.0,delta/race.settings.visibility_fade_seconds)
  if opacity>=1.0:phase="FINISH"
 if race.mouse_finished and phase in ["OPENING","HIDDEN","HIDING"]:
  phase="REVEALING"
  revealed_time=race.elapsed
 race.mouse.set_opacity(opacity)
 race.mouse.controls_enabled=phase in ["OPENING","FINISH"] and not race.mouse_paused and not race.mouse_finished
