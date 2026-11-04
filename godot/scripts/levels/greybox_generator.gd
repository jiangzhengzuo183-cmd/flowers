extends "res://scripts/maze/maze_generator.gd"

const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const Geometry := preload("res://scripts/levels/greybox_geometry.gd")
const GateScene := preload("res://scenes/levels/greybox_gate.tscn")
const SwitchScene := preload("res://scenes/levels/greybox_switch.tscn")
const RoundHall := preload("res://scripts/levels/round_hall.gd")
const WallPlan := preload("res://scripts/levels/wall_plan.gd")
const SunkenCorridor := preload("res://scripts/levels/sunken_corridor.gd")
const ArchedUnderpass := preload("res://scripts/levels/arched_underpass.gd")
var gates: Dictionary = {}
var switches: Dictionary = {}
var surfaces: Array = []
var architecture: Node3D
var rail_count := 0
var floor_faces := PackedVector3Array()
var round_hall: Node3D
var high_wall_count := 0
var rail_edges: Array[Dictionary] = []
var removed_rail_wall_count := 0

func build(original: Dictionary) -> void:
	super(Layout.patched_map(original))
	floor_material.albedo_color = Color("c3c8c7")
	wall_material.albedo_color = Geometry.WALL_GREY
	architecture = Node3D.new()
	architecture.name = "LevelArchitecture"
	add_child(architecture)
	_replace_ground_floor()
	_build_courtyard()
	floor_faces.append_array(SunkenCorridor.build(architecture,Layout.config().sunken_corridor))
	round_hall = RoundHall.build(architecture,Layout.config().building)
	surfaces = Layout.config().surfaces
	for surface: Dictionary in surfaces:
		_build_surface(surface)
	for surface: Dictionary in surfaces:
		_build_boundary_rails(surface)
	_relieve_rail_walls()
	var floor_body := StaticBody3D.new()
	floor_body.name = "RaisedSurfaceCollision"
	architecture.add_child(floor_body)
	var floor_shape := ConcavePolygonShape3D.new()
	floor_shape.backface_collision = true
	floor_shape.set_faces(floor_faces)
	var floor_collider := CollisionShape3D.new()
	floor_collider.shape = floor_shape
	floor_body.add_child(floor_collider)
	var structure_mat := Geometry.material(Color("8b9696"))
	for opening: Dictionary in Layout.config().arches:
		_build_arch(opening,structure_mat)
	for spec: Dictionary in Layout.config().doors:
		var gate = GateScene.instantiate()
		gate.name = spec.id
		gate.gate_id = spec.id
		_place_portal(gate,spec.edge)
		gate.position.y = float(spec.get("floor",0.0))
		architecture.add_child(gate)
		gates[spec.id] = gate
		var button = SwitchScene.instantiate()
		button.name = str(spec.id).replace("D","S")
		button.gate_id = spec.id
		var p: Array = spec.switch_position
		button.position = Vector3(p[0],p[1],p[2])
		architecture.add_child(button)
		switches[spec.id] = button
	# At the crossing, ground movement is E/W only; the bridge remains N/S.
	ArchedUnderpass.build(architecture,Layout.config().bridge_vault)
	Geometry.label(architecture,"H1 · 抬高通路 +1.2m",Vector3(14.4,2.2,44.4),36)
	Geometry.label(architecture,"H2 · 过街桥 +2.6m",Vector3(39.6,3.7,15.6),38)
	var underpass_label := Geometry.label(architecture,"桥下通道",Vector3(37.2,1.8,15.6),34)
	underpass_label.name = "UnderpassInspectionLabel"
	Geometry.label(architecture,"H3 · 东庭短高台 +0.6m",Vector3(37.2,1.6,30.6),32)
	Geometry.label(architecture,"H4 · 南露台 +1.2m",Vector3(24,2.3,30.6),32)
	# Layer 1 blocks Charlie; layer 3 is reserved for camera obstruction by
	# actual architecture, rather than the full-height invisible cutaway walls.
	for body: StaticBody3D in architecture.find_children("*","StaticBody3D",true,false):
		body.collision_layer = 5
	_rebuild_route_lines(original)

