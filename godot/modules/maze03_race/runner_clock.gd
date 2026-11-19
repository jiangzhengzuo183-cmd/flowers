extends RefCounted
## Shared deterministic integrator for calibration and live movement. Crossing events refresh, never stack.
const EPS := 0.00000001
var route: RefCounted
var settings: Resource
var rate := 1.0
var cost := 0.0
var seconds := 0.0
var boost_remaining := 0.0
var pause_remaining := 0.0
var hesitation_count := 0
var crossing_count := 0
var finished := false
var last_crossings: Array[int] = []
func configure(path: RefCounted, balance: Resource, speed: float) -> void:
 route=path
 settings=balance
 rate=speed
func opening_weight(at: float) -> float:
 return lerpf(settings.opening_multiplier,1.0,smoothstep(settings.opening_seconds,settings.opening_seconds+settings.opening_ease_seconds,at))
func advance(delta: float) -> float:
 var remaining := delta
 var consumed := 0.0
 last_crossings.clear()
 while remaining>EPS and not finished:
  if pause_remaining>EPS:
   var used := minf(remaining,pause_remaining)
   pause_remaining=maxf(0.0,pause_remaining-used)
   boost_remaining=maxf(0.0,boost_remaining-used)
   seconds+=used
   consumed+=used
   remaining-=used
   continue
  var pause_at: float = route.pauses[hesitation_count] if hesitation_count<route.pauses.size() else INF
  var boost_at: float = route.barrier_costs[crossing_count] if crossing_count<route.barrier_costs.size() else INF
  var target := minf(route.weighted_length,minf(pause_at,boost_at))
  var slice := remaining
  if boost_remaining>EPS:slice=minf(slice,boost_remaining)
  for boundary: float in [settings.opening_seconds,settings.opening_seconds+settings.opening_ease_seconds]:
   if seconds<boundary-EPS:slice=minf(slice,boundary-seconds)
  var speed = rate*opening_weight(seconds+slice*0.5)*(route.barrier_multiplier if boost_remaining>EPS else 1.0)
  var used := minf(slice,maxf(0.0,(target-cost)/speed))
  cost=minf(target,cost+used*speed)
  seconds+=used
  consumed+=used
  remaining-=used
  boost_remaining=maxf(0.0,boost_remaining-used)
  if cost>=target-EPS:
   if boost_at<=target+EPS:
    last_crossings.append(crossing_count)
    crossing_count+=1
    boost_remaining=route.barrier_seconds
   if pause_at<=target+EPS:
    hesitation_count+=1
    pause_remaining=settings.hesitation_seconds
   if cost>=route.weighted_length-EPS:finished=true
 return consumed

static func calibrate(path: RefCounted, balance: Resource) -> float:
 var lower: float = path.weighted_length/balance.target_seconds*0.2
 var upper: float = path.weighted_length/balance.target_seconds*2.0
 for iteration in 24:
  var middle := (lower+upper)*0.5
  var clock = load("res://modules/maze03_race/runner_clock.gd").new()
  clock.configure(path,balance,middle)
  for frame in 24000:
   clock.advance(1.0/60.0)
   if clock.finished:break
  if clock.seconds>balance.target_seconds:lower=middle
  else:upper=middle
 return (lower+upper)*0.5
