extends Node
## Only two selected primary silhouettes move; all distances and colliders stay unchanged.
@export_range(0.1,3.0,0.1) var rotation_degrees_per_second := 1.1
@export_range(0.2,3.0,0.1) var float_amplitude := 1.4
var pieces: Array[Dictionary] = []
var elapsed := 0.0
var resonance := 0.0
var shock := 0.0
func install(enclosure: Node3D) -> void:
	name = "SlowMegastructureMotion"
	for id in ["NortheastCurvedMonolith","NorthwestRaisedDisc"]:
		var node := enclosure.middle.get_node(id) as Node3D
		pieces.append({"node":node,"origin":node.position,"yaw":node.rotation.y,"disc":id=="NorthwestRaisedDisc"})
	enclosure.add_child(self)
func _process(delta: float) -> void:
	elapsed += delta
	for piece in pieces:
		var node: Node3D = piece.node
		var disc: bool = piece.disc
		node.position = piece.origin
		node.position.y += sin(elapsed*(TAU/13.0 if disc else TAU/25.0))*(float_amplitude if disc else 0.18)
		node.position.y += sin(elapsed*21.0)*resonance*0.16-absf(shock)*0.30
		node.rotation.y = piece.yaw+(0.0 if disc else elapsed*deg_to_rad(rotation_degrees_per_second))
		node.rotation.x = sin(elapsed*TAU/18.0)*deg_to_rad(0.55) if disc else 0.0
		node.rotation.z = sin(elapsed*17.0)*resonance*0.0008+shock*0.006