func _replace_ground_floor() -> void:
	# Remove only the inherited runtime floor, then rebuild around the real
	# courtyard hole. No original scene, data, or source asset is rewritten.
	get_node("FloorCollision").free()
	for child: Node in get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.x>45:
			child.free()
			break
	var plans: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-0.7,-0.7),Vector2(46.3,-0.7),Vector2(46.3,46.3),Vector2(-0.7,46.3)])]
	for r: Array in [[0.0,9.6,4.8,14.4],Layout.config().sunken_corridor.rect]:
		var hole := PackedVector2Array([Vector2(r[0],r[2]),Vector2(r[1],r[2]),Vector2(r[1],r[3]),Vector2(r[0],r[3])])
		var next: Array[PackedVector2Array] = []
		for plan: PackedVector2Array in plans:
			next.append_array(WallPlan.subtract(plan,hole))
		plans = next
	for plan: PackedVector2Array in plans:
		# Both holes are rectangular. Retain the original BoxMesh floor shading.
		var bounds := Rect2(plan[0],Vector2.ZERO)
		for p: Vector2 in plan:
			bounds = bounds.expand(p)
		Geometry.box(architecture,"GroundSlab",Vector3(bounds.size.x,0.25,bounds.size.y),Vector3(bounds.get_center().x,-0.125,bounds.get_center().y),floor_material)

func _build_courtyard() -> void:
	var garden := Node3D.new()
	garden.name = "NorthwestCourtyard"
	architecture.add_child(garden)
	var index := 0
	for faces: PackedVector3Array in Layout.courtyard_faces:
		var r := 2+index/4
		var c := index%4
		var height := float(Layout.config().northwest.levels[r-2][c])
		var color := Color("899e9c") if height<0 else (Color("aaa899") if height>0 else Color("b5bdb7"))
		var mesh := ArrayMesh.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex: Vector3 in faces:
			st.add_vertex(vertex)
		st.generate_normals()
		mesh = st.commit()
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = Geometry.material(color)
		garden.add_child(visual)
		floor_faces.append_array(faces)
		index += 1
	var stone := Geometry.material(Color("7a8682"))
	var rail_material := Geometry.material(Geometry.WALL_GREY)
	for transition: Dictionary in Layout.config().northwest.transitions:
		var a := Layout.cell_point(transition.a)
		var b := Layout.cell_point(transition.b)
		var along_x := absf(b.x-a.x)>0.1
		var count := ceili(absf(float(transition.heights[1])-float(transition.heights[0]))/0.12)
		for step in count:
			var t := (0.5+1.4*(step+0.5)/count)/2.4
			var p := a.lerp(b,t)
			p.y = Layout.height_at(Vector2(p.x,p.z))+0.014
			var size := Vector3(1.4/count*0.9,0.028,1.8) if along_x else Vector3(1.8,0.028,1.4/count*0.9)
			Geometry.box(garden,"CourtyardTread",size,p,Geometry.material(Color("bdc2b9")),false)
	# The old non-passable wall becomes an actual framed observation window.
	for x in [0.16,2.24]:
		Geometry.box(garden,"WindowPier",Vector3(0.32,3.0,0.32),Vector3(x,0.9,9.6),stone)
	Geometry.box(garden,"WindowSill",Vector3(1.76,1.4,0.32),Vector3(1.2,-0.1,9.6),stone)
	Geometry.box(garden,"WindowHeader",Vector3(1.76,0.6,0.32),Vector3(1.2,2.1,9.6),stone)
	for x in [0.7,1.2,1.7]:
		Geometry.box(garden,"WindowBar",Vector3(0.045,1.2,0.10),Vector3(x,1.2,9.6),stone)
	# The two low/high interfaces remain blocked. The retaining wall top is
	# 0.95m above the upper +0.9m gallery; the opening is never a 1.5m step.
	for z in [10.8,13.2]:
		Geometry.box(garden,"RetainingWall",Vector3(0.30,1.55,2.4),Vector3(4.8,0.125,z),stone)
		for rail_y in [1.05,1.82]:
			Geometry.box(garden,"GalleryBalustrade",Vector3(0.12,0.08,2.4),Vector3(4.8,rail_y,z),rail_material)
		for offset in [-0.9,-0.45,0.0,0.45,0.9]:
			Geometry.box(garden,"GalleryBaluster",Vector3(0.08,0.86,0.08),Vector3(4.8,1.4,z+offset),rail_material)
	# Centre of the lower loop: preserve both 1.8m circulation strips.
	Geometry.box(garden,"DryFlowerbed",Vector3(1.0,0.28,1.0),Vector3(2.4,-0.46,12.0),Geometry.material(Color("747f70")))
	for anchor: Dictionary in Layout.config().northwest.reservedAnchors:
		var point := Layout.cell_point(anchor.cell)
		point.y = Layout.height_at(Vector2(point.x,point.z))+0.03
		Geometry.box(garden,str(anchor.id)+"_Reserved",Vector3(0.32,0.02,0.32),point,Geometry.material(Color("7d9294")),false)
	Geometry.label(garden,"H5 · 下沉花庭 −0.6m / 回廊 +0.9m",Vector3(4.8,3.9,10.8),36)

