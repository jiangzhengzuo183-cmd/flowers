extends Node3D
const G:=preload("res://scripts/levels/greybox_geometry.gd")
const Layout:=preload("res://scripts/maze03/layout.gd")
const Finish:=preload("res://art/maze03/finish.gd")
const HALF_BASE:=4.05
const TOP_HALF:=0.80
const HEIGHT:=10.2
const OCULUS:=0.70
const FIN_PITCH:=0.225
const FIN_WIDTH:=0.158
var shell: Node3D
var rib_count:=0
var pads: Array[Node3D]=[]
var pad_paths: Array=[]
var water_material: ShaderMaterial
var reflection_view: SubViewport
var reflection_camera: Camera3D
var white: Material
func _ready() -> void:
	white=Finish.stone(Color("e9eae7"),false,true)
	_build_pool()
	_build_ribbed_pyramid()
	_build_shaft()
	_build_reflection()
	for mesh: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		mesh.set_meta("custom_maze03_finish",true)

func _face(side: int,u: float,y: float,inset: float=0.0) -> Vector3:
	var d:=lerpf(HALF_BASE,TOP_HALF,y/HEIGHT)-inset*(1.0-0.84*pow(y/HEIGHT,6.0))
	match side:
		0:return Vector3(u,y,-d)
		1:return Vector3(d,y,u)
		2:return Vector3(-u,y,d)
		_:return Vector3(-d,y,-u)

func _build_ribbed_pyramid() -> void:
	shell=Node3D.new()
	shell.name="VerticalFinPyramid"
	shell.position=Layout.CENTER
	add_child(shell)
	var liner_material:=Finish.stone(Color("cdd2d2"),false,true)
	for side in 4:
		# True recessed internal skin gives the finely spaced deep plates mass.
		# Four pitched facades are defined by the plates themselves, not a box.
		var outline:=PackedVector2Array([Vector2(-HALF_BASE,0)])
		if side in [0,1,2]:
			outline.append_array(PackedVector2Array([Vector2(-1.08,0),Vector2(-1.08,2.42),Vector2(1.08,2.42),Vector2(1.08,0)]))
		outline.append_array(PackedVector2Array([Vector2(HALF_BASE,0),Vector2(TOP_HALF,HEIGHT),Vector2(-TOP_HALF,HEIGHT)]))
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var faces:=PackedVector3Array()
		var tris:=Geometry2D.triangulate_polygon(outline)
		var normal:=Vector3(0,(HALF_BASE-TOP_HALF)/HEIGHT,-1).normalized()
		normal=normal.rotated(Vector3.UP,-side*PI*0.5)
		for i in range(0,tris.size(),3):
			var a: Vector2=outline[tris[i]];var b: Vector2=outline[tris[i+1]];var c: Vector2=outline[tris[i+2]]
			_triangle(st,faces,_face(side,a.x,a.y,0.30),_face(side,b.x,b.y,0.30),_face(side,c.x,c.y,0.30),normal)
		_add_surface(shell,"RecessedStructuralSkin_%d"%side,st,faces,liner_material)
		var count:=floori(HALF_BASE*2/FIN_PITCH)
		for i in count:
			var u: float=(i-(count-1)*0.5)*FIN_PITCH
			var top_y:=HEIGHT*(1.0-maxf(0.0,absf(u)-TOP_HALF)/(HALF_BASE-TOP_HALF))
			var base_y:=2.42 if side in [0,1,2] and absf(u)<1.08 else 0.0
			if top_y<=base_y+0.08:
				continue
			var vertices:=PackedVector3Array()
			for across in [-FIN_WIDTH*0.5,FIN_WIDTH*0.5]:
				var edge_top:=HEIGHT*(1.0-maxf(0.0,absf(u+across)-TOP_HALF)/(HALF_BASE-TOP_HALF))
				vertices.append_array(PackedVector3Array([_face(side,u+across,base_y),_face(side,u+across,edge_top),_face(side,u+across,edge_top,0.34),_face(side,u+across,base_y,0.34)]))
			var rib:=G.prism(shell,"StructuralVerticalFin_%d_%d"%[side,i],vertices,white,true)
			rib_count+=1
			rib.set_meta("structural_fin",true)
	# A real circular skylight within a small square crown; no cap across it.
	var top:=SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_faces:=PackedVector3Array()
	for i in 96:
		var a:=TAU*i/96;var b:=TAU*(i+1)/96
		var va:=Vector2(cos(a),sin(a));var vb:=Vector2(cos(b),sin(b))
		var oa:=va*TOP_HALF/maxf(absf(va.x),absf(va.y));var ob:=vb*TOP_HALF/maxf(absf(vb.x),absf(vb.y))
		_triangle(top,top_faces,Vector3(oa.x,HEIGHT,oa.y),Vector3(ob.x,HEIGHT,ob.y),Vector3(vb.x*OCULUS,HEIGHT,vb.y*OCULUS),Vector3.UP)
		_triangle(top,top_faces,Vector3(oa.x,HEIGHT,oa.y),Vector3(vb.x*OCULUS,HEIGHT,vb.y*OCULUS),Vector3(va.x*OCULUS,HEIGHT,va.y*OCULUS),Vector3.UP)
	_add_surface(shell,"OpenCircularOculus",top,top_faces,white)

