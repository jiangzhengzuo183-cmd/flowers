extends Node3D
## Six clean silhouettes, staggered in depth; limited glazing follows their prototypes.
const F := preload("res://modules/maze03_final/architecture_forms.gd")
const G := preload("res://modules/maze03_final/geometric_masses.gd")
const MIDDLE_LAYER := 8
const DISTANT_LAYER := 16
const SCENERY_MASK := MIDDLE_LAYER | DISTANT_LAYER
const CENTRE := Vector3(24,0,22.8)
var focal_count := 0
var secondary_count := 0
var connector_count := 0
var near_count := 0
var solid_mesh_count := 0
var glazing_count := 0
var closest_extent := INF
var middle: Node3D
var distant: Node3D

func _ready() -> void:
	name = "WhiteMegastructureEnclosure"
	middle = Node3D.new()
	middle.name = "PrimaryGeometricMasses"
	add_child(middle)
	distant = Node3D.new()
	distant.name = "QuietIntermediateMasses"
	add_child(distant)
	_primary_masses()
	var ring_axis := preload("res://modules/maze03_final/ring_axis.gd").new()
	ring_axis.position = middle.get_node("NortheastCurvedMonolith").position
	add_child(ring_axis)
	_lower_cloud_banks()
	_lighting()
	_include_in_mirror()
	var motion := preload("res://modules/maze03_final/megastructure_motion.gd").new()
	motion.install(self)

func _mass(parent: Node3D, id: String, at: Vector3, geometry: SurfaceTool, primary: bool, yaw_offset: float = 0.0) -> Node3D:
	var group := Node3D.new()
	group.name = id
	group.position = at
	group.rotation.y = atan2(CENTRE.x-at.x,CENTRE.z-at.z)+yaw_offset
	parent.add_child(group)
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://modules/maze03_final/geometric_stone.gdshader")
	var distance := Vector2(at.x-CENTRE.x,at.z-CENTRE.z).length()
	paint.set_shader_parameter("air_perspective",clampf((distance-120.0)/1400.0+0.02,0.025,0.075) if primary else 0.13)
	var visual := F.finish(group,"ContinuousWhiteVolume",geometry,paint,false)
	visual.layers = MIDDLE_LAYER if primary else DISTANT_LAYER
	solid_mesh_count += 1
	var bounds := visual.get_aabb()
	paint.set_shader_parameter("foundation_base",bounds.position.y)
	paint.set_shader_parameter("foundation_height",clampf(bounds.size.y*0.30,8.0,28.0))
	var radius := Vector2(maxf(absf(bounds.position.x),absf(bounds.end.x)),maxf(absf(bounds.position.z),absf(bounds.end.z))).length()
	closest_extent = minf(closest_extent,distance-radius)
	group.set_meta("centre_distance",distance)
	group.set_meta("top_altitude",at.y+bounds.end.y)
	if primary:
		focal_count += 1
	else:
		secondary_count += 1
	return group

func _primary_masses() -> void:
	# Existing forms are a little closer, with irregular radii and distinct upper levels.
	_mass(middle,"NortheastCurvedMonolith",Vector3(128,-18,-109),G.curved_mass(50,33,100,250),true,-0.25)
	_mass(middle,"WesternSingleCutVolume",Vector3(-137,-17,8),G.pierced_mass(Vector3(104,84,34),Vector2(-9,42),Vector2(25,23)),true,0.12)
	_mass(middle,"SoutheastQuietDome",Vector3(112,-11,181),G.dome(Vector2(65,50),55),true)
	# Museum of Memory: one tall, thick plane with a narrow recessed window.
	var blade := _mass(middle,"EasternHighBlade",Vector3(157,-20,48),G.pierced_mass(Vector3(43,140,24),Vector2(5,79),Vector2(5.4,38)),true,-0.18)
	_glazing(blade,G.oval_glazing(Vector2(5,79),Vector2(5.4,38),7.5))
	# Brasilia Congress reference: two long plates and one connecting bridge.
	var twins := F.surface()
	for x: float in [-15,15]:
		F.solid(twins,Vector3(x,66,0),Vector3(10,132,18),0.35)
	F.solid(twins,Vector3(0,80,0),Vector3(20,6,16),0.25)
	_mass(middle,"SouthwestConnectedTwins",Vector3(-82,-20,171),twins,true,-0.12)
	# Niteroi: a continuous flared body and its original horizontal glazing band.
	var disc_profile := PackedVector2Array([Vector2(0,0),Vector2(7,0),Vector2(7.5,7),Vector2(17,10),Vector2(39,18),Vector2(43,21),Vector2(43,25),Vector2(39,27),Vector2(0,28)])
	var disc := _mass(middle,"NorthwestRaisedDisc",Vector3(-78,-13,-141),G.lathe(disc_profile,5),true)
	_glazing(disc,G.lathe(PackedVector2Array([Vector2(43,21),Vector2(43,25)])))

func _glazing(group: Node3D, geometry: SurfaceTool) -> void:
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://modules/maze03_final/distant_glazing.gdshader")
	paint.set_shader_parameter("air_perspective",0.08)
	var mesh := F.finish(group,"RecessedGlazing",geometry,paint,false)
	mesh.layers = MIDDLE_LAYER
	glazing_count += 1

func _lighting() -> void:
	var sun := get_parent().get_parent().get_node("Sun") as DirectionalLight3D
	for visual: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		if visual.material_override is ShaderMaterial and visual.name in [&"ContinuousWhiteVolume",&"MiddleWhiteMass",&"RecessedGlazing"]:
			visual.material_override.set_shader_parameter("sun_direction",sun.global_basis.z)

func _include_in_mirror() -> void:
	var sanctuary := get_parent().get_parent().get_node_or_null("GeneratedMaze/LevelArchitecture/FinalSanctuary")
	if sanctuary!=null:
		var mirror := sanctuary.get("reflection_camera") as Camera3D
		if mirror!=null:
			mirror.cull_mask = mirror.cull_mask | SCENERY_MASK

func _lower_cloud_banks() -> void:
	for layer: Node3D in [middle,distant]:
		for group: Node3D in layer.get_children():
			var bank := MeshInstance3D.new()
			bank.name = "LowFoundationCloud"
			var quad := QuadMesh.new()
			quad.size = Vector2(186,46) if group.name==&"SoutheastQuietDome" else Vector2(152,38)
			bank.mesh = quad
			bank.position = Vector3(0,-2.0 if group.name==&"NorthwestRaisedDisc" else 6.0,68)
			var paint := ShaderMaterial.new()
			paint.shader = preload("res://modules/maze03_final/clouds.gdshader")
			paint.set_shader_parameter("vertical_bank",true)
			paint.set_shader_parameter("outside_only",false)
			paint.set_shader_parameter("phase",float(group.get_index())*2.1)
			paint.set_shader_parameter("tint",Color("e5eff7"))
			paint.set_shader_parameter("opacity",0.16 if layer==middle else 0.24)
			bank.material_override = paint
			bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bank.layers = 4
			group.add_child(bank)





