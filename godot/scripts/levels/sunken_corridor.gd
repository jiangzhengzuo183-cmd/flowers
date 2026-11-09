extends RefCounted
## H6 is independent of raised surfaces: negative floor heights must not max with zero.
const Geometry := preload("res://scripts/levels/greybox_geometry.gd")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const NicheStar := preload("res://scripts/levels/niche_star.gd")
const NICHE_FRONT := 4.65
const NICHE_BACK := 5.16
const NICHE_OUTER_BACK := 5.28
const NICHE_OUTER_HALF_WIDTH := 0.62
const NICHE_INNER_HALF_WIDTH := 0.54
const STAR_MODELS := [
	preload("res://art/maze01/niche_stars/four_point_star.glb"),
	preload("res://art/maze01/niche_stars/gold_star.glb"),
	preload("res://art/maze01/niche_stars/violet_gem.glb"),
]
const STAR_CHIMES := [
	preload("res://art/maze01/niche_stars/do.wav"),
	preload("res://art/maze01/niche_stars/re.wav"),
	preload("res://art/maze01/niche_stars/mi.wav"),
]

static func install_stars(corridor: Node3D, spec: Dictionary, actor: CharacterBody3D) -> void:
	# The rotation envelope stays within the pocket, behind the corridor wall face.
	var names := [&"StarMi", &"StarRe", &"StarDo"]
	var tints := [Color("a0c3ff"), Color("ffe4a3"), Color("d1a8ff")]
	var toward_walkway := Basis(Vector3.UP, -PI / 2.0)
	for index in mini(spec.niches.size(), STAR_MODELS.size()):
		var star := NicheStar.new()
		star.name = names[index]
		star.position = Vector3((NICHE_FRONT + NICHE_BACK) * 0.5, 0.21, float(spec.niches[index]))
		corridor.add_child(star)
		var facing := toward_walkway * Basis(Vector3.RIGHT, PI / 2.0) if index == 1 else toward_walkway
		star.install(STAR_MODELS[index], STAR_CHIMES[STAR_CHIMES.size() - 1 - index], tints[index], facing, actor)

static func build(parent: Node3D,spec: Dictionary) -> PackedVector3Array:
	var corridor := Node3D.new()
	corridor.name = "SunkenCorridor"
	parent.add_child(corridor)
	var faces := PackedVector3Array()
	var floor_mat := Geometry.material(Color("c3c8c7"))
	var trim := Geometry.material(Color("a5afab"))
	var stone := Geometry.material(Geometry.WALL_GREY)
	var rect: Array = spec.rect
	for section: Dictionary in spec.sections:
		var a := Vector3(rect[0],section.heights[0],section.z[0])
		var b := Vector3(rect[1],section.heights[0],section.z[0])
		var c := Vector3(rect[1],section.heights[1],section.z[1])
		var d := Vector3(rect[0],section.heights[1],section.z[1])
		var local_faces := PackedVector3Array([a,c,b,a,d,c])
		faces.append_array(local_faces)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p: Vector3 in local_faces:
			st.add_vertex(p)
		st.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name = section.id
		mesh.mesh = st.commit()
		mesh.material_override = floor_mat
		corridor.add_child(mesh)
		# Narrow paving bands are visual, raised 1cm rather than coplanar overlays.
		for x: float in [2.64,4.50]:
			var band := SurfaceTool.new()
			band.begin(Mesh.PRIMITIVE_TRIANGLES)
			var points := [Vector3(x,float(section.heights[0])+0.01,section.z[0]),Vector3(x+0.06,float(section.heights[0])+0.01,section.z[0]),Vector3(x+0.06,float(section.heights[1])+0.01,section.z[1]),Vector3(x,float(section.heights[1])+0.01,section.z[1])]
			for index: int in [0,2,1,0,3,2]:
				band.add_vertex(points[index])
			band.generate_normals()
			var stripe := MeshInstance3D.new()
			stripe.mesh = band.commit()
			stripe.material_override = trim
			corridor.add_child(stripe)
	var cursor := float(rect[2])
	for index in spec.niches.size():
		var z := float(spec.niches[index])
		_east_panel(corridor,"WallSegment_H6_Panel%d"%index,cursor,z-NICHE_OUTER_HALF_WIDTH,float(spec.foundation),float(spec.wall_top),stone)
		_build_niche(corridor,z,index,float(spec.foundation),float(spec.wall_top),stone,trim)
		cursor = z+NICHE_OUTER_HALF_WIDTH
	_east_panel(corridor,"WallSegment_H6_PanelEnd",cursor,float(rect[3]),float(spec.foundation),float(spec.wall_top),stone)
	var anchor := Marker3D.new()
	anchor.name = spec.reserved_anchor.id
	var p: Array = spec.reserved_anchor.position
	anchor.position = Vector3(p[0],p[1],p[2])
	corridor.add_child(anchor)
	var label := Geometry.label(corridor,"H6 · 下沉石廊 −0.6m",Vector3(3.6,1.9,21.6),34)
	label.name = "InspectionLabel"
	return faces