func _triangle(st: SurfaceTool,faces: PackedVector3Array,a: Vector3,b: Vector3,c: Vector3,normal: Vector3) -> void:
	if (b-a).cross(c-a).dot(normal)>0.0:
		var swap:=b;b=c;c=swap
	st.set_normal(normal)
	for vertex: Vector3 in [a,b,c]:
		st.add_vertex(vertex);faces.append(vertex)

func _add_surface(parent: Node3D,id: String,st: SurfaceTool,faces: PackedVector3Array,material: Material) -> void:
	var body:=StaticBody3D.new();body.name=id;body.collision_layer=5
	var collider:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new()
	shape.backface_collision=true;shape.set_faces(faces);collider.shape=shape;body.add_child(collider)
	var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material;body.add_child(mesh);parent.add_child(body)

func _build_pool() -> void:
	var r:=Layout.POOL
	var center:=Layout.CENTER
	var bed:=G.box(self,"NewMirrorPoolBed",Vector3(r.size.x,0.20,r.size.y),center-Vector3.UP*0.45,Finish.stone(Color("8ba8b5")))
	(bed.get_child(0) as MeshInstance3D).layers=4
	var foundation:=G.box(self,"SanctuaryIsland",Vector3(8.5,0.32,8.5),center-Vector3.UP*0.16,white)
	(foundation.get_child(0) as MeshInstance3D).layers=4
	for z in [r.position.y,r.end.y]:
		G.box(self,"FlushWhitePoolCoping",Vector3(r.size.x+0.18,0.22,0.18),Vector3(center.x,-0.11,z),white)
	for x in [r.position.x,r.end.x]:
		G.box(self,"FlushWhitePoolCoping",Vector3(0.18,0.22,r.size.y),Vector3(x,-0.11,center.z),white)
	water_material=ShaderMaterial.new();water_material.shader=preload("res://art/maze03/water.gdshader")
	var water:=MeshInstance3D.new();water.name="NewContinuousRingWater"
	var plane:=PlaneMesh.new();plane.size=r.size;water.mesh=plane
	water.position=center-Vector3.UP*0.08;water.layers=2;water.material_override=water_material
	water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(water)
	# Each pad has its own matching solid collider. There is no hidden bridge.
	_step_path("North",[Vector3(25.2,0,15.5),Vector3(25.0,0,16.6),Vector3(24.45,0,17.7),Vector3(24.0,0,18.80)],false)
	_step_path("East",[Vector3(28.15,0,22.8),Vector3(29.25,0,22.72),Vector3(30.35,0,22.50),Vector3(31.45,0,22.78),Vector3(32.55,0,23.05),Vector3(33.65,0,22.8)],true)
	_step_path("South",[Vector3(24.0,0,26.95),Vector3(23.8,0,28.05),Vector3(23.15,0,29.15),Vector3(22.40,0,30.25),Vector3(21.5,0,31.35)],false)
	var rng:=RandomNumberGenerator.new();rng.seed=33057
	var star_material:=StandardMaterial3D.new();star_material.albedo_color=Color("cceeff");star_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 28:
		var pos:=Vector3(rng.randf_range(r.position.x+0.4,r.end.x-0.4),-0.095,rng.randf_range(r.position.y+0.4,r.end.y-0.4))
		if absf(pos.x-center.x)<4.4 and absf(pos.z-center.z)<4.4:
			pos.x=r.position.x+0.6 if i%2==0 else r.end.x-0.6
		var mesh:=SphereMesh.new();mesh.radius=rng.randf_range(0.016,0.027);mesh.height=mesh.radius*2
		var point:=MeshInstance3D.new();point.name="SubmergedStar_%02d"%i;point.mesh=mesh;point.position=pos;point.material_override=star_material;add_child(point)

