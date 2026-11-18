extends Node3D
const F := preload("res://modules/maze03_final/architecture_forms.gd")
var elapsed := 0.0
var pivot: Node3D
var base_height := 1.22
var coupling_energy := 1.0
var surface_material: ShaderMaterial
var core_material: StandardMaterial3D
var bounce_light: OmniLight3D
func _ready() -> void:
	name = "HoveringBlueCube"
	position = Vector3(24,base_height,22.8)
	pivot = Node3D.new()
	pivot.rotation_degrees = Vector3(45,0,45)
	add_child(pivot)
	var surface := F.surface()
	_build_beveled_cube(surface,0.21,0.011)
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://modules/maze03_final/hover_cube.gdshader")
	surface_material = paint
	var sun := get_tree().root.find_child("Sun",true,false) as DirectionalLight3D
	if sun!=null:
		paint.set_shader_parameter("sun_direction",sun.global_basis.z)
	F.finish(pivot,"SolidBlueGeometricCube",surface,paint,false)
	var glyph := StandardMaterial3D.new()
	glyph.albedo_color = Color(0.56,0.81,1.0,0.4)
	glyph.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glyph.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glyph.roughness = 0.8
	glyph.emission_enabled = true
	glyph.emission = Color("80bddf")
	glyph.emission_energy_multiplier = 0.25
	var markings := F.surface()
	for axis in 3:
		for signum: float in [-1.0,1.0]:
			var normal := Vector3.ZERO
			normal[axis] = signum
			var u := Vector3.ZERO
			u[(axis+1)%3] = 1.0
			var v := normal.cross(u)
			var center := normal*0.2106
			var outer := [Vector2(0,0.065),Vector2(-0.055,-0.038),Vector2(0.055,-0.038)]
			for i in 3:
				var a: Vector2 = outer[i]
				var b: Vector2 = outer[(i+1)%3]
				F.face(markings,PackedVector3Array([center+u*a.x+v*a.y,center+u*b.x+v*b.y,center+u*b.x*0.80+v*b.y*0.80,center+u*a.x*0.80+v*a.y*0.80]),normal)
	F.finish(pivot,"QuietInsetTriangleMarks",markings,glyph,false)
	var core := MeshInstance3D.new()
	core.name = "LuminousEnergyCore"
	var orb := SphereMesh.new()
	orb.radius = 0.065
	orb.height = 0.13
	orb.radial_segments = 16
	orb.rings = 8
	core.mesh = orb
	core_material = StandardMaterial3D.new()
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.albedo_color = Color(0.80,0.95,1.0,0.90)
	core_material.emission_enabled = true
	core_material.emission = Color("c4f1ff")
	core_material.emission_energy_multiplier = 1.8
	core_material.render_priority = -1
	core.material_override = core_material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var bounce := OmniLight3D.new()
	bounce.name = "CubeBlueBounce"
	bounce_light = bounce
	bounce.omni_range = 3.2
	bounce.light_color = Color("9edfff")
	bounce.light_energy = 0.85
	bounce.shadow_enabled = false
	add_child(bounce)
func _build_beveled_cube(st: SurfaceTool,h: float,b: float) -> void:
	var k := h-b
	for axis in 3:
		for signum: float in [-1.0,1.0]:
			var normal := Vector3.ZERO
			normal[axis] = signum
			var points := PackedVector3Array()
			for p: Vector2 in [Vector2(-k,-k),Vector2(k,-k),Vector2(k,k),Vector2(-k,k)]:
				var q := normal*h
				q[(axis+1)%3] = p.x
				q[(axis+2)%3] = p.y
				points.append(q)
			F.face(st,points,normal)
	for a in 3:
		var c := (a+1)%3
		var other := (a+2)%3
		for sa: float in [-1.0,1.0]:
			for sc: float in [-1.0,1.0]:
				var points := PackedVector3Array()
				for uv: Vector2 in [Vector2(0,-k),Vector2(1,-k),Vector2(1,k),Vector2(0,k)]:
					var q := Vector3.ZERO
					q[a] = sa*(h if uv.x==0 else k)
					q[c] = sc*(k if uv.x==0 else h)
					q[other] = uv.y
					points.append(q)
				var normal := Vector3.ZERO
				normal[a] = sa
				normal[c] = sc
				F.face(st,points,normal.normalized())
	for sx: float in [-1.0,1.0]:
		for sy: float in [-1.0,1.0]:
			for sz: float in [-1.0,1.0]:
				F.face(st,PackedVector3Array([Vector3(sx*h,sy*k,sz*k),Vector3(sx*k,sy*h,sz*k),Vector3(sx*k,sy*k,sz*h)]),Vector3(sx,sy,sz).normalized())
func _process(delta: float) -> void:
	elapsed += delta
	position.y = base_height+sin(elapsed*TAU/4.8)*0.05
	rotation.y = elapsed*0.34
	coupling_energy = 0.94+0.06*sin(elapsed*0.9)
	surface_material.set_shader_parameter("energy_pulse",coupling_energy)
	core_material.emission_energy_multiplier = 1.8*coupling_energy
	bounce_light.light_energy = 0.95*coupling_energy





