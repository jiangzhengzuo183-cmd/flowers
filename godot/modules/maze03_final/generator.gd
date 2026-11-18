extends "res://scripts/levels/greybox_generator.gd"
const Temple := preload("res://modules/maze03_final/sanctuary.gd")
const Courtyard := preload("res://modules/maze03_final/courtyard.gd")
const Barrier := preload("res://modules/maze03_final/barrier.gd")
const SHORTCUTS := [["v",14,12],["h",5,14],["v",2,4]]
const ENTRY_REMOVED_WALLS := ["WallSegment_H_19_0","WallSegment_H_19_1"]
const EXTRA_BARRIERS := [
	{"id":"B5","edge":[[2,6],[2,7]]},
	{"id":"B6","edge":[[2,9],[2,10]]},
]
var northwest_removed_wall_count := 0
var barriers: Array[Area3D] = []
var sanctuary: Node3D
var removed_walls := 0
var shortcut_count := 0
var removed_south_bridge := 0

func build(original: Dictionary) -> void:
	replaced_switches = {"D1":true, "D2":true, "D3":true, "D4":true}
	super(original)

func remodel() -> void:
	for id: String in ["CentralRoundHall", "G6", "G7", "G8"]:
		var old := architecture.get_node_or_null(id)
		if old != null:
			old.free()
	get_node("EarthBearer").free()
	var floor := load("res://art/maze01/materials/floor_limestone.tres").duplicate() as StandardMaterial3D
	floor.albedo_color = Color("c9c8c0")
	floor.normal_scale = 0.12
	_restore_sunken_areas(floor)
	_rebuild_courtyard(floor)
	# Cut around the retained lower levels and the centered mirror basin.
	for child in architecture.get_children():
		if child is StaticBody3D and child.get_children().any(func(n): return n is MeshInstance3D and n.get_meta("greybox_part","") == "GroundSlab"):
			child.free()
	var plans: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-0.7,-0.7),Vector2(46.3,-0.7),Vector2(46.3,46.3),Vector2(-0.7,46.3)])]
	var corridor: Array = Layout.config().sunken_corridor.rect
	var holes := [Rect2(0,4.8,9.6,9.6), Rect2(corridor[0],corridor[2],corridor[1]-corridor[0],corridor[3]-corridor[2]), Temple.POOL]
	for hole: Rect2 in holes:
		var mask := PackedVector2Array([hole.position,Vector2(hole.end.x,hole.position.y),hole.end,Vector2(hole.position.x,hole.end.y)])
		var next: Array[PackedVector2Array] = []
		for plan in plans:
			next.append_array(WallPlan.subtract(plan,mask))
		plans = next
	for plan in plans:
		var bounds := Rect2(plan[0],Vector2.ZERO)
		for point in plan:
			bounds = bounds.expand(point)
		Geometry.box(architecture, "FinishedStoneFloor", Vector3(bounds.size.x,0.25,bounds.size.y), Vector3(bounds.get_center().x,-0.125,bounds.get_center().y), floor)
	# Strip only the southern H4 bridge, its treads and its rails.
	for child in architecture.get_children():
		if not child is Node3D:
			continue
		var point: Vector3 = child.position
		var part := str(child.name)
		var visuals := child.find_children("*", "MeshInstance3D", false, false)
		if not visuals.is_empty():
			var visual := visuals[0] as MeshInstance3D
			point = architecture.to_local(visual.to_global(visual.get_aabb().get_center()))
			part = str(visual.get_meta("greybox_part",child.name))
		if str(child.name).begins_with("H4_"):
			child.free()
			removed_south_bridge += 1
			continue
		if part.begins_with("GuardRail") or part == "Tread":
			if point.x > 20.6 and point.x < 26.4 and point.z > 27.4 and point.z < 31.2:
				child.free()
	# The inherited raised-surface collision includes the bridge, so filter its H4 faces too.
	var retained := PackedVector3Array()
	for i in range(0, floor_faces.size(), 3):
		var center := (floor_faces[i] + floor_faces[i+1] + floor_faces[i+2]) / 3.0
		if center.x > 20.6 and center.x < 26.4 and center.z > 27.4 and center.z < 31.2:
			continue
		retained.append_array(floor_faces.slice(i,i+3))
	var collider := architecture.get_node("RaisedSurfaceCollision").get_child(0) as CollisionShape3D
	(collider.shape as ConcavePolygonShape3D).set_faces(retained)
	# Reframe the established door openings, with no retained leaf or unlocking component.
	for id: String in gates:
		var gate: Node3D = gates[id]
		_add_energy_frame(id,gate.transform)
		gate.free()
	gates.clear()
	# Two added thresholds lie on the B branch, not on the shared route or the pool.
	for spec: Dictionary in EXTRA_BARRIERS:
		var a := Layout.cell_point(spec.edge[0])
		var b := Layout.cell_point(spec.edge[1])
		var center := (a+b)*0.5
		center.y = Layout.height_at(Vector2(center.x,center.z))
		var rotation_y := PI*0.5 if absf(b.x-a.x)>0.5 else 0.0
		_add_energy_frame(spec.id,Transform3D(Basis(Vector3.UP,rotation_y),center))
	for group_name in ["VerticalWalls","HorizontalWalls"]:
		for wall: Node3D in get_node(group_name).get_children():
			var inside := Temple.POOL.grow(0.01).has_point(Vector2(wall.position.x,wall.position.z))
			# A consistent dry strip separates all remaining walls from the pool.
			var visual := wall.get_child(0) as MeshInstance3D
			var bounds := visual.get_aabb()
			var a: Vector3 = visual.to_global(bounds.position)
			var b: Vector3 = visual.to_global(bounds.end)
			var footprint := Rect2(Vector2(minf(a.x,b.x),minf(a.z,b.z)),Vector2(absf(a.x-b.x),absf(a.z-b.z)))
			var shore_clearance := footprint.intersects(Temple.POOL.grow(0.75))
			var short := false
			for spec in SHORTCUTS:
				if str(wall.name) == "WallSegment_%s_%d_%d" % [str(spec[0]).to_upper(),spec[1],spec[2]]:
					short = true
			var west_door := str(wall.name) == "WallSegment_V_9_8"
			if short:
				shortcut_count += 1
			var east_bank: bool = group_name == "HorizontalWalls" and wall.position.x > Temple.POOL.end.x and wall.position.x < Temple.POOL.end.x+1.3 and wall.position.z >= Temple.POOL.position.y and wall.position.z <= Temple.POOL.end.y
			var canopy_interior := Courtyard.AREA.grow(0.002).has_point(Vector2(wall.position.x,wall.position.z)) and wall.position.x>0.2
			if canopy_interior:
				northwest_removed_wall_count += 1
			if inside or short or west_door or east_bank or canopy_interior or shore_clearance or str(wall.name) in ENTRY_REMOVED_WALLS:
				wall.free()
				removed_walls += 1
	var connection_count := _extend_pool_dividers()
	var shoreline := preload("res://modules/maze03_final/pool_boundary.gd").build(architecture)
	shoreline.set_meta("corridor_connections",connection_count)
	_open_northwest_threshold()
	preload("res://modules/maze03_final/wall_joints.gd").repair(self)
	sanctuary = Temple.new()
	sanctuary.name = "FinalSanctuary"
	architecture.add_child(sanctuary)
	for mesh: MeshInstance3D in architecture.find_children("*","MeshInstance3D",true,false):
		if mesh.get_meta("greybox_part","") == "FinishedStoneFloor":
			mesh.layers = 4
	for body: StaticBody3D in architecture.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 5