func _wall_height(r: int,c: int,vertical: bool) -> float:
	var row := float(r)+(.5 if vertical else 0.0)
	var col := float(c)+(0.0 if vertical else .5)
	var height := float(Layout.config().base_wall_height)
	for zone: Dictionary in Layout.config().low_zones:
		var a: Array = zone.rect
		if row>=float(a[0]) and row<=float(a[2])+1 and col>=float(a[1]) and col<=float(a[3])+1:
			height = float(zone.height)
	# Retain the old lot boundary as a low courtyard enclosure; the actual
	# circular hall/porches provide the high indoor walls and embedded arches.
	if row>=8 and row<=11 and col>=8 and col<=12:
		height = 1.1
	# Explicit connected arch clusters extend around corners. Their outer
	# route-facing ends step down to medium walls; routes between clusters stay low.
	for extension: Dictionary in Layout.config().arch_wall_extensions:
		if extension.axis==("v" if vertical else "h") and int(extension.row)==r and int(extension.col)==c:
			height = maxf(height,float(extension.height))
	for extension: Dictionary in Layout.config().central_wall_extensions:
		if extension.axis==("v" if vertical else "h") and int(extension.row)==r and int(extension.col)==c:
			height = maxf(height,float(extension.height))
	return height

func _build_walls(matrix: Array,vertical: bool,size: float,mat: StandardMaterial3D,body: StaticBody3D) -> void:
	body.collision_layer = 1
	var group := Node3D.new()
	group.name = "VerticalWalls" if vertical else "HorizontalWalls"
	add_child(group)
	for r in matrix.size():
		for c in matrix[r].size():
			if not matrix[r][c]:
				continue
			wall_count += 1
			# The repaired full-height porch wall replaces this old low board.
			if not vertical and r==8 and c==10:
				continue
			if (not vertical and r==4 and c==0) or (vertical and c==2 and r in [4,5]):
				continue
			if vertical and c==2 and r>=6 and r<=11:
				continue # H6's wall contains real recessed niches, with its own collision.
			var x := (float(c)+(0.0 if vertical else .5))*size
			var z := (float(r)+(.5 if vertical else 0.0))*size
			var floor_y := maxf(Layout.height_at(Vector2(x+(0.3 if vertical else 0.0),z+(0.0 if vertical else 0.3))),Layout.height_at(Vector2(x-(0.3 if vertical else 0.0),z-(0.0 if vertical else 0.3))))
			var bottom := -0.85 if x<=9.61 and z>=4.79 and z<=14.41 else -0.05
			if vertical and c==1 and r>=6 and r<=11:
				bottom = -0.85
			var height := _wall_height(r,c,vertical)
			high_wall_count += 1 if height>=3.0 else 0
			var top := floor_y+height
			var dimensions := Vector3(0.3 if vertical else size+0.3,top-bottom,size+0.3 if vertical else 0.3)
			var center := Vector3(x,(top+bottom)/2,z)
			# Independent wall segments allow only the ray-hit wall to blend.
			var segment := Geometry.box(group,"WallSegment_%s_%d_%d"%["V" if vertical else "H",r,c],dimensions,center,mat)
			segment.collision_layer = 1

