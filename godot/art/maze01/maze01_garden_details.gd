extends Node3D
## Small pieces of greenery, all visual-only. The three water leaves share one mesh.

const POND_LEAVES := [Vector2(1.07,10.84), Vector2(3.41,10.65), Vector2(3.75,13.14)]
const LEAF_SIZE := [0.28,0.22,0.32]
const MOSS_COLORS := [Color("82967a"),Color("9eac87"),Color("788f76"),Color("aab898")]
const BLOSSOM_COLORS := [Color("f5efdb"),Color("ecc1c9"),Color("f1dca7")]
const Turf := preload("res://art/maze01/plaza_grass.gdshader")
var _leaves: Array[MeshInstance3D] = []
var _water: float
var _age := 0.0

func install_pool(courtyard: Node3D, water: float) -> void:
	name = "FloatingDuckweed"
	_water = water
	courtyard.add_child(self)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := PackedVector3Array()
	for i in 10:
		var a := TAU*i/10.0
		var radius := 0.28 if i == 0 else 0.50
		rim.append(Vector3(cos(a)*radius,0.0,sin(a)*0.38))
	for i in rim.size():
		var tone := 0.87 + float(i%3)*0.045
		_face(surface,Vector3(0,0.043,0),rim[i],rim[(i+1)%rim.size()],Color(tone,tone,tone))
	var model := surface.commit()
	for i in POND_LEAVES.size():
		var material := _plant_material()
		material.albedo_color = [Color("a1bd86"),Color("c0d29b"),Color("85af8f")][i]
		material.roughness = 0.60
		var leaf := _mesh(self,"Duckweed%d"%(i+1),model,material)
		leaf.scale = Vector3.ONE*LEAF_SIZE[i]
		_leaves.append(leaf)
	_process(0.0)

func _process(delta: float) -> void:
	_age += delta
	for i in _leaves.size():
		var origin: Vector2 = POND_LEAVES[i]
		var phase := _age*(0.27+0.031*i)+2.12*i
		var point := origin+Vector2(cos(phase)*0.105,sin(phase)*0.075)
		var leaf := _leaves[i]
		leaf.position = Vector3(point.x,_water+0.026+sin(phase*2.7)*0.009,point.y)
		leaf.rotation = Vector3(sin(phase*2.7)*0.035,phase*0.21,cos(phase*2.7)*0.025)

static func install_plaza(statue: Node3D) -> void:
	var plants := SurfaceTool.new()
	plants.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91833
	var ground := PlaneMesh.new()
	ground.size = Vector2(9.0,9.0)
	var paint := ShaderMaterial.new()
	paint.shader = Turf
	_mesh(statue,"PlazaMeadow",ground,paint).position.y = 0.008
	# Loose clusters cover the meadow and leave room around the plinth.
	var pockets: Array[Vector2] = [
		Vector2(-2.43,-2.35),Vector2(-0.98,-1.62),Vector2(1.67,-2.12),Vector2(2.56,-0.96),
		Vector2(-2.49,-0.58),Vector2(-1.23,0.54),Vector2(2.06,0.91),Vector2(2.34,1.94),
		Vector2(-2.53,2.94),Vector2(-0.97,2.91),Vector2(1.37,2.85),Vector2(2.61,2.90),
		Vector2(0.14,-2.04),Vector2(-0.10,1.47),Vector2(-1.32,2.16),
	]
	for i in pockets.size():
		var center := pockets[i]
		for j in 13:
			var offset := Vector2.from_angle(rng.randf_range(0.0,TAU))*rng.randf_range(0.13,0.49)
			for blade in 2:
				var base := center+offset+Vector2(rng.randf_range(-0.045,0.045),rng.randf_range(-0.04,0.04))
				_grass(plants,base,rng.randf_range(0.075,0.21),rng.randf_range(0.0,TAU),MOSS_COLORS[(i+j+blade)%4])
		for flower in (5 if i%3 != 1 else 3):
			var offset := Vector2.from_angle(flower*2.22+i*0.73)*rng.randf_range(0.15,0.42)
			_flower(plants,center+offset,rng.randf_range(0.22,0.36),BLOSSOM_COLORS[(i+flower)%3])
	_mesh(statue,"PlazaGreenery",plants.commit(),_plant_material())

static func _grass(tool: SurfaceTool, p: Vector2, height: float, angle: float, color: Color) -> void:
	var base := Vector3(p.x,0.007,p.y)
	var fwd := Vector3(cos(angle),0,sin(angle))
	var edge := Vector3(-fwd.z,0,fwd.x)*0.013
	var bent := base+Vector3.UP*height*0.66+fwd*height*0.18
	var top := base+Vector3.UP*height+fwd*height*0.39
	_face(tool,base-edge,base+edge,bent+edge*0.66,color)
	_face(tool,base-edge,bent+edge*0.66,bent-edge*0.52,color.darkened(0.05))
	_face(tool,bent-edge*0.52,bent+edge*0.66,top,color.lightened(0.10))

static func _flower(tool: SurfaceTool, p: Vector2, height: float, color: Color) -> void:
	var head := Vector3(p.x,height,p.y)
	var size := 1.9 + height * 2.1
	_grass(tool,p,height,0.47,Color("8a9e78"))
	head += Vector3(cos(0.47),0,sin(0.47))*height*0.39
	for i in 5:
		var a := TAU*i/5.0
		var dir := Vector3(cos(a),0,sin(a))
		var edge := Vector3(-dir.z,0,dir.x)*0.012*size
		var ridge := head+(dir*0.024+Vector3.UP*0.007)*size
		_face(tool,head,ridge+edge,ridge+dir*0.013*size,color)
		_face(tool,head,ridge+dir*0.013*size,ridge-edge,color.darkened(0.04))
	for i in 5:
		var a := Vector2.from_angle(TAU*i/5.0)*0.010*size
		var b := Vector2.from_angle(TAU*(i+1)/5.0)*0.010*size
		_face(tool,head+Vector3.UP*0.009*size,head+Vector3(a.x,0.007*size,a.y),head+Vector3(b.x,0.007*size,b.y),Color("e8bf75"))

static func _face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	tool.set_color(color)
	tool.set_normal((c-a).cross(b-a).normalized())
	for vertex: Vector3 in [a,b,c]:
		tool.add_vertex(vertex)

static func _plant_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.84
	material.metallic_specular = 0.18
	return material

static func _mesh(parent: Node3D, label: String, model: Mesh, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = model
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.set_meta("art_addition",true)
	parent.add_child(visual)
	return visual