func update_room_view(_point: Vector3, _walking: bool, _top: bool = false) -> void:
	pass

func refresh_reference_routes(data: Dictionary) -> void:
	for id: String in ["A","B"]:
		var group: Node3D = route_nodes[id]
		for child in group.get_children():
			child.free()
		var lines := ImmediateMesh.new()
		var material := _material(Color(data.routes[id].color),true)
		lines.surface_begin(Mesh.PRIMITIVE_LINES,material)
		var path: Array = data.routes[id].cellPath
		for i in range(1,path.size()):
			var a := Layout.cell_point(path[i-1])
			var b := Layout.cell_point(path[i])
			for step in 12:
				for t in [step/12.0,(step+1)/12.0]:
					var point := a.lerp(b,t)
					var level := Layout.height_at(Vector2(point.x,point.z))
					if Courtyard.AREA.has_point(Vector2(point.x,point.z)):
						level = Courtyard.height_at(Vector2(point.x,point.z))
					if Temple.POOL.has_point(Vector2(point.x,point.z)):
						level = 0.0
					point.y = level+0.065
					lines.surface_add_vertex(point)
		lines.surface_end()
		var visual := MeshInstance3D.new()
		visual.mesh = lines
		group.add_child(visual)
func _restore_sunken_areas(_floor: Material) -> void:
	var courtyard := architecture.get_node("NorthwestCourtyard")
	for id in ["WadingPoolSurface","PoolGoldfish","FloatingDuckweed"]:
		var effect := courtyard.get_node_or_null(id)
		if effect != null:
			effect.free()
	var corridor := architecture.get_node("SunkenCorridor")
	var wall := load("res://art/maze01/materials/plaster_cream.tres").duplicate() as StandardMaterial3D
	wall.albedo_color = Color("e9e9e5")
	var spec: Dictionary = Layout.config().sunken_corridor
	for child in corridor.get_children():
		if str(child.name).begins_with("Niche"):
			child.free()
	var z0 := float(spec.rect[2])
	var z1 := float(spec.rect[3])
	# Remove the segmented east wall before adding one uninterrupted wall face.
	for child in corridor.get_children():
		if child is Node3D and child.find_children("*","MeshInstance3D",true,false).any(func(n): return str(n.get_meta("greybox_part","")).begins_with("WallSegment_H6_Panel")):
			child.free()
	Geometry.box(corridor,"WallSegment_H6_Continuous",Vector3(0.30,float(spec.wall_top)-float(spec.foundation),z1-z0),Vector3(4.8,(float(spec.wall_top)+float(spec.foundation))*0.5,(z0+z1)*0.5),wall)
	# The floors, steps, balustrades and existing matching floor_faces stay in place.
	for mesh: MeshInstance3D in courtyard.find_children("*","MeshInstance3D",true,false):
		if mesh.get_meta("art_role","") == "water":
			mesh.hide()