static func _east_panel(parent: Node3D,id: String,z0: float,z1: float,bottom: float,top: float,mat: Material) -> void:
	Geometry.box(parent,id,Vector3(0.3,top-bottom,z1-z0),Vector3(4.8,(bottom+top)/2,(z0+z1)/2),mat)

static func _build_niche(parent: Node3D,z: float,index: int,bottom: float,top: float,stone: Material,trim: Material) -> void:
	var niche := Node3D.new()
	niche.name = "Niche%d"%(index+1)
	niche.set_meta("occlusion_group",true)
	parent.add_child(niche)
	var sill := -0.4
	var spring := 0.4
	var pocket_depth := NICHE_BACK - NICHE_FRONT
	var pocket_middle := (NICHE_FRONT + NICHE_BACK) * 0.5
	var jamb_width := NICHE_OUTER_HALF_WIDTH - NICHE_INNER_HALF_WIDTH
	Geometry.box(niche,"WallSegment_H6_NicheBack",Vector3(NICHE_OUTER_BACK-NICHE_BACK,top-bottom,NICHE_OUTER_HALF_WIDTH*2),Vector3((NICHE_OUTER_BACK+NICHE_BACK)*0.5,(top+bottom)/2,z),stone)
	Geometry.box(niche,"WallSegment_H6_NicheBase",Vector3(pocket_depth,sill-bottom,NICHE_OUTER_HALF_WIDTH*2),Vector3(pocket_middle,(bottom+sill)/2,z),stone)
	for side: float in [-1,1]:
		Geometry.box(niche,"WallSegment_H6_NicheJamb",Vector3(pocket_depth,spring-sill,jamb_width),Vector3(pocket_middle,(spring+sill)/2,z+side*(NICHE_INNER_HALF_WIDTH+jamb_width*0.5)),trim)
	for step in 12:
		var a := PI*step/12
		var b := PI*(step+1)/12
		var ring := PackedVector2Array([Vector2(z+cos(a)*NICHE_OUTER_HALF_WIDTH,spring+sin(a)*NICHE_OUTER_HALF_WIDTH),Vector2(z+cos(b)*NICHE_OUTER_HALF_WIDTH,spring+sin(b)*NICHE_OUTER_HALF_WIDTH),Vector2(z+cos(b)*NICHE_INNER_HALF_WIDTH,spring+sin(b)*NICHE_INNER_HALF_WIDTH),Vector2(z+cos(a)*NICHE_INNER_HALF_WIDTH,spring+sin(a)*NICHE_INNER_HALF_WIDTH)])
		Geometry.extruded_section(niche,"WallSegment_H6_NicheArch",ring,NICHE_FRONT,NICHE_BACK,trim)
		var fill := PackedVector2Array([ring[0],ring[1],Vector2(ring[1].x,top),Vector2(ring[0].x,top)])
		Geometry.extruded_section(niche,"WallSegment_H6_NicheAbove",fill,NICHE_FRONT,NICHE_BACK,stone)