func _step_path(id: String,points: Array,along_x: bool) -> void:
	pad_paths.append(points)
	for i in points.size():
		var width:=1.50+0.10*sin(i*2.13+id.length())
		var length:=0.89+0.025*sin(i*1.37)
		var dimensions:=Vector3(length,0.26,width) if along_x else Vector3(width,0.26,length)
		var pad:=G.box(self,"SeparatedPad_%s_%02d"%[id,i],dimensions,points[i]-Vector3.UP*0.13,white)
		pad.rotation_degrees.y=sin(i*2.3)*3.0
		pad.set_meta("visible_footprint",dimensions)
		pads.append(pad)

func _build_shaft() -> void:
	var material:=ShaderMaterial.new();material.shader=preload("res://art/maze03/beam.gdshader")
	for i in 5:
		var beam:=MeshInstance3D.new();beam.name="ColdOculusLightShaft"
		var plane:=QuadMesh.new();plane.size=Vector2(1.25,HEIGHT-0.05);beam.mesh=plane
		beam.position=Layout.CENTER+Vector3.UP*(HEIGHT*0.5);beam.rotation.y=i*PI/5;beam.material_override=material
		beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(beam)
	var light:=SpotLight3D.new();light.name="OculusColdWhiteLight";light.position=Layout.CENTER+Vector3.UP*(HEIGHT-0.05)
	light.rotation_degrees.x=-90;light.spot_range=HEIGHT+1;light.spot_angle=8;light.light_color=Color("dcefff");light.light_energy=2.1;add_child(light)
	var dust:=CPUParticles3D.new();dust.name="OculusAirMotes";dust.position=Layout.CENTER+Vector3.UP*4.8
	dust.amount=22;dust.lifetime=9.0;dust.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;dust.emission_box_extents=Vector3(0.45,4.4,0.45)
	dust.gravity=Vector3(0.003,-0.011,0.002);dust.initial_velocity_min=0.01;dust.initial_velocity_max=0.03
	var sphere:=SphereMesh.new();sphere.radius=0.013;sphere.height=0.026
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("dcf2ff");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;sphere.material=mat;dust.mesh=sphere;add_child(dust)

func _build_reflection() -> void:
	reflection_view=SubViewport.new();reflection_view.name="MirrorPoolPlanarReflection";reflection_view.size=Vector2i(1024,640)
	reflection_view.world_3d=get_world_3d();reflection_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;reflection_view.msaa_3d=Viewport.MSAA_2X;add_child(reflection_view)
	reflection_camera=Camera3D.new();reflection_camera.cull_mask=1;reflection_camera.far=500;reflection_camera.near=0.06;reflection_view.add_child(reflection_camera)
	water_material.set_shader_parameter("reflection_image",reflection_view.get_texture())
func _process(_delta: float) -> void:
	var source:=get_viewport().get_camera_3d()
	if source==null or not is_instance_valid(reflection_camera):return
	var reflect:=func(p: Vector3) -> Vector3:return Vector3(p.x,-0.16-p.y,p.z)
	var at: Vector3=reflect.call(source.global_position);var aim: Vector3=reflect.call(source.global_position-source.global_basis.z)
	var up:=source.global_basis.y;up.y=-up.y
	reflection_camera.global_position=at;reflection_camera.look_at(aim,up);reflection_camera.projection=source.projection;reflection_camera.fov=source.fov;reflection_camera.size=source.size
	var size:=get_viewport().get_visible_rect().size
	reflection_view.size=Vector2i(1024,maxi(256,int(1024*size.y/maxf(size.x,1))))
func _exit_tree() -> void:
	# Release the viewport texture before its owning SubViewport leaves the tree.
	set_process(false)
	if is_instance_valid(water_material):water_material.set_shader_parameter("reflection_image",null)
	if is_instance_valid(reflection_view):reflection_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
