extends "res://art/maze01/maze01_atmosphere.gd"
## Retain the finished cloud construction; all surrounding architecture is new.
func _ready() -> void:
	name="SilverBlueArchitecturalHorizon"
	_add_cloud(-19.0,0.037,Vector2(0.005,0.002),Color("b9cbdc"),0.48,Vector2(19,-7))
	_add_cloud(-9.5,0.053,Vector2(0.008,-0.003),Color("e0e9ed"),0.65,Vector2.ZERO)
	_add_exterior_clouds()
	var pale:=Geometry.material(Color("c9d3d7"))
	var far:=Geometry.material(Color("b5c9d7"))
	for spec: Array in [[Vector3(-43,24,-61),19.0,Vector3(74,16,-16)],[Vector3(125,37,-79),29.0,Vector3(80,-28,12)]]:
		var mesh:=MeshInstance3D.new();mesh.name="SuspendedMonumentalRing"
		var ring:=TorusMesh.new();ring.inner_radius=spec[1]-0.80;ring.outer_radius=spec[1]+0.80;ring.rings=128;ring.ring_segments=12
		mesh.mesh=ring;mesh.position=spec[0];mesh.rotation_degrees=spec[2];mesh.material_override=pale;add_child(mesh)
	for spec: Array in [[-62,-24,27,1.2],[-68,-29,17,0.9],[-81,-22,35,1.1],[105,-57,36,1.4],[113,-63,22,1.0],[-45,99,31,1.2],[115,95,21,1.0]]:
		Geometry.box(self,"DistantSlenderColumn",Vector3(spec[3],spec[2],spec[3]),Vector3(spec[0],spec[2]*0.5-5,spec[1]),far,false)
	Geometry.box(self,"SuspendedArchitecturalPlane",Vector3(23,0.55,3.4),Vector3(-48,12,-49),pale,false)
	Geometry.box(self,"RemoteHorizontalPlane",Vector3(19,0.45,2.6),Vector3(108,22,-64),far,false)
	_frame(Vector3(-74,-3,46),20,29,pale)
	_frame(Vector3(81,-4,110),15,23,far)
	for mesh: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func _frame(center: Vector3,width: float,height: float,material: Material) -> void:
	for side in [-1,1]:
		Geometry.box(self,"MonumentalFramePier",Vector3(0.75,height,0.9),center+Vector3(side*width*0.5,height*0.5,0),material,false)
	Geometry.box(self,"MonumentalFrameHeader",Vector3(width,0.75,0.9),center+Vector3.UP*height,material,false)
