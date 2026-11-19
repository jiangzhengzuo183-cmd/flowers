extends Node
## Only the previously untimed exploration sessions use this clock. Race owns its own clock.
var scene: Node
var actor: CharacterBody3D
var elapsed := 0.0
var finished := false
var ready_to_play := true
var _settle_frames := 0
func install(level: Node) -> void:
    scene = level
    actor = scene.get_node("%Player")
    actor.stamina.session_reset.connect(reset)
func reset() -> void:
    _settle_frames=2
    elapsed = 0.0
    finished = false
func _physics_process(delta: float) -> void:
    if _settle_frames>0:
        _settle_frames-=1
        return
    var race = scene.get("race")
    if is_instance_valid(race) and race.current_mode == "Race": return
    if finished or not ready_to_play: return
    if scene.get("completed") == true:
        finished = true
        return
    if is_instance_valid(race) and race.recorder.finish_trigger.overlaps_body(actor):
        finished = true
        return
    if scene.walk_mode and actor.controls_enabled: elapsed += delta
