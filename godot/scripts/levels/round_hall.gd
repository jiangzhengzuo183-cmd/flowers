extends RefCounted
## Circular room and porch union. All three external portal transforms stay fixed.

const Geometry := preload("res://scripts/levels/greybox_geometry.gd")
const WallPlan := preload("res://scripts/levels/wall_plan.gd")
const Windows := preload("res://scripts/levels/round_hall_windows.gd")
const WALL_CREAM := Color("a9a99c")

static func _inside(p: Vector2,rect: Array,margin: float = 0.0) -> bool:
	return p.x>=float(rect[0])-margin and p.x<=float(rect[1])+margin and p.y>=float(rect[2])-margin and p.y<=float(rect[3])+margin

static func contains(p: Vector2,spec: Dictionary) -> bool:
	var center := Vector2(spec.circle.center[0],spec.circle.center[1])
	if p.distance_to(center)<=float(spec.circle.usableRadius):
		return true
	for porch: Dictionary in spec.porches:
		if _inside(p,porch.rect):
			return true
	return false

static func build(parent: Node3D,spec: Dictionary) -> Node3D:
	var hall := Node3D.new()
	hall.name = "CentralRoundHall"
	parent.add_child(hall)
	var stone := Geometry.material(WALL_CREAM)
	var trim := stone
	var roof_material := Geometry.material(Color("687d84"))
	var roof_trim := Geometry.material(Color("747f7d"))
	var center := Vector2(spec.circle.center[0],spec.circle.center[1])
	var inner := float(spec.circle.usableRadius)
	var outer := float(spec.circle.outerRadius)
	var height := float(spec.eave)
	var windows := Windows.frames(center,outer,spec.porches)
	var circle_mask := PackedVector2Array()
	var wall_plans: Array[PackedVector2Array] = []
	var pier_masks := _portal_piers(spec)
	var band_clearance: Array = []
	for porch: Dictionary in spec.porches:
		var r: Array = porch.rect
		# End decorative bands past the 24cm porch wall, with a 1cm joint.
		band_clearance.append({"rect":[float(r[0])-0.25,float(r[1])+0.25,float(r[2])-0.25,float(r[3])+0.25]})
	for i in 144:
		circle_mask.append(center+Vector2(cos(TAU*i/144),sin(TAU*i/144))*inner)
	for i in 144:
		var a := TAU*i/144
		var b := TAU*(i+1)/144
		var plan := PackedVector2Array([center+Vector2(cos(a),sin(a))*inner,center+Vector2(cos(b),sin(b))*inner,center+Vector2(cos(b),sin(b))*outer,center+Vector2(cos(a),sin(a))*outer])
		# Cut exactly the porch opening out of the wall volume. Skipping an
		# entire wedge at a sampled radius used to leave vertical daylight slits.
		for piece: PackedVector2Array in WallPlan.outside_porches(plan,spec.porches):
			for unique: PackedVector2Array in _unique_pieces(piece,pier_masks):
				var wall := Geometry.extruded_polygon(hall,"CurvedWall%d"%i,unique,0,height,stone,true)
				# Keep the existing movement and camera collision footprint.
				var glazing_cut := Windows.cut_wall(unique,center,inner,windows,height)
				if glazing_cut != null:
					(wall.get_child(1) as MeshInstance3D).mesh = glazing_cut
				wall_plans.append(unique)
		for band: Array in [[0.03,0.22,outer+0.12],[height-0.22,height+0.02,outer+0.18]]:
			var band_plan := PackedVector2Array([center+Vector2(cos(a),sin(a))*(outer-0.03),center+Vector2(cos(b),sin(b))*(outer-0.03),center+Vector2(cos(b),sin(b))*float(band[2]),center+Vector2(cos(a),sin(a))*float(band[2])])
			for piece: PackedVector2Array in WallPlan.outside_porches(band_plan,band_clearance):
				Geometry.extruded_polygon(hall,"Plinth" if float(band[0])<1 else "Cornice",piece,float(band[0]),float(band[1]),trim,true)
	# Repeated pilasters and arched window recesses establish the European
	# pavilion silhouette while all details remain simple greybox geometry.
	for i in 12:
		var angle := TAU*i/12
		var pos := center+Vector2(cos(angle),sin(angle))*(outer+0.04)
		var blocked := false
		for porch: Dictionary in spec.porches:
			if _inside(pos,porch.rect,0.48):
				blocked = true
		if blocked:
			continue
		var facade := Node3D.new()
		facade.name = "EuropeanFacade%d"%i
		facade.position = Vector3(pos.x,0,pos.y)
		facade.rotation.y = PI/2-angle
		hall.add_child(facade)
		Geometry.box(facade,"Pilaster",Vector3(0.24,height-0.62,0.22),Vector3(0,(height+0.02)/2,0.01),stone,false)
		Geometry.box(facade,"Capital",Vector3(0.38,0.20,0.34),Vector3(0,height-0.36,0.04),trim,false)
		Geometry.box(facade,"Base",Vector3(0.34,0.22,0.28),Vector3(0,0.3,0.04),trim,false)
	Windows.build(hall,center,inner,outer,windows,trim)
	# Only the exposed edges of the porch union receive walls. Walls sit
	# outside the 1.8m net passage, and stop at each original external door.
	for index in spec.porches.size():
		var rect: Array = spec.porches[index].rect
		var corners := [Vector2(rect[0],rect[2]),Vector2(rect[1],rect[2]),Vector2(rect[1],rect[3]),Vector2(rect[0],rect[3])]
		for side in 4:
			var a: Vector2 = corners[side]
			var b: Vector2 = corners[(side+1)%4]
			var direction := (b-a).normalized()
			var outside := Vector2(direction.y,-direction.x)
			var cuts := _porch_cuts(a,b,center,inner,spec.porches)
			for step in range(1,cuts.size()):
				var start := a.lerp(b,cuts[step-1])
				var end := a.lerp(b,cuts[step])
				var mid := (start+end)/2
				if mid.distance_to(center)<inner-0.0001:
					continue
				var hidden_edge := false
				for other in spec.porches.size():
					if other!=index and _inside(mid+outside*0.015,spec.porches[other].rect):
						hidden_edge = true
				var door := (absf(mid.y-19.2)<0.02 and ((mid.x>=21.89 and mid.x<=23.71) or (mid.x>=26.69 and mid.x<=28.51))) or (absf(mid.y-26.4)<0.02 and mid.x>=24.29 and mid.x<=26.11)
				if hidden_edge or door:
					continue
				var plan := PackedVector2Array([start,end,end+outside*0.24,start+outside*0.24])
				for piece: PackedVector2Array in WallPlan.outside_porches(plan,spec.porches):
					for final_piece: PackedVector2Array in WallPlan.subtract(piece,circle_mask):
						# G7 and its linking porch share collinear outer edges. Only
						# generate previously uncovered wall volume, including round junctions.
						for without_pier: PackedVector2Array in _unique_pieces(final_piece,pier_masks):
							for unique: PackedVector2Array in _unique_pieces(without_pier,wall_plans):
								Geometry.extruded_polygon(hall,"PorchWall",unique,0,height,stone,true)
								wall_plans.append(unique)
	# One non-overlapping floor surface replaces coplanar cylinders/boxes.
	var floor_plans: Array[PackedVector2Array] = [circle_mask]
	for porch: Dictionary in spec.porches:
		var r: Array = porch.rect
		var plan := PackedVector2Array([Vector2(r[0],r[2]),Vector2(r[1],r[2]),Vector2(r[1],r[3]),Vector2(r[0],r[3])])
		floor_plans.append_array(_unique_pieces(plan,floor_plans))
	Geometry.plan_surface(hall,"HallFloor",floor_plans,0.024,Geometry.material(Color("b0b7ad")))
	var roof_group := Node3D.new()
	roof_group.name = "Roof"
	hall.add_child(roof_group)
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.08
	roof_mesh.bottom_radius = outer+0.1
	roof_mesh.height = float(spec.ridge)-height
	roof_mesh.radial_segments = 48
	var roof := MeshInstance3D.new()
	roof.mesh = roof_mesh
	roof.material_override = roof_material
	roof.position = Vector3(center.x,(height+float(spec.ridge))/2,center.y)
	roof_group.add_child(roof)
	for i in 12:
		var angle := TAU*i/12
		var radial := Vector3(cos(angle),0.0,sin(angle))
		var crest := Vector3(center.x,float(spec.ridge)-0.05,center.y) + radial * 0.136
		var gutter := Vector3(center.x,height+0.07,center.y) + radial * (outer+0.079)
		Geometry.beam(roof_group,"RoofRib",crest,gutter,0.046,roof_trim)
	Geometry.box(roof_group,"Finial",Vector3(0.12,0.8,0.12),Vector3(center.x,float(spec.ridge)+0.35,center.y),roof_trim,false)
	Geometry.box(roof_group,"FinialCrosspiece",Vector3(0.46,0.09,0.10),Vector3(center.x,float(spec.ridge)+0.48,center.y),roof_trim,false)
	# Thin ceiling supports camera obstruction without filling the room below it.
	var ceiling := StaticBody3D.new()
	ceiling.name = "Ceiling"
	hall.add_child(ceiling)
	var collider := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = inner
	cylinder.height = 0.12
	collider.shape = cylinder
	collider.position = Vector3(center.x,height-0.06,center.y)
	ceiling.add_child(collider)
	var roof_plans: Array[PackedVector2Array] = []
	for porch: Dictionary in spec.porches:
		var r: Array = porch.rect
		var plan := PackedVector2Array([Vector2(float(r[0])-0.14,float(r[2])-0.09),Vector2(float(r[1])+0.14,float(r[2])-0.09),Vector2(float(r[1])+0.14,float(r[3])+0.09),Vector2(float(r[0])-0.14,float(r[3])+0.09)])
		for unique: PackedVector2Array in _unique_pieces(plan,roof_plans):
			# These union pieces are rectangles; BoxMesh preserves the same
			# light-facing roof normals as the original pale floor slabs.
			var bounds := Rect2(unique[0],Vector2.ZERO)
			for p: Vector2 in unique:
				bounds = bounds.expand(p)
			Geometry.box(roof_group,"PorchRoof",Vector3(bounds.size.x,0.18,bounds.size.y),Vector3(bounds.get_center().x,height+0.09,bounds.get_center().y),stone)
			roof_plans.append(unique)
	Geometry.label(hall,"圆形教堂 · 三入口",Vector3(24,height+0.2,22.8),38)
	return hall