func _rebuild_courtyard(material: Material) -> void:
	var retained := PackedVector3Array()
	for i in range(0,floor_faces.size(),3):
		var center := (floor_faces[i]+floor_faces[i+1]+floor_faces[i+2])/3.0
		if not Courtyard.AREA.grow(0.003).has_point(Vector2(center.x,center.z)):
			retained.append_array(floor_faces.slice(i,i+3))
	retained.append_array(Courtyard.build(architecture.get_node("NorthwestCourtyard"),material))
	floor_faces = retained
func _add_energy_frame(id: String, pose: Transform3D) -> void:
	var frame := Node3D.new()
	frame.name = "EnergyFrame_"+id
	frame.transform = pose
	architecture.add_child(frame)
	var stone := load("res://art/maze01/materials/plaster_cream.tres").duplicate() as StandardMaterial3D
	stone.albedo_color = Color("e9e9e5")
	for x in [-1.07,1.07]:
		Geometry.box(frame,"CarvedJamb",Vector3(0.28,2.8,0.42),Vector3(x,1.4,0),stone)
	Geometry.box(frame,"Lintel",Vector3(2.42,0.28,0.42),Vector3(0,2.66,0),stone)
	var barrier := Barrier.new()
	barrier.name = id
	frame.add_child(barrier)
	barriers.append(barrier)
func _open_northwest_threshold() -> void:
	# Green annotation: remove the tall two-sided chute, retaining the existing routes.
	for wall: Node3D in get_node("HorizontalWalls").get_children():
		if str(wall.name) not in ["WallSegment_H_4_4","WallSegment_H_4_5","WallSegment_H_5_4","WallSegment_H_5_5"]:
			continue
		var mesh := wall.get_child(0) as MeshInstance3D
		var source := mesh.get_meta("art_source_mesh",null) as BoxMesh
		if source==null:
			continue
		var height := minf(source.size.y,1.08 if wall.position.z<10.8 else 0.92)
		var adjusted := source.duplicate() as BoxMesh
		adjusted.size.y = height
		wall.position.y = height*0.5
		mesh.set_meta("art_source_mesh",adjusted)
		mesh.mesh = adjusted
		for shape: CollisionShape3D in wall.find_children("*","CollisionShape3D",true,false):
			if shape.shape is BoxShape3D:
				shape.shape = shape.shape.duplicate()
				shape.shape.size.y = height
				shape.position.y = 0.0


func _extend_pool_dividers() -> int:
	# Extend five existing walls: the requested second northern divider now seals the bypass.
	# There are no new protruding connector bodies or corner spokes.
	var count := 0
	for spec: Array in [["HorizontalWalls","WallSegment_H_7_5",0,12.0,15.54],["HorizontalWalls","WallSegment_H_11_5",0,12.0,15.54],["VerticalWalls","WallSegment_V_4_11",2,9.6,14.34],["VerticalWalls","WallSegment_V_4_12",2,9.45,14.34],["HorizontalWalls","WallSegment_H_8_14",0,32.46,36.0]]:
		var wall := get_node(str(spec[0])).get_node_or_null(str(spec[1])) as Node3D
		if wall==null:
			continue
		var visual := wall.get_child(0) as MeshInstance3D
		var source := visual.get_meta("art_source_mesh",visual.mesh) as BoxMesh
		if source==null:
			continue
		var replacement := source.duplicate() as BoxMesh
		replacement.size[spec[2]] = float(spec[4])-float(spec[3])
		wall.position[spec[2]] = (float(spec[3])+float(spec[4]))*0.5
		visual.mesh = replacement
		visual.set_meta("art_source_mesh",replacement)
		wall.set_meta("pool_join",true)
		if wall.name==&"WallSegment_V_4_12":wall.set_meta("extended_north_divider",true)
		for shape: CollisionShape3D in wall.find_children("*","CollisionShape3D",true,false):
			if shape.shape is BoxShape3D:
				shape.shape = shape.shape.duplicate()
				shape.shape.size[spec[2]] = replacement.size[spec[2]]
				shape.position[spec[2]] = 0.0
		count += 1
	return count


