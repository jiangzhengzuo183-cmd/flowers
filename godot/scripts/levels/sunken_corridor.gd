extends RefCounted
## H6 is independent of raised surfaces: negative floor heights must not max with zero.
const Geometry := preload("res://scripts/levels/greybox_geometry.gd")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")

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
		_east_panel(corridor,"WallSegment_H6_Panel%d"%index,cursor,z-0.48,float(spec.foundation),float(spec.wall_top),stone)
		_build_niche(corridor,z,index,float(spec.foundation),float(spec.wall_top),stone,trim)
		cursor = z+0.48
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
	Geometry.box(niche,"WallSegment_H6_NicheBack",Vector3(0.2,top-bottom,0.96),Vector3(4.85,(top+bottom)/2,z),stone)
	Geometry.box(niche,"WallSegment_H6_NicheBase",Vector3(0.1,sill-bottom,0.96),Vector3(4.7,(bottom+sill)/2,z),stone)
	for side: float in [-1,1]:
		Geometry.box(niche,"WallSegment_H6_NicheJamb",Vector3(0.1,spring-sill,0.08),Vector3(4.7,(spring+sill)/2,z+side*0.44),trim)
	for step in 12:
		var a := PI*step/12
		var b := PI*(step+1)/12
		var ring := PackedVector2Array([Vector2(z+cos(a)*0.48,spring+sin(a)*0.48),Vector2(z+cos(b)*0.48,spring+sin(b)*0.48),Vector2(z+cos(b)*0.4,spring+sin(b)*0.4),Vector2(z+cos(a)*0.4,spring+sin(a)*0.4)])
		Geometry.extruded_section(niche,"WallSegment_H6_NicheArch",ring,4.65,4.75,trim)
		var fill := PackedVector2Array([ring[0],ring[1],Vector2(ring[1].x,top),Vector2(ring[0].x,top)])
		Geometry.extruded_section(niche,"WallSegment_H6_NicheAbove",fill,4.65,4.75,stone)
