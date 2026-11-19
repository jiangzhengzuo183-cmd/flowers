extends RefCounted
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const Zone := preload("res://modules/stamina/recovery_zone.gd")
const Debug := preload("res://modules/stamina/debug_readout.gd")
static func install(scene: Node, recovery_zones: bool, timing: bool = false) -> void:
	var actor: CharacterBody3D = scene.get_node("%Player")
	var readout := Debug.new()
	readout.actor = actor
	scene.get_node("%ViewportContainer").add_child(readout)
	if recovery_zones:
		var world := actor.get_parent()
		var spec: Dictionary = Layout.config().building.circle
		var chapel := Zone.new()
		chapel.name = "ChapelStaminaRecovery"
		chapel.zone_label = &"chapel"
		chapel.actor = actor
		chapel.position = Vector3(spec.center[0], 1.0, spec.center[1])
		var cylinder := CylinderShape3D.new()
		cylinder.radius = float(spec.usableRadius) - 0.30
		cylinder.height = 2.6
		var shape := CollisionShape3D.new()
		shape.shape = cylinder
		chapel.add_child(shape)
		world.add_child(chapel)
		var plaza := Zone.new()
		plaza.name = "StatueCourtStaminaRecovery"
		plaza.zone_label = &"statue_court"
		plaza.actor = actor
		plaza.position = Layout.cell_point(Layout.config().statue_plaza_cell) + Vector3.UP
		var box := BoxShape3D.new()
		box.size = Vector3(6.0, 2.6, 6.0)
		shape = CollisionShape3D.new()
		shape.shape = box
		plaza.add_child(shape)
		world.add_child(plaza)
	if timing:
		var recorder := preload("res://modules/stamina/route_timing.gd").new()
		recorder.name = "RouteTimingTest"
		scene.add_child(recorder)
		recorder.install(scene)
