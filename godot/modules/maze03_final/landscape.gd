extends Node3D
## A connected distant architectural world, with three focal districts and a quiet perimeter.
const F := preload("res://modules/maze03_final/architecture_forms.gd")
const Enclosure := preload("res://modules/maze03_final/enclosure.gd")
const OuterSilhouettes := preload("res://modules/maze03_final/outer_silhouettes.gd")
const Atmosphere := preload("res://modules/maze03_final/atmosphere.gd")
const SceneryLayout := preload("res://modules/maze03_final/scenery_layout.gd")
var group_count := 0
var depth_counts := [0,0,0]
var silhouette_count := 0
var inlay_count := 0
var roofs_simplified := 0

func _ready() -> void:
	name = "FinalTrialHorizon"
	_reference_city_layers()
	add_child(Enclosure.new())
	add_child(Atmosphere.new())

func _material(_tint: String, _pattern: bool = false, _center_x: float = 0.0, _front: float = 5.0, _center_y: float = 36.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://modules/maze03_final/horizon_haze.gdshader")
	mat.set_shader_parameter("mist",Color("f1f3f2"))
	mat.set_shader_parameter("shade",Color("c2ced7"))
	mat.set_shader_parameter("clarity",0.30)
	mat.set_shader_parameter("sun_direction",get_parent().get_node("Sun").global_basis.z)
	return mat

func _reference_city_layers() -> void:
	# Reuse the successful authored Near/Far district composition from Maze01/02.
	# All overrides are on newly constructed instance materials, never source files.
	var city := preload("res://art/environments/sky_memories/distant_city.tscn").instantiate() as Node3D
	city.name = "LayeredWhiteCity"
	city.position = Vector3(24,0,22.8)
	add_child(city)
	for layer: Node3D in city.get_children():
		var far := layer.name==&"FarDistricts"
		var masonry := _city_finish(far,false)
		var glazing := _city_finish(far,true)
		for anchor: Marker3D in layer.get_children():
			var index := anchor.get_index()
			SceneryLayout.place(anchor,far)
			var district_paint := masonry.duplicate() as ShaderMaterial
			var strength := 0.85+0.24*(0.5+0.5*cos(index*1.77))
			district_paint.set_shader_parameter("clarity",minf(0.95,(0.72 if far else 0.84)*strength))
			for mesh: MeshInstance3D in anchor.get_children():
				mesh.material_override = glazing if mesh.name==&"WarmWindows" else district_paint
				if mesh.name==&"WarmWindows":
					mesh.hide()
				elif mesh.name==&"Architecture":
					mesh.mesh = OuterSilhouettes.simplify(mesh.mesh,anchor.get_index())
					roofs_simplified += 1
			silhouette_count += 1
		depth_counts[2 if far else 0] = layer.get_child_count()

func _city_finish(far: bool, windows: bool) -> ShaderMaterial:
	var mat := _material("")
	mat.set_shader_parameter("clarity",0.42 if far else 0.63)
	mat.set_shader_parameter("mist",Color("f4f8fc"))
	mat.set_shader_parameter("shade",Color("a5cbe7"))
	mat.set_shader_parameter("windows",windows)
	return mat
func _group(id: String, center: Vector3, depth: int) -> Node3D:
	var group := Node3D.new()
	group.name = id
	group.position = center
	group.rotation.y = atan2(24-center.x,22.8-center.z)
	add_child(group)
	group_count += 1
	depth_counts[depth] += 1
	return group

func _primary_gate() -> void:
	var group := _group("PrimaryVaultDistrict",Vector3(128,-26,-152),1)
	group.scale = Vector3.ONE*1.55
	var main := F.surface()
	F.arch(main,Vector3(0,9,0),Vector2(40,29),30,5.0,10.0)
	for side: float in [-1,1]:
		F.solid(main,Vector3(side*28.5,36,0),Vector3(9,72,14),0.7,0.93)
		F.solid(main,Vector3(side*28.5,72.7,0),Vector3(10,1.4,15),0.4)
	F.finish(group,"VaultAndAbutments",main,_material("becdd2"))
	var terraces := F.surface()
	F.solid(terraces,Vector3(0,8,-3),Vector3(82,4,39),0.8)
	F.solid(terraces,Vector3(-41,15,-19),Vector3(28,8,32),0.6)
	F.solid(terraces,Vector3(36,17,-25),Vector3(22,14,25),0.55)
	F.solid(terraces,Vector3(-44,28,-27),Vector3(11,18,17),0.55)
	F.arch(terraces,Vector3(37,24,-25),Vector2(14,14),12,2.4,6)
	F.finish(group,"AttachedTerracesAndGalleries",terraces,_material("adbfc9"))
	var recess := F.surface()
	F.solid(recess,Vector3(0,5.6,3),Vector3(73,0.65,30),0.1)
	F.solid(recess,Vector3(-41,11.1,-17),Vector3(26,0.7,30),0.1)
	F.finish(group,"TerraceShadowReveals",recess,_material("819eae"),false)

func _west_arcade() -> void:
	var group := _group("WesternLayeredArcade",Vector3(-160,-24,16),1)
	group.scale = Vector3.ONE*1.35
	var arcade := F.surface()
	for i in 3:
		F.arch(arcade,Vector3((i-1)*24,0,-absf(i-1)*4),Vector2(17,13),23,3.0,8)
	F.solid(arcade,Vector3(0,39,0),Vector3(80,4.0,19),0.7)
	F.solid(arcade,Vector3(-20,43,-15),Vector3(47,4.1,23),0.55)
	F.solid(arcade,Vector3(-26,51,-18),Vector3(13,12,15),0.55)
	F.solid(arcade,Vector3(-26,66,-18),Vector3(7.5,18,10),0.42,0.90)
	F.solid(arcade,Vector3(33,16,-13),Vector3(21,20,25),0.65)
	F.arch(arcade,Vector3(40,26,-17),Vector2(13,13),12,2.4,7)
	F.finish(group,"ContinuousThreeVaultGallery",arcade,_material("bacbd0"))
	var reveal := F.surface()
	F.solid(reveal,Vector3(0,36.8,2),Vector3(78,0.5,18),0.1)
	F.solid(reveal,Vector3(-20,40.8,-15),Vector3(46,0.5,22),0.1)
	F.finish(group,"GalleryShadowLines",reveal,_material("8ba6b5"),false)
func _east_sanctums() -> void:
	var group := _group("EasternVerticalSanctums",Vector3(153,-23,81),1)
	var body := F.surface()
	var heights := [35.0,55.0,77.0,61.0,39.0]
	for i in heights.size():
		var x: float = (i-2)*9.7
		var z := -absf(i-2)*5.0
		var height: float = heights[i]
		F.solid(body,Vector3(x,height/2,z),Vector3(7.4,height,15),0.7,0.86)
		F.solid(body,Vector3(x,height+0.6,z),Vector3(7.0,1.2,14.3),0.35)
	F.solid(body,Vector3(0,9,-4),Vector3(68,4.0,33),0.8)
	F.solid(body,Vector3(14,24,-19),Vector3(37,3.5,19),0.45)
	F.arch(body,Vector3(-32,14,-18),Vector2(18,16),16,3.0,7)
	F.finish(group,"TaperedSanctumWings",body,_material("bacbd1"))
	var panel := F.surface()
	F.solid(panel,Vector3(0,46,7.55),Vector3(6,40,0.3),0.12)
	F.finish(group,"SanctumRecessedEnergyPath",panel,_material("afc4ce",true,0.0,7.7,46))
	inlay_count += 1
	var reveal := F.surface()
	F.solid(reveal,Vector3(0,6.8,-4),Vector3(64,0.65,31),0.1)
	F.solid(reveal,Vector3(14,22.0,-19),Vector3(35,0.55,17),0.1)
	F.finish(group,"SanctumUndercuts",reveal,_material("829fab"),false)

func _close_fragments() -> void:
	for spec: Array in [[Vector3(-67,-27,75),-0.15],[Vector3(108,-30,-2),0.12]]:
		var group := _group("NearBrokenArcade",spec[0],0)
		var mass := F.surface()
		F.arch(mass,Vector3.ZERO,Vector2(23,18),30,4.5,11)
		F.solid(mass,Vector3(-14,18,-6),Vector3(10,45,20),0.8,0.94)
		F.solid(mass,Vector3(-24,22,-6),Vector3(27,3.4,21),0.45)
		F.solid(mass,Vector3(-5,2,-6),Vector3(40,4,29),0.65)
		group.rotation.y += spec[1]
		F.finish(group,"FragmentOfOuterGallery",mass,_material("bdcbd0"))

func _perimeter_world() -> void:
	var group := _group("ContinuousFarArchitecturalWorld",Vector3(24,0,22.8),2)
	group.rotation.y = 0
	var silhouettes := F.surface()
	# A broad band with gaps and varied setbacks, not four lone objects or a row of pins.
	for i in 28:
		var angle := TAU*float(i)/28+0.08
		var radius := 246.0+21.0*sin(i*1.73)
		var center := Vector3(cos(angle)*radius,-39,sin(angle)*radius)
		var sector := Node3D.new()
		# Local orthogonal masses are turned tangentially before joining one draw batch.
		var basis := Basis(Vector3.UP,-angle)
		var size := Vector3(22.0+fposmod(i*7.1,17.0),46.0+fposmod(i*13.7,41),15.0)
		# Build each small neighborhood locally then transform its completed vertices.
		var local := F.surface()
		F.solid(local,Vector3(0,size.y/2,0),size,0.6,0.94)
		F.solid(local,Vector3(size.x*0.56,size.y*0.28,-8),Vector3(size.x*0.78,size.y*0.56,24),0.55)
		F.solid(local,Vector3(size.x*0.20,size.y*0.60,-5),Vector3(size.x*1.42,2.6,18),0.35)
		if i%4==1:
			F.arch(local,Vector3(-size.x*0.45,22,-4),Vector2(14,14),17,2.8,8)
		var mesh := local.commit()
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for j in vertices.size():
			silhouettes.set_normal(basis*normals[j])
			silhouettes.add_vertex(center+basis*vertices[j])
		sector.free()
		silhouette_count += 1
	F.finish(group,"RecedingArchitecturalSilhouettes",silhouettes,_material("bdd3dd"),false)







