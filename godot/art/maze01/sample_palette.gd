extends RefCounted
## Visual-only bindings. Never edits meshes, transforms, physics or layout data.
const Plaster := preload("res://art/maze01/materials/plaster_cream.tres")
const Roof := preload("res://art/maze01/materials/roof_lake.tres")
const Glass := preload("res://art/maze01/materials/glass_teal.tres")
const Trim := preload("res://art/maze01/materials/trim_warm.tres")
const PrismFinish := preload("res://art/maze01/legacy_prism_finish.gdshader")
const FLOOR_OPTIONS := [
	["清亮鸢尾蓝紫", Color("b1ace0")],
	["浅雾紫蓝", Color("c0c6e5")],
	["浅米石", Color("ddd1bc")],
]

static func stone_finish(color: Color, roughness: float, legacy_winding: bool, joint_strength: float = 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PrismFinish
	mat.set_shader_parameter("finish_color",color)
	mat.set_shader_parameter("finish_side_color",Plaster.albedo_color)
	mat.set_shader_parameter("finish_roughness",roughness)
	mat.set_shader_parameter("legacy_winding",legacy_winding)
	mat.set_shader_parameter("joint_strength",joint_strength)
	mat.set_shader_parameter("grain",Plaster.normal_texture)
	return mat

static func matte(color: Color,roughness: float = 0.78) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func bind(mesh: MeshInstance3D,mat: Material,role: String) -> void:
	mesh.material_override = mat
	mesh.set_meta("art_role",role)

static func apply(generator: Node3D) -> Array[ShaderMaterial]:
	var hall: Node3D = generator.round_hall
	var roof: Node3D = hall.get_node("Roof")
	var floor_finish := stone_finish(FLOOR_OPTIONS[0][1], 0.94, false, 0.024)
	var deck_finish := stone_finish(FLOOR_OPTIONS[0][1], 0.94, true, 0.024)
	var rail_finish := stone_finish(Plaster.albedo_color, Plaster.roughness, true)
	var moulding := Plaster.duplicate() as StandardMaterial3D
	moulding.albedo_color = Plaster.albedo_color.lerp(Color("c5bbae"), 0.19)
	for mesh: MeshInstance3D in hall.find_children("*","MeshInstance3D",true,false):
		var part := str(mesh.get_meta("greybox_part",""))
		if roof.is_ancestor_of(mesh):
			bind(mesh,Roof,"roof")
		elif part=="WindowPane":
			bind(mesh,Glass,"glass")
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif part=="HallFloor":
			bind(mesh,floor_finish,"floor")
		elif part in ["Cornice", "Plinth", "Sill", "ArchFrame"]:
			bind(mesh,moulding,"moulding")
		else:
			bind(mesh,Plaster,"plaster")
	for id: String in ["G4","G6","G7","G8"]:
		for mesh: MeshInstance3D in generator.architecture.get_node(id).find_children("*","MeshInstance3D",true,false):
			bind(mesh,Plaster,"plaster")
	for id: String in ["VerticalWalls","HorizontalWalls"]:
		for mesh: MeshInstance3D in generator.get_node(id).find_children("*","MeshInstance3D",true,false):
			var p: Vector3 = mesh.get_parent().position
			if p.x>=19.0 and p.x<=31.3 and p.z>=16.5 and p.z<=33.7:
				bind(mesh,Plaster,"plaster")
	for mesh: MeshInstance3D in generator.architecture.find_children("*","MeshInstance3D",true,false):
		var part := str(mesh.get_meta("greybox_part",""))
		if part.begins_with("GuardRail"):
			# Legacy prism vertices already use world coordinates; the body
			# origin is zero. Classify the actual mesh bounds, not that origin.
			var p: Vector3 = mesh.global_transform*mesh.get_aabb().get_center()
			if (p.x>=35 and p.z<23) or (p.x>=34 and p.z>=28 and p.z<=32) or (p.x>=19 and p.x<=27 and p.z>=27):
				bind(mesh,rail_finish,"rail_plaster")
		elif part.begins_with("H2_") or part.begins_with("H4_"):
			bind(mesh,deck_finish,"floor")
	var coral := matte(Color("d39d88"),0.59)
	for id: String in ["D2", "D4"]:
		for mesh: MeshInstance3D in generator.gates[id].find_children("*","MeshInstance3D",true,false):
			var part := str(mesh.get_meta("greybox_part",""))
			if part.begins_with("Bar") or part=="Crossbar":
				bind(mesh,coral,"gate_coral")
			else:
				bind(mesh,Plaster,"plaster")
	for label: Label3D in generator.find_children("*","Label3D",true,false):
		label.hide()
	_add_details(generator, floor_finish)
	return [floor_finish, deck_finish]

static func visual(parent: Node3D,id: String,mesh: Mesh,mat: Material,point: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = id
	node.mesh = mesh
	node.material_override = mat
	node.position = point
	node.set_meta("art_addition",true)
	parent.add_child(node)
	return node

static func box(parent: Node3D,id: String,size: Vector3,point: Vector3,mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return visual(parent,id,mesh,mat,point)

static func _add_details(generator: Node3D, floor_finish: ShaderMaterial) -> void:
	var extras := Node3D.new()
	extras.name = "ArtSampleDetails"
	generator.architecture.add_child(extras)
	# Local, non-colliding display patches; no global floor or source mesh replacement.
	var patch := PlaneMesh.new()
	patch.size = Vector2(11.8,10.2)
	bind(visual(extras,"ChapelCourtFinish",patch,floor_finish,Vector3(25,0.013,22)), floor_finish, "floor")
	for x: float in [19.2,30.8]:
		box(extras,"CourtEdge",Vector3(0.025,0.004,10),Vector3(x,0.018,22),Trim)
	var shine := matte(Color(0.92,0.98,1.0,0.26),0.2)
	shine.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shine.render_priority = 2
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var warm_glass := Glass.duplicate() as StandardMaterial3D
	warm_glass.emission = Color("f0d9b7")
	warm_glass.emission_energy_multiplier = 0.18
	var count := 0
	for window: Node3D in generator.round_hall.find_children("ArchedWindowRecess*","Node3D",true,false):
		if count%3==1:
			for pane: MeshInstance3D in window.find_children("*","MeshInstance3D",true,false):
				if pane.get_meta("art_role","")=="glass":
					bind(pane,warm_glass,"glass_warm")
		var strip := box(window,"GlassGlint",Vector3(0.024,0.65,0.002),Vector3(-0.22,1.62,0.071),shine)
		strip.rotation.z = -0.22
		count += 1
	# Fine arch-front structure line; no global outline and no extra physics.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 25:
		var a := PI*i/24
		st.add_vertex(Vector3(cos(a)*1.205,1.6+sin(a)*1.205,-0.211))
	visual(generator.architecture.get_node("G4"),"QuietArchJoint",st.commit(),Trim,Vector3.ZERO)
	for point: Vector3 in [Vector3(24,4.25,22.8),Vector3(22.8,4.25,20.0),Vector3(26.4,4.25,20.4)]:
		_lamp(extras,point,point.x==24)

static func _lamp(parent: Node3D,point: Vector3,real_light: bool) -> void:
	var lamp := Node3D.new()
	lamp.name = "WarmPendant"
	lamp.position = point
	parent.add_child(lamp)
	var brass := matte(Color("ad9973"),0.53)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.012
	stem.bottom_radius = 0.012
	stem.height = 1.2
	stem.radial_segments = 8
	visual(lamp,"Stem",stem,brass,Vector3(0,0.8,0))
	var shade := CylinderMesh.new()
	shade.top_radius = 0.17
	shade.bottom_radius = 0.37
	shade.height = 0.29
	shade.radial_segments = 12
	visual(lamp,"Shade",shade,Plaster,Vector3(0,0.12,0))
	var glow := matte(Color("ffe2a7"))
	glow.emission_enabled = true
	glow.emission = Color("ffd890")
	glow.emission_energy_multiplier = 1.4
	var bulb := SphereMesh.new()
	bulb.radius = 0.10
	bulb.height = 0.20
	visual(lamp,"Bulb",bulb,glow,Vector3(0,-0.055,0))
	if real_light:
		var light := OmniLight3D.new()
		light.name = "InteriorWarmFill"
		light.light_color = Color("fff0dc")
		light.light_energy = 0.50
		light.omni_range = 4.7
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		lamp.add_child(light)