static func _portal_piers(spec: Dictionary) -> Array[PackedVector2Array]:
	var masks: Array[PackedVector2Array] = []
	for door: Dictionary in spec.doors:
		var center := Vector2((float(door.edge[0][1])+float(door.edge[1][1])+1)*1.2,(float(door.edge[0][0])+float(door.edge[1][0])+1)*1.2)
		var rotated: bool = door.edge[0][0]==door.edge[1][0]
		for side: float in [-1,1]:
			var offset := Vector2(0,side*1.05) if rotated else Vector2(side*1.05,0)
			var half := Vector2(0.2,0.15) if rotated else Vector2(0.15,0.2)
			var a := center+offset-half
			var b := center+offset+half
			masks.append(PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]))
	return masks

static func _unique_pieces(plan: PackedVector2Array,occupied: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [plan]
	for mask: PackedVector2Array in occupied:
		var next: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in pieces:
			next.append_array(WallPlan.subtract(piece,mask))
		pieces = next
		if pieces.is_empty():
			break
	return pieces

static func _porch_cuts(a: Vector2,b: Vector2,center: Vector2,radius: float,porches: Array) -> Array[float]:
	var cuts: Array[float] = [0.0,1.0]
	var horizontal := absf(b.x-a.x)>0.001
	var span := b.x-a.x if horizontal else b.y-a.y
	var fixed := a.y-center.y if horizontal else a.x-center.x
	var values: Array[float] = []
	if radius*radius>=fixed*fixed:
		var offset := sqrt(radius*radius-fixed*fixed)
		values.append((center.x if horizontal else center.y)-offset)
		values.append((center.x if horizontal else center.y)+offset)
	for porch: Dictionary in porches:
		var r: Array = porch.rect
		values.append(float(r[0] if horizontal else r[2]))
		values.append(float(r[1] if horizontal else r[3]))
	for value in values:
		var t := (value-(a.x if horizontal else a.y))/span
		if t>0.00001 and t<0.99999 and not cuts.has(t):
			cuts.append(t)
	cuts.sort()
	return cuts
