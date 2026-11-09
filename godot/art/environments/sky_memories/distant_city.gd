@tool
extends Node3D
## Batches each authored district's solid volumes and window inlays separately.

const Finish := preload("res://art/environments/sky_memories/distant_city.gdshader")
const SkyEnvironment := preload("res://art/environments/maze01_dream_environment.tres")

func _ready() -> void:
	var box := BoxMesh.new()
	var spire := CylinderMesh.new()
	spire.radial_segments = 4
	spire.rings = 0
	spire.top_radius = 0.0
	spire.bottom_radius = 0.71
	for layer: Node3D in get_children():
		var far := layer.name == &"FarDistricts"
		var stone := _material(far, false)
		var amber := _material(far, true)
		for district: Marker3D in layer.get_children():
			_district(district, box, spire, stone, amber, far)

func _district(anchor: Marker3D, box: BoxMesh, spire: CylinderMesh, stone: ShaderMaterial, amber: ShaderMaterial, far: bool) -> void:
	var masonry := SurfaceTool.new()
	var glazing := SurfaceTool.new()
	masonry.begin(Mesh.PRIMITIVE_TRIANGLES)
	glazing.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(anchor.name))
	var variant := anchor.get_index()
	var height := 15.0 + float(variant % 4)*3.5
	# The broad terraces tie the towers together and read as streets between the roofs.
	_block(masonry,box,Vector3(-6.5,-8.5,0.5),Vector3(45.0,22.0,13.8))
	_block(masonry,box,Vector3(10.0,-7.0,-6.4),Vector3(32.0,22.0,14.1))
	for i in 10:
		var x := (i-4.5)*6.05 + rng.randf_range(-1.1,1.1)
		var z := rng.randf_range(-12.0,5.7)
		var roof_y := rng.randf_range(2.0,10.6) + (2.6 if far else 0.0)
		var width := rng.randf_range(4.4,6.2)
		var depth := rng.randf_range(4.8,8.9)
		_block(masonry, box, Vector3(x,(roof_y-16.0)*0.5,z), Vector3(width,roof_y+16.0,depth))
		if i%3 == variant%3:
			_block(masonry, box, Vector3(x,roof_y+0.65,z), Vector3(width*0.62,1.3,depth*0.74))
		if i%2 == 0 and roof_y > 4.0:
			_window(glazing, box, Vector3(x,roof_y-1.55,z+depth*0.5), 0.38, 1.15)
	var tower_x := -13.0 + 7.8 * float(variant%4)
	_tower(masonry, glazing, box, spire, Vector2(tower_x,-1.0), height, 5.8, variant%2==0)
	_tower(masonry, glazing, box, spire, Vector2(tower_x + (17.0 if tower_x<0 else -17.0),-10.0), height*0.76, 4.5, variant%2!=0)
	var hall_x := 11.0 if tower_x < 0.0 else -11.0
	_block(masonry,box,Vector3(hall_x,6.0,1.2),Vector3(12.2,12.1,10.8))
	_block(masonry,box,Vector3(hall_x,12.4,1.2),Vector3(13.5,0.9,11.2))
	for wing: float in [-1.0,1.0]:
		_window(glazing,box,Vector3(hall_x+wing*2.45,9.55,6.6),0.5,1.5)
	if variant%2 == 1:
		_arcade(masonry, box, Vector3(-13.0,1.0,13.5))
	else:
		_arcade(masonry, box, Vector3(15.5,0.0,13.6))
	_instance(anchor, "Architecture", masonry.commit(), stone)
	_instance(anchor, "WarmWindows", glazing.commit(), amber)

func _tower(tool: SurfaceTool, glazing: SurfaceTool, box: BoxMesh, spire: CylinderMesh, p: Vector2, height: float, width: float, pointed: bool) -> void:
	_block(tool, box, Vector3(p.x,(height-18.0)*0.5,p.y), Vector3(width,height+18.0,width))
	_block(tool, box, Vector3(p.x,height-0.67,p.y), Vector3(width*1.18,1.23,width*1.18))
	if pointed:
		_block(tool, spire, Vector3(p.x,height+1.88,p.y), Vector3(width*1.06,3.8,width*1.06), PI*0.25)
	else:
		_block(tool, box, Vector3(p.x,height+1.14,p.y), Vector3(width*0.68,2.28,width*0.68))
		for side: float in [-1.0,1.0]:
			_block(tool, box, Vector3(p.x+side*width*0.48,height+0.38,p.y), Vector3(0.55,1.17,width*1.12))
	_window(glazing, box, Vector3(p.x-width*0.18,height-2.9,p.y+width*0.5),0.38,1.45)
	_window(glazing, box, Vector3(p.x+width*0.18,height-2.9,p.y+width*0.5),0.38,1.45)
	_block(glazing, box, Vector3(p.x+width*0.5+0.025,height-5.4,p.y+0.64),Vector3(0.04,1.30,0.31))

func _arcade(tool: SurfaceTool, box: BoxMesh, origin: Vector3) -> void:
	for side: float in [-1.0,1.0]:
		_block(tool, box, origin+Vector3(side*4.42,-3.8,0),Vector3(1.8,18.0,3.65))
	var spring := origin+Vector3.UP*5.2
	var front := Vector3.BACK*1.825
	var curve := SurfaceTool.new()
	curve.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 16:
		var a := PI*i/16.0
		var b := PI*(i+1)/16.0
		var start := Vector3(cos(a),sin(a),0)
		var end := Vector3(cos(b),sin(b),0)
		var normal := (start+end).normalized()
		var oa := spring+start*5.32
		var ob := spring+end*5.32
		var ia := spring+start*3.52
		var ib := spring+end*3.52
		_quad(curve,oa+front,ob+front,ib+front,ia+front,Vector3.BACK)
		_quad(curve,oa-front,ob-front,ib-front,ia-front,Vector3.FORWARD)
		_quad(curve,oa-front,ob-front,ob+front,oa+front,normal)
		_quad(curve,ia-front,ib-front,ib+front,ia+front,-normal)
	curve.index()
	tool.append_from(curve.commit(),0,Transform3D.IDENTITY)

func _quad(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,normal: Vector3) -> void:
	tool.set_normal(normal)
	var face := [a,b,c,a,c,d] if (c-a).cross(b-a).dot(normal)>0.0 else [a,c,b,a,d,c]
	for point: Vector3 in face:
		tool.add_vertex(point)

func _window(tool: SurfaceTool, box: BoxMesh, p: Vector3, width: float, height: float) -> void:
	_block(tool,box,p+Vector3.BACK*0.024,Vector3(width,height,0.042))

func _block(tool: SurfaceTool, mesh: PrimitiveMesh, at: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	tool.append_from(mesh,0,Transform3D(Basis(Vector3.UP,yaw).scaled_local(size),at))

func _material(far: bool, windows: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Finish
	mat.set_shader_parameter("windows",windows)
	mat.set_shader_parameter("clarity",(0.49 if far else 0.74) if not windows else (0.64 if far else 0.84))
	mat.set_shader_parameter("city_center",Vector2(global_position.x,global_position.z))
	for key: StringName in [&"zenith",&"middle",&"horizon",&"nadir",&"cloud_color",&"sky_details"]:
		var value: Variant = SkyEnvironment.sky.sky_material.get_shader_parameter(key)
		if value != null:
			mat.set_shader_parameter(key,value)
	if far:
		mat.set_shader_parameter("mist",Color("bfa9d6"))
		mat.set_shader_parameter("shade",Color("9583b2"))
	return mat

func _instance(parent: Node3D, label: String, mesh: ArrayMesh, mat: ShaderMaterial) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = mat
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