func _place_portal(portal: Node3D, edge: Array) -> void:
	portal.position = (Layout.cell_point(edge[0])+Layout.cell_point(edge[1]))/2
	portal.rotation.y = PI/2 if edge[0][0] == edge[1][0] else 0.0

func _build_arch(spec: Dictionary, mat: Material) -> void:
	var portal := Node3D.new()
	portal.name = spec.id
	_place_portal(portal,spec.edge)
	architecture.add_child(portal)
	var church := str(spec.id) in ["G6","G7","G8"]
	if church:
		mat = Geometry.material(RoundHall.WALL_CREAM)
	var height := float(Layout.config().building.eave) if church else 3.4
	var spring := 2.1 if church else 1.6
	# The arc and upper infill complete the wall above the spring line;
	# full-height piers would overlap those faces and produce flickering stripes.
	Geometry.box(portal,"LeftPier",Vector3(0.3,spring,0.4),Vector3(-1.05,spring/2,0),mat)
	Geometry.box(portal,"RightPier",Vector3(0.3,spring,0.4),Vector3(1.05,spring/2,0),mat)
	for i in 12:
		var a := PI*i/12
		var b := PI*(i+1)/12
		var points := PackedVector3Array()
		for z in [-0.2,0.2]:
			points.append(Vector3(cos(a)*1.2,spring+sin(a)*1.2,z))
			points.append(Vector3(cos(b)*1.2,spring+sin(b)*1.2,z))
			points.append(Vector3(cos(b)*0.9,spring+sin(b)*0.9,z))
			points.append(Vector3(cos(a)*0.9,spring+sin(a)*0.9,z))
		Geometry.prism(portal,"ArchStone%d"%i,points,mat,church)
		var infill := PackedVector3Array()
		for z in [-0.2,0.2]:
			infill.append(Vector3(cos(a)*1.2,spring+sin(a)*1.2,z))
			infill.append(Vector3(cos(b)*1.2,spring+sin(b)*1.2,z))
			infill.append(Vector3(cos(b)*1.2,height,z))
			infill.append(Vector3(cos(a)*1.2,height,z))
		Geometry.prism(portal,"WallAboveArch%d"%i,infill,mat,church)
	Geometry.label(portal,str(spec.id),Vector3(0,height+0.15,0),36)

func _surface_vertices(surface: Dictionary, thickness: float, solid: bool) -> PackedVector3Array:
	var r: Array = surface.rect
	var points := [Vector2(r[0],r[2]),Vector2(r[1],r[2]),Vector2(r[1],r[3]),Vector2(r[0],r[3])]
	var result := PackedVector3Array()
	for p: Vector2 in points:
		result.append(Vector3(p.x,Layout.surface_height(surface,p),p.y))
	for p: Vector2 in points:
		result.append(Vector3(p.x,-0.2 if solid else Layout.surface_height(surface,p)-thickness,p.y))
	return result

func _build_surface(surface: Dictionary) -> void:
	var mat := Geometry.material(Color("98a3a2") if str(surface.id).begins_with("H1") else Color("879695"))
	var vertices := _surface_vertices(surface,0.2,surface.solid)
	var visual_body := Geometry.prism(architecture,str(surface.id),vertices,mat)
	# A single connected static triangle surface avoids convex side faces at
	# adjacent ramp/landing seams catching the capsule before its foot rises.
	(visual_body.get_child(0) as CollisionShape3D).disabled = true
	_append_quad(vertices[0],vertices[1],vertices[2],vertices[3])
	_append_quad(vertices[4],vertices[7],vertices[6],vertices[5])
	# Tread plates are visual only. The continuous matching slope carries the capsule.
	var rise := absf(float(surface.heights[1])-float(surface.heights[0]))
	if rise < 0.05:
		return
	var r: Array = surface.rect
	var count := ceili(rise/0.12)
	var tread_mat := Geometry.material(Color("aab3b2"))
	for i in count:
		var t := (i+0.5)/count
		var x := lerpf(r[0],r[1],t) if surface.axis == "x" else (float(r[0])+float(r[1]))/2
		var z := lerpf(r[2],r[3],t) if surface.axis == "z" else (float(r[2])+float(r[3]))/2
		var span := (float(r[1])-float(r[0]))/count if surface.axis == "x" else (float(r[3])-float(r[2]))/count
		var size := Vector3(span*0.9,0.035,float(r[3])-float(r[2])) if surface.axis == "x" else Vector3(float(r[1])-float(r[0]),0.035,span*0.9)
		Geometry.box(architecture,"Tread",size,Vector3(x,Layout.surface_height(surface,Vector2(x,z))+0.018,z),tread_mat,false)

