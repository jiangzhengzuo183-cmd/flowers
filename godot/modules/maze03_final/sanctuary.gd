extends Node3D
const G := preload("res://scripts/levels/greybox_geometry.gd")
const CENTER := Vector3(24, 0, 22.8)
const POOL := Rect2(15.6, 14.4, 16.8, 16.8)
var pads: Array[Node3D] = []
var routes: Array = []
var water: ShaderMaterial
var reflection: SubViewport
var reflection_camera: Camera3D
var white: StandardMaterial3D
var rib_count := 0
var axis_material: ShaderMaterial

func _ready() -> void:
	white = load("res://art/maze01/materials/plaster_cream.tres").duplicate()
	white.albedo_color = Color("e9e9e5")
	white.roughness = 0.82
	white.normal_scale = 0.10
	_build_pool()
	_build_shell()
	_build_light()
	add_child(preload("res://modules/maze03_final/hover_cube.gd").new())
	add_child(preload("res://modules/maze03_final/interior_atmosphere.gd").new())
	for mesh: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		if not str(mesh.name) == "ReflectiveRingWater" and mesh.to_global(mesh.get_aabb().end).y < 0.02:
			mesh.layers = 4
	_build_reflection()

func _build_pool() -> void:
	G.box(self, "MirrorBasinBed", Vector3(POOL.size.x, 0.24, POOL.size.y), Vector3(24, -0.57, 22.8), G.material(Color("94b4c0")))
	_build_wade_floor()
	G.box(self, "SanctuaryFoundation", Vector3(7.4, 0.36, 7.4), CENTER - Vector3.UP * 0.18, white)
	var face := MeshInstance3D.new()
	face.name = "ReflectiveRingWater"
	var plane := PlaneMesh.new()
	plane.size = POOL.size
	face.mesh = plane
	face.position = Vector3(24, -0.14, 22.8)
	face.layers = 2
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water = ShaderMaterial.new()
	water.shader = preload("res://modules/maze03_final/water.gdshader")
	face.material_override = water
	add_child(face)
	_path("North", Vector3(24,0,14.25), Vector3(24,0,19.15), 5)
	_path("South", Vector3(24,0,31.35), Vector3(24,0,26.45), 5)

func _path(id: String, start: Vector3, end: Vector3, count: int) -> void:
	routes.append([start, end])
	var along := (end - start).normalized()
	var side := along.cross(Vector3.UP)
	var spacing := start.distance_to(end) / float(count)
	for i in count:
		var point := start.lerp(end, (i + 0.5) / float(count))
		# Offset alternate rounded pads; the small gaps remain walkable at normal speed.
		point += side*(0.0 if i==0 or i==count-1 else (0.13 if i%2==0 else -0.13))
		var polygon := PackedVector2Array()
		for j in 16:
			var angle := TAU*j/16.0+0.08*sin(i*1.4)
			var variation := 1.0+0.045*sin(j*2.0+i*1.9)+0.025*cos(j*3.0-i)
			var offset := side*cos(angle)*(0.405+0.018*cos(i))*variation+along*sin(angle)*(spacing*0.375)*variation
			polygon.append(Vector2(point.x+offset.x,point.z+offset.z))
		var pad := G.extruded_polygon(self,"SeparatedPad_"+id+str(i),polygon,-0.105,0.0,white,true)
		pad.set_meta("separated_pad",true)
		pad.set_meta("rounded_footprint",polygon)
		pads.append(pad)

func _build_shell() -> void:
	var shell := Node3D.new()
	shell.name = "FinSanctuary"
	shell.position = CENTER
	add_child(shell)
	var half := 3.50
	var crown := 0.77
	var height := 10.3
	for side in 4:
		for i in 33:
			var offset := (i - 16) * 0.208
			var top := height * (1.0 - maxf(0.0, absf(offset) - crown) / (half - crown))
			var base := 2.65 if side in [0,2] and absf(offset) < 0.98 else 0.0
			if top <= base + 0.05:
				continue
			var vertices := PackedVector3Array()
			for x in [offset - 0.072, offset + 0.072]:
				var tip := height * (1.0 - maxf(0.0,absf(x)-crown)/(half-crown))
				for inset in [0.0, 0.32]:
					for y in [base, tip]:
						var depth: float = lerpf(half, crown, y / height) - inset
						var vertex := Vector3(clampf(x,-depth,depth), y, -depth).rotated(Vector3.UP, -side * PI * 0.5)
						vertices.append(vertex)
			# Geometry.prism expects the two four-corner rings in its standard order.
			var ordered := PackedVector3Array([vertices[0],vertices[1],vertices[3],vertices[2],vertices[4],vertices[5],vertices[7],vertices[6]])
			G.prism(shell, "StructuralFin_" + str(side) + "_" + str(i), ordered, white, true)
			rib_count += 1
	var crown_surface := SurfaceTool.new()
	crown_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 64:
		var a := TAU * float(i) / 64
		var b := TAU * float(i+1) / 64
		var va := Vector2(cos(a),sin(a))
		var vb := Vector2(cos(b),sin(b))
		var outer_a := va * crown / maxf(absf(va.x),absf(va.y))
		var outer_b := vb * crown / maxf(absf(vb.x),absf(vb.y))
		var points := [Vector3(outer_a.x,height,outer_a.y),Vector3(outer_b.x,height,outer_b.y),Vector3(vb.x*0.60,height,vb.y*0.60),Vector3(va.x*0.60,height,va.y*0.60)]
		for index in [0,2,1,0,3,2]:
			crown_surface.set_normal(Vector3.UP)
			crown_surface.add_vertex(points[index])
	var crown_mesh := MeshInstance3D.new()
	crown_mesh.name = "OpenCircularSkylightCrown"
	crown_mesh.mesh = crown_surface.commit()
	crown_mesh.material_override = white
	shell.add_child(crown_mesh)

