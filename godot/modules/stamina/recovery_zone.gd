extends Area3D
## Detection only. Capsule inflation is allowed for in the authored interior boundaries.
@export var zone_label: StringName = &"chapel"
var actor: CharacterBody3D
func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_entered)
	body_exited.connect(_left)
func _entered(body: Node3D) -> void:
	if body == actor:
		actor.stamina.enter_zone(get_instance_id(), zone_label)
func _left(body: Node3D) -> void:
	if body == actor:
		actor.stamina.leave_zone(get_instance_id())
func _exit_tree() -> void:
	if is_instance_valid(actor) and is_instance_valid(actor.stamina):
		actor.stamina.leave_zone(get_instance_id())