func _append_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	floor_faces.append_array(PackedVector3Array([a,c,b,a,d,c]))

func _build_boundary_rails(surface: Dictionary) -> void:
	var r: Array = surface.rect
	var corners := [Vector2(r[0],r[2]),Vector2(r[1],r[2]),Vector2(r[1],r[3]),Vector2(r[0],r[3])]
	for index in 4:
		var a: Vector2 = corners[index]
		var b: Vector2 = corners[(index+1)%4]
		var outward := Vector2(0,-1) if index == 0 else (Vector2(1,0) if index == 1 else (Vector2(0,1) if index == 2 else Vector2(-1,0)))
		var cuts: Array[float] = [0.0,1.0]
		for other: Dictionary in surfaces:
			for n in 4:
				var value := float(other.rect[n])
				if (index%2 == 0 and n < 2) or (index%2 == 1 and n >= 2):
					var t := (value-a.x)/(b.x-a.x) if index%2 == 0 else (value-a.y)/(b.y-a.y)
					if t>0.001 and t<0.999 and not cuts.has(t):
						cuts.append(t)
		cuts.sort()
		for i in range(1,cuts.size()):
			var start := a.lerp(b,cuts[i-1])
			var end := a.lerp(b,cuts[i])
			var mid := (start+end)/2
			var y := Layout.surface_height(surface,mid)
			var internal := false
			for other: Dictionary in surfaces:
				if other.id != surface.id and Layout.contains(other,mid+outward*0.02,0.0) and absf(Layout.surface_height(other,mid)-y)<0.02:
					internal = true
			if internal:
				continue
			var ya := Layout.surface_height(surface,start)
			var yb := Layout.surface_height(surface,end)
			_append_quad(Vector3(start.x,ya,start.y),Vector3(end.x,yb,end.y),Vector3(end.x,-0.2 if surface.solid else yb-0.2,end.y),Vector3(start.x,-0.2 if surface.solid else ya-0.2,start.y))
			if ya<0.02 and yb<0.02:
				continue
			var across := outward*0.055
			var points := PackedVector3Array()
			for extra_y in [0.92,0.02]:
				for p: Vector2 in [start-across,end-across,end+across,start+across]:
					points.append(Vector3(p.x,Layout.surface_height(surface,p)+extra_y,p.y))
			Geometry.prism(architecture,"GuardRail%d"%rail_count,points,Geometry.material(Geometry.WALL_GREY))
			rail_edges.append({"a":start,"b":end,"surface":surface.id})
			rail_count += 1