func _build_light() -> void:
	# Lighting only: the sanctuary shell, oculus, entrances and basin stay intact.
	var light := SpotLight3D.new()
	light.name = "OculusBlueShaftLight"
	light.position = CENTER + Vector3.UP * 10.1
	light.rotation_degrees.x = -90
	light.spot_angle = 22
	light.spot_range = 11.0
	light.light_color = Color("f6f4ed")
	light.light_energy = 1.85
	add_child(light)
	light.look_at(CENTER+Vector3(1.4,0.1,1.0))
	var rim := OmniLight3D.new()
	rim.name = "SkylightBlueBounce"
	rim.position = CENTER+Vector3.UP*10.6
	rim.omni_range = 2.6
	rim.light_color = Color("c4dfe9")
	rim.light_energy = 0.35
	rim.shadow_enabled = false
	add_child(rim)
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = preload("res://modules/maze03_final/beam.gdshader")
	axis_material = beam_mat
	# Crossing depth-tested ribbons keep the shaft visible from every azimuth.
	# The upper part extends beyond the roof; it never draws through opaque walls.
	for i in 3:
		var beam := MeshInstance3D.new()
		beam.name = "ContinuousBlueAxis"+str(i)
		var quad := QuadMesh.new()
		quad.size = Vector2(3.1,57.0)
		beam.mesh = quad
		beam.position = CENTER+Vector3.UP*28.5
		beam.rotation.y = i*PI/3.0
		beam.material_override = beam_mat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
func _build_reflection() -> void:
	reflection = SubViewport.new()
	reflection.name = "MirrorReflection"
	reflection.size = Vector2i(768, 432)
	reflection.world_3d = get_world_3d()
	reflection.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(reflection)
	reflection_camera = Camera3D.new()
	reflection_camera.cull_mask = 1
	reflection_camera.near = 0.1
	reflection_camera.far = 500
	reflection.add_child(reflection_camera)
	water.set_shader_parameter("reflection_image", reflection.get_texture())
	water.set_shader_parameter("reflection_ready", true)

func _process(_delta: float) -> void:
	var cube := get_node_or_null("HoveringBlueCube")
	if cube!=null and axis_material!=null:
		axis_material.set_shader_parameter("core_height",cube.global_position.y)
		axis_material.set_shader_parameter("energy_pulse",cube.coupling_energy)
	if not is_instance_valid(reflection_camera):
		return
	var source := get_viewport().get_camera_3d()
	if source == null:
		return
	# Do not redraw the whole world a second time while the pool is off screen.
	var on_screen := false
	for x: float in [POOL.position.x,24.0,POOL.end.x]:
		for z: float in [POOL.position.y,22.8,POOL.end.y]:
			if source.is_position_in_frustum(Vector3(x,-0.14,z)):
				on_screen = true
	if not on_screen:
		return
	var transform := source.global_transform
	transform.origin.y = -0.28 - transform.origin.y
	transform.basis.x.y *= -1
	transform.basis.y.y *= -1
	transform.basis.z.y *= -1
	transform.basis.x *= -1
	reflection_camera.global_transform = transform
	var source_size := source.get_viewport().get_visible_rect().size
	var target_size := Vector2i(768,maxi(128,roundi(768*source_size.y/maxf(1.0,source_size.x))))
	if reflection.size != target_size:
		reflection.size = target_size
	reflection_camera.projection = source.projection
	reflection_camera.fov = source.fov
	reflection_camera.size = source.size
	water.set_shader_parameter("reflection_view_projection", reflection_camera.get_camera_projection() * Projection(reflection_camera.global_transform.affine_inverse()))
	reflection.render_target_update_mode = SubViewport.UPDATE_ONCE

func _exit_tree() -> void:
	set_process(false)
	if is_instance_valid(water):
		water.set_shader_parameter("reflection_image",null)
	if is_instance_valid(reflection):
		reflection.render_target_update_mode = SubViewport.UPDATE_DISABLED
func _build_wade_floor() -> void:
	# A shallow underwater bevel lets Charlie walk in and back out without a jump.
	var cuts_x := [POOL.position.x,POOL.position.x+0.65,POOL.end.x-0.65,POOL.end.x]
	var cuts_z := [POOL.position.y,POOL.position.y+0.65,POOL.end.y-0.65,POOL.end.y]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for row in 3:
		for col in 3:
			var vertices := PackedVector3Array()
			for offset: Vector2i in [Vector2i.ZERO,Vector2i(1,0),Vector2i.ONE,Vector2i(0,1)]:
				var x: float = cuts_x[col+offset.x]
				var z: float = cuts_z[row+offset.y]
				var distance := minf(minf(x-POOL.position.x,POOL.end.x-x),minf(z-POOL.position.y,POOL.end.y-z))
				vertices.append(Vector3(x,-0.42*clampf(distance/0.65,0,1),z))
			for triangle: Array in [[0,1,2],[0,2,3]]:
				var a := vertices[triangle[0]]
				var b := vertices[triangle[1]]
				var c := vertices[triangle[2]]
				st.set_normal((c-a).cross(b-a).normalized())
				for v: Vector3 in [a,b,c]:
					st.add_vertex(v)
					faces.append(v)
	var body := StaticBody3D.new()
	body.name = "WalkableShallowBasin"
	body.collision_layer = 5
	add_child(body)
	var visual := MeshInstance3D.new()
	visual.mesh = st.commit()
	visual.material_override = G.material(Color("94b4c0"))
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collider.shape = shape
	body.add_child(collider)




