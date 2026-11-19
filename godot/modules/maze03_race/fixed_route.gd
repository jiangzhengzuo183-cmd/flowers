extends RefCounted
## A's southern/eastern main route + the northern B branch. Physics-checked once per race scene.
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const SAMPLE := 0.12
var points := PackedVector3Array()
var distances := PackedFloat64Array()
var costs := PackedFloat64Array()
var cells: Array = []
var pauses := PackedFloat64Array()
var pause_distances := PackedFloat64Array()
var length := 0.0
var weighted_length := 0.0
var base_speed := 0.0
var clearance_checks := 0
var error := ""
var barrier_events: Array[Dictionary] = []
var barrier_costs := PackedFloat64Array()
var barrier_multiplier := 1.35
var barrier_seconds := 3.0

func build(level: Node, settings: Resource) -> bool:
 points.clear()
 distances.clear()
 costs.clear()
 cells.clear()
 pauses.clear()
 pause_distances.clear()
 barrier_events.clear()
 barrier_costs.clear()
 barrier_multiplier=level.barrier_speed_multiplier
 barrier_seconds=level.barrier_duration_seconds
 length = 0.0
 weighted_length = 0.0
 clearance_checks = 0
 error = ""
 var main: Array = level.maze_data.routes.A.cellPath
 var branch: Array = level.maze_data.routes.B.cellPath
 var junction := [3,16]
 var a_index := _cell_index(main,junction)
 var b_index := _cell_index(branch,junction)
 if a_index < 0 or b_index < 0:
  error = "未找到固定支路连接点"
  return false
 cells = main.slice(0,a_index+1) + branch.slice(b_index+1)
 var world: World3D = level.get_node("%Player").get_world_3d()
 var previous_y := 0.0
 for i in cells.size()-1:
  var a := Layout.cell_point(cells[i])
  var b := Layout.cell_point(cells[i+1])
  var steps := ceili(a.distance_to(b)/SAMPLE)
  for step in steps:
   var flat := a.lerp(b,float(step)/steps)
   # Left starting lane merges into the corridor centre over the first 1.2m.
   if i==0:flat.x -= 0.4*(1.0-smoothstep(0.0,1.2,float(step)/steps*a.distance_to(b)))
   var query := PhysicsRayQueryParameters3D.create(flat+Vector3.UP*(previous_y+0.44),flat+Vector3.UP*(previous_y-0.75),1)
   var hit := world.direct_space_state.intersect_ray(query)
   if hit.is_empty() or hit.normal.y < 0.60:
    error = "固定路线缺少可行走地面："+str(flat)
    return false
   var point: Vector3 = hit.position
   previous_y = point.y
   _append(point)
 var finish := Layout.cell_point(cells[-1])
 var hit := world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(finish+Vector3.UP*(previous_y+0.44),finish+Vector3.UP*(previous_y-0.75),1))
 if hit.is_empty():
  error = "终点地面缺失"
  return false
 _append(hit.position)
 var shape := CapsuleShape3D.new()
 shape.radius = 0.22
 shape.height = 0.60
 var sweep := PhysicsShapeQueryParameters3D.new()
 sweep.shape = shape
 sweep.collision_mask = 1
 sweep.margin = 0.002
 for i in range(1,points.size()):
  sweep.transform = Transform3D(Basis.IDENTITY,points[i-1]+Vector3.UP*0.43)
  sweep.motion = points[i]-points[i-1]
  var result := world.direct_space_state.cast_motion(sweep)
  clearance_checks += 1
  if result.size()!=2 or result[0]<0.999:
   error = "固定路线碰撞未通过："+str(points[i-1])+" → "+str(points[i])
   return false
 costs.append(0.0)
 for i in range(1,points.size()):
  var fraction := (distances[i-1]+distances[i])*0.5/length
  var weight := speed_weight(fraction,settings)
  weighted_length += (distances[i]-distances[i-1])/weight
  costs.append(weighted_length)
 base_speed = weighted_length/(settings.target_seconds-2.0*settings.hesitation_seconds)
 for cell: Array in [[14,10],[3,16]]:
  var nearest := 0
  var aim := Layout.cell_point(cell)
  for i in points.size():
   if Vector2(points[i].x-aim.x,points[i].z-aim.z).length_squared() < Vector2(points[nearest].x-aim.x,points[nearest].z-aim.z).length_squared():
    nearest = i
  pauses.append(costs[nearest])
  pause_distances.append(distances[nearest])
 _find_barriers(level.get_node("%GeneratedMaze").barriers)
 base_speed=preload("res://modules/maze03_race/runner_clock.gd").calibrate(self,settings)
 return true

func _find_barriers(barriers: Array) -> void:
 for barrier: Node3D in barriers:
  var last_distance := -100.0
  for i in range(1,points.size()):
   var a := barrier.to_local(points[i-1])
   var b := barrier.to_local(points[i])
   if not ((a.z>0.000001 and b.z<=0.000001) or (a.z< -0.000001 and b.z>= -0.000001)):continue
   var blend := clampf(-a.z/(b.z-a.z),0.0,1.0)
   var crossing := a.lerp(b,blend)
   if absf(crossing.x)>0.96 or crossing.y< -0.12 or crossing.y>1.9:continue
   var distance := lerpf(distances[i-1],distances[i],blend)
   if distance-last_distance<0.15:continue
   last_distance=distance
   barrier_events.append({"distance":distance,"barrier":barrier,"id":str(barrier.name),"point":points[i-1].lerp(points[i],blend)})
 barrier_events.sort_custom(func(a: Dictionary,b: Dictionary):return a.distance<b.distance)
 for event in barrier_events:barrier_costs.append(cost_at_distance(event.distance))

func cost_at_distance(distance: float) -> float:
 var index := _index(distances,clampf(distance,0.0,length))
 var blend := clampf((distance-distances[index])/maxf(0.00001,distances[index+1]-distances[index]),0.0,1.0)
 return lerpf(costs[index],costs[index+1],blend)

func _append(point: Vector3) -> void:
 if not points.is_empty():
  length += points[-1].distance_to(point)
 points.append(point)
 distances.append(length)

func _cell_index(path: Array, cell: Array) -> int:
 for i in path.size():
  if Layout.cell_key(path[i])==Layout.cell_key(cell):return i
 return -1

func speed_weight(fraction: float, settings: Resource) -> float:
 if fraction<0.16:return settings.fast_start
 if fraction<0.27:return lerpf(settings.fast_start,settings.relaxed_middle,smoothstep(0.16,0.27,fraction))
 if fraction<0.65:return settings.relaxed_middle
 if fraction<0.80:return lerpf(settings.relaxed_middle,settings.fast_finish,smoothstep(0.65,0.80,fraction))
 return settings.fast_finish

func sample(cost: float) -> Dictionary:
 var index := _index(costs,clampf(cost,0.0,weighted_length))
 var blend := clampf((cost-costs[index])/maxf(0.00001,costs[index+1]-costs[index]),0.0,1.0)
 return {"position":points[index].lerp(points[index+1],blend),"direction":(points[index+1]-points[index]).normalized(),"distance":lerpf(distances[index],distances[index+1],blend)}

func _index(values: PackedFloat64Array, value: float) -> int:
 var low := 0
 var high := values.size()-1
 while low+1<high:
  var middle := (low+high)/2
  if values[middle]<=value:low=middle
  else:high=middle
 return mini(low,values.size()-2)
