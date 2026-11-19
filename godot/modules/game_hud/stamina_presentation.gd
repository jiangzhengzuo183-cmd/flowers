extends RefCounted
## Read-only view of existing sources. This does not own boost timers or stamina rules.
var _cake_previous := 0.0
var _barrier_previous := 0.0
var boost_serial := 0
func read(actor: CharacterBody3D, cake_effects: Node) -> Dictionary:
    var cake: float=maxf(0.0,float(cake_effects.get("boost_remaining"))) if is_instance_valid(cake_effects) else 0.0
    var value: Variant=actor.get("boost_remaining")
    var barrier: float=maxf(0.0,float(value)) if value!=null else 0.0
    if cake>_cake_previous+0.08 or barrier>_barrier_previous+0.08:boost_serial+=1
    _cake_previous=cake
    _barrier_previous=barrier
    var boosted: bool=cake>0.0 or barrier>0.0
    var moving_fast: bool=Vector2(actor.velocity.x,actor.velocity.z).length()>actor.WALK_SPEED+0.1
    return {"ratio":actor.stamina.percentage(),"running":actor.stamina.is_sprinting or (boosted and moving_fast),"boosted":cake>0.0 or barrier>0.0,"boost_serial":boost_serial}
func reset() -> void:
    _cake_previous=0.0
    _barrier_previous=0.0
    boost_serial=0