func _relieve_rail_walls() -> void:
	# The platform side collision plus its guard replaces the parallel grid
	# wall only over the guarded interval. End stubs and tunnel barriers stay.
	for group_name: String in ["VerticalWalls","HorizontalWalls"]:
		var group := get_node(group_name)
		for body: StaticBody3D in group.get_children():
			var parts := str(body.name).split("_")
			var vertical := parts[1]=="V"
			var visual := body.get_child(0) as MeshInstance3D
			var size := (visual.mesh as BoxMesh).size
			var center := body.position
			var side := center.x if vertical else center.z
			var along := center.z if vertical else center.x
			var length := size.z if vertical else size.x
			var start := along-length/2
			var end := along+length/2
			var cuts: Array[Vector2] = []
			for rail: Dictionary in rail_edges:
				var a: Vector2 = rail.a
				var b: Vector2 = rail.b
				if (vertical and absf(a.x-b.x)>0.001) or (not vertical and absf(a.y-b.y)>0.001):
					continue
				if absf(side-(a.x if vertical else a.y))>0.45:
					continue
				var lo := maxf(start,minf(a.y,b.y) if vertical else minf(a.x,b.x))
				var hi := minf(end,maxf(a.y,b.y) if vertical else maxf(a.x,b.x))
				if hi-lo>0.03:
					cuts.append(Vector2(lo,hi))
			if cuts.is_empty():
				continue
			cuts.sort_custom(func(a: Vector2,b: Vector2): return a.x<b.x)
			var merged: Array[Vector2] = []
			for cut: Vector2 in cuts:
				if not merged.is_empty() and cut.x<=merged[-1].y+0.02:
					merged[-1].y = maxf(merged[-1].y,cut.y)
				else:
					merged.append(cut)
			var remains: Array[Vector2] = []
			var cursor := start
			for cut: Vector2 in merged:
				if cut.x-cursor>0.08:
					remains.append(Vector2(cursor,cut.x))
				cursor = maxf(cursor,cut.y)
			if end-cursor>0.08:
				remains.append(Vector2(cursor,end))
			for i in remains.size():
				var span := remains[i]
				var dimensions := size
				var position := center
				if vertical:
					dimensions.z = span.y-span.x
					position.z = (span.x+span.y)/2
				else:
					dimensions.x = span.y-span.x
					position.x = (span.x+span.y)/2
				# Re-evaluate each end piece at its own landing height. Keeping
				# the old panel height would leave tall isolated boards beside rails.
				var across := Vector2(0.3,0) if vertical else Vector2(0,0.3)
				var plan_position := Vector2(position.x,position.z)
				var landing := maxf(Layout.height_at(plan_position+across),Layout.height_at(plan_position-across))
				var bottom := center.y-size.y/2
				var top := landing+1.05
				dimensions.y = top-bottom
				position.y = (top+bottom)/2
				var piece := Geometry.box(group,str(body.name)+"_Trim%d"%i,dimensions,position,wall_material)
				piece.collision_layer = 1
			removed_rail_wall_count += 1
			body.free()

func _rebuild_route_lines(original: Dictionary) -> void:
	for id: String in ["A","B"]:
		var group: Node3D = route_nodes[id]
		for child: Node in group.get_children():
			group.remove_child(child)
			child.queue_free()
		var immediate := ImmediateMesh.new()
		var mat := _material(Color(original.routes[id].color),true)
		immediate.surface_begin(Mesh.PRIMITIVE_LINES,mat)
		var path: Array = original.routes[id].cellPath
		for i in range(1,path.size()):
			var a := Layout.cell_point(path[i-1])
			var b := Layout.cell_point(path[i])
			for step in 12:
				for t in [step/12.0,(step+1)/12.0]:
					var p := a.lerp(b,t)
					p.y = Layout.height_at(Vector2(p.x,p.z))+0.06
					immediate.surface_add_vertex(p)
		immediate.surface_end()
		var instance := MeshInstance3D.new()
		instance.mesh = immediate
		group.add_child(instance)

func set_walk_cutaway(enabled: bool) -> void:
	# Heights and collisions now agree. The follow camera handles obstruction.
	for pin: MeshInstance3D in marker_pins:
		pin.visible = not enabled
	if is_instance_valid(architecture) and architecture.has_node("SunkenCorridor/InspectionLabel"):
		architecture.get_node("SunkenCorridor/InspectionLabel").visible = not enabled
	if is_instance_valid(architecture) and architecture.has_node("UnderpassInspectionLabel"):
		architecture.get_node("UnderpassInspectionLabel").visible = not enabled
	if is_instance_valid(round_hall):
		round_hall.get_node("Roof").visible = enabled

func update_room_view(_point: Vector3,_walking: bool,top_down: bool = false) -> void:
	if is_instance_valid(round_hall):
		round_hall.get_node("Roof").visible = not top_down

func reset_mechanisms() -> void:
	for id: String in gates:
		gates[id].reset_gate()
		switches[id].set_used(false)
