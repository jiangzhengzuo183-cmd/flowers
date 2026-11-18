extends RefCounted
## Existing districts compose six transition zones, leaving the primary silhouettes breathing room.
## bearing, radius, height offset, width scale, height scale, depth scale, yaw offset.
const MIDDLE := {
	"WestBelfries":[213.0,246.0,0.0,0.96,1.10,1.10,-4.0],
	"SouthArcade":[94.0,226.0,1.8,1.20,1.08,1.14,3.0],
	"EastSpire":[32.0,238.0,-0.6,0.94,1.20,1.10,-5.0],
	"NorthTerraces":[279.0,240.0,2.2,1.08,1.25,1.18,4.0],
	"WestWatergate":[153.0,230.0,-1.2,1.20,1.12,1.16,-3.0],
	"NorthwestLibrary":[259.0,250.0,0.8,1.08,1.12,1.15,5.0],
	"NortheastHalls":[347.0,236.0,1.1,1.12,1.18,1.15,-4.0],
	"SoutheastCourt":[111.0,258.0,-2.0,0.82,0.94,1.10,3.0],
}
const FAR := {
	"WestHangingTowers":[204.0,310.0,-3.0,0.90,1.35,1.15,3.0],
	"SouthWestStair":[137.0,302.0,-1.0,1.02,1.40,1.20,-4.0],
	"SouthEastCloister":[82.0,300.0,-4.0,0.95,1.15,1.14,4.0],
	"NorthEastSteeples":[331.0,315.0,-0.8,0.93,1.40,1.20,-3.0],
	"NorthWestArcade":[270.0,322.0,-2.0,1.35,1.30,1.20,2.0],
	"WestLowerCity":[22.0,324.0,-2.8,0.82,1.05,1.16,-4.0],
	"NorthBelltowers":[286.0,335.0,-4.5,0.78,1.08,1.15,4.0],
	"EastOldMarket":[163.0,319.0,-2.3,0.94,1.35,1.18,-2.0],
	"SouthLongCloister":[105.0,326.0,-4.0,1.00,1.15,1.15,3.0],
}
static func place(anchor: Node3D,far: bool) -> void:
	var table := FAR if far else MIDDLE
	if not table.has(str(anchor.name)):
		push_error("Missing Maze03 horizon placement: "+str(anchor.name))
		return
	var spec: Array = table[str(anchor.name)]
	var angle := deg_to_rad(float(spec[0]))
	var radial := Vector3(cos(angle),0,sin(angle))
	anchor.position = radial*float(spec[1])+Vector3.UP*float(spec[2])
	anchor.rotation.y = atan2(-radial.x,-radial.z)+deg_to_rad(float(spec[6]))
	anchor.scale = Vector3(spec[3],spec[4],spec[5])
	# Align the visible district centre, rather than its off-centre authoring origin.
	var mesh := anchor.get_node("Architecture") as MeshInstance3D
	var center := mesh.get_aabb().get_center()
	var offset := anchor.basis*Vector3(center.x,0,center.z)
	anchor.position.x -= offset.x
	anchor.position.z -= offset.z
	anchor.set_meta("skyline_bearing",spec[0])
	anchor.set_meta("skyline_radius",spec[1])
