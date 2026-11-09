extends RefCounted

const CONFIG_PATH := "res://data/levels/maze_01_greybox.json"
const H5_GRID_UNIT := 0.025
const H5_CELL_UNITS := 96
const H5_RISER_HEIGHT := 0.15
static var _cached: Dictionary = {}
static var courtyard_faces: Array[PackedVector3Array] = []
static var courtyard_steps: Array[PackedVector3Array] = []
static var courtyard_risers := PackedVector3Array()
static var courtyard_collision_risers := PackedVector3Array()

static func config() -> Dictionary:
	if _cached.is_empty():
		_cached = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	return _cached

static func cell_point(cell: Array, y: float = 0.0) -> Vector3:
	return Vector3((float(cell[1])+0.5)*2.4, y, (float(cell[0])+0.5)*2.4)

static func patched_map(original: Dictionary) -> Dictionary:
	var result := original.duplicate(true)
	for patch: Dictionary in config().wall_patches:
		var matrix: Array = result.grid.verticalWalls if patch.axis == "v" else result.grid.horizontalWalls
		matrix[int(patch.row)][int(patch.col)] = patch.wall
	for r in int(result.grid.rows):
		for c in int(result.grid.cols):
			result.grid.cellWalls[r][c] = {"north":result.grid.horizontalWalls[r][c],"south":result.grid.horizontalWalls[r+1][c],"west":result.grid.verticalWalls[r][c],"east":result.grid.verticalWalls[r][c+1]}
	if courtyard_faces.is_empty():
		_build_courtyard_faces()
	return result

static func _nw_level(r: int,c: int) -> float:
	return float(config().northwest.levels[r-2][c]) if r>=2 and r<=5 and c>=0 and c<=3 else 0.0

static func _build_courtyard_faces() -> void:
	var spec: Dictionary = config().northwest
	var shore: Array = spec.entry.inside
	var ramps: Dictionary = {}
	for transition: Dictionary in spec.transitions:
		for side in 2:
			var from: Array = transition.a if side==0 else transition.b
			var to: Array = transition.b if side==0 else transition.a
			var tile := Vector2i(int(from[1]),int(from[0]))
			var direction := Vector2i(int(to[1]),int(to[0]))-tile
			var start := float(transition.heights[side])
			var finish := float(transition.heights[1-side])
			if to==shore:
				continue # The southwest stair descends wholly inside its dry entry cell.
			if not ramps.has(tile):
				ramps[tile] = {}
			var edge_height := finish if from==shore else (start+finish)*0.5
			var run := 1.0 if from==shore else (0.9 if absf(start-finish)>0.7 else 0.6)
			ramps[tile][direction] = Vector2(edge_height,run)
	# Keep the invisible walking surface continuous. Visible treads change
	# height midway between the collision levels, at most half a riser away.
	# Grid cuts mark the ends of the 0.6/0.9/1.0 m runs and each tread edge.
	var entry_tile := Vector2i(int(shore[1]),int(shore[0]))
	courtyard_collision_risers = _courtyard_grid(ramps,entry_tile,[0,24,36,40,56,60,72,96],false,courtyard_faces)
	courtyard_risers = _courtyard_grid(ramps,entry_tile,[0,5,6,15,18,24,25,30,35,36,40,56,60,61,66,71,72,78,81,90,91,96],true,courtyard_steps)

static func _courtyard_grid(ramps: Dictionary,entry_tile: Vector2i,cuts: Array,stepped: bool,surfaces_out: Array[PackedVector3Array]) -> PackedVector3Array:
	surfaces_out.clear()
	var edges: Dictionary = {}
	var risers := PackedVector3Array()
	for r in range(2,6):
		for c in range(4):
			var y := _nw_level(r,c)
			var tile := Vector2i(c,r)
			var slopes: Dictionary = ramps.get(tile,{})
			var faces := PackedVector3Array()
			for j in cuts.size()-1:
				for i in cuts.size()-1:
					var lo := Vector2(cuts[i],cuts[j])*H5_GRID_UNIT
					var hi := Vector2(cuts[i+1],cuts[j+1])*H5_GRID_UNIT
					var x0: int = c*H5_CELL_UNITS+cuts[i]
					var x1: int = c*H5_CELL_UNITS+cuts[i+1]
					var z0: int = r*H5_CELL_UNITS+cuts[j]
					var z1: int = r*H5_CELL_UNITS+cuts[j+1]
					var h := Vector4.ZERO
					if stepped:
						h = Vector4.ONE*snappedf(_courtyard_ramp_height(y,slopes,(lo+hi)*0.5),H5_RISER_HEIGHT)
					else:
						h = Vector4(
							_courtyard_ramp_height(y,slopes,lo),
							_courtyard_ramp_height(y,slopes,Vector2(hi.x,lo.y)),
							_courtyard_ramp_height(y,slopes,hi),
							_courtyard_ramp_height(y,slopes,Vector2(lo.x,hi.y))
						)
					var a := Vector3(x0*H5_GRID_UNIT,h.x,z0*H5_GRID_UNIT)
					var b := Vector3(x1*H5_GRID_UNIT,h.y,z0*H5_GRID_UNIT)
					var d := Vector3(x0*H5_GRID_UNIT,h.w,z1*H5_GRID_UNIT)
					var corner := Vector3(x1*H5_GRID_UNIT,h.z,z1*H5_GRID_UNIT)
					if slopes.size()>1:
						# The two southwest flights meet on a diagonal at the L-shaped turn.
						faces.append_array(PackedVector3Array([a,d,b,b,d,corner]))
					else:
						faces.append_array(PackedVector3Array([a,corner,b,a,d,corner]))
					_join_courtyard_edge(edges,risers,Vector4i(x0,z0,x1,z0),a,b)
					_join_courtyard_edge(edges,risers,Vector4i(x0,z1,x1,z1),d,corner)
					_join_courtyard_edge(edges,risers,Vector4i(x0,z0,x0,z1),a,d)
					_join_courtyard_edge(edges,risers,Vector4i(x1,z0,x1,z1),b,corner)
					if tile==entry_tile and j==cuts.size()-2:
						_join_courtyard_edge(edges,risers,Vector4i(x0,z1,x1,z1),Vector3(d.x,0,d.z),Vector3(corner.x,0,corner.z))
			surfaces_out.append(faces)
	return risers

static func _courtyard_ramp_height(y: float,slopes: Dictionary,p: Vector2) -> float:
	var height := y
	for direction: Vector2i in slopes:
		var edge: Vector2 = slopes[direction]
		var distance := 1.2-(p-Vector2(1.2,1.2)).dot(Vector2(direction))
		var ramp := lerpf(edge.x,y,clampf(distance/edge.y,0.0,1.0))
		height = minf(height,ramp) if edge.x<y else maxf(height,ramp)
	return height

static func _join_courtyard_edge(edges: Dictionary,risers: PackedVector3Array,key: Vector4i,a: Vector3,b: Vector3) -> void:
	if not edges.has(key):
		edges[key] = PackedVector3Array([a,b])
		return
	# Straight retaining faces close the sides of a ramp or a level change.
	var other: PackedVector3Array = edges[key]
	if not is_equal_approx(a.y,other[0].y):
		risers.append_array(PackedVector3Array([a,other[0],other[1]]))
	if not is_equal_approx(b.y,other[1].y):
		risers.append_array(PackedVector3Array([a,other[1],b]))

static func courtyard_height(point: Vector2) -> float:
	for faces: PackedVector3Array in courtyard_faces:
		for i in range(0,faces.size(),3):
			var a := Vector2(faces[i].x,faces[i].z)
			var b := Vector2(faces[i+1].x,faces[i+1].z)
			var c := Vector2(faces[i+2].x,faces[i+2].z)
			var denominator := (b-a).cross(c-a)
			if absf(denominator)<0.00001:
				continue
			var u := (point-a).cross(c-a)/denominator
			var v := (b-a).cross(point-a)/denominator
			if u>=-0.0001 and v>=-0.0001 and u+v<=1.0001:
				return faces[i].y*(1-u-v)+faces[i+1].y*u+faces[i+2].y*v
	return 0.0

static func surface_height(surface: Dictionary, point: Vector2) -> float:
	var r: Array = surface.rect
	var t := inverse_lerp(float(r[0] if surface.axis == "x" else r[2]),float(r[1] if surface.axis == "x" else r[3]),point.x if surface.axis == "x" else point.y)
	return lerpf(float(surface.heights[0]),float(surface.heights[1]),clampf(t,0,1))

static func contains(surface: Dictionary, point: Vector2, tolerance: float = 0.001) -> bool:
	var r: Array = surface.rect
	return point.x >= float(r[0])-tolerance and point.x <= float(r[1])+tolerance and point.y >= float(r[2])-tolerance and point.y <= float(r[3])+tolerance

static func height_at(point: Vector2) -> float:
	if point.x>=0 and point.x<=9.6 and point.y>=4.8 and point.y<=14.4:
		return courtyard_height(point)
	if in_sunken_corridor(point):
		return corridor_height(point.y)
	var height := 0.0
	for surface: Dictionary in config().surfaces:
		if contains(surface,point):
			height = maxf(height,surface_height(surface,point))
	return height

static func in_sunken_corridor(point: Vector2) -> bool:
	var rect: Array = config().sunken_corridor.rect
	return point.x>=float(rect[0]) and point.x<=float(rect[1]) and point.y>=float(rect[2]) and point.y<=float(rect[3])

static func corridor_height(z: float) -> float:
	for section: Dictionary in config().sunken_corridor.sections:
		if z>=float(section.z[0])-0.001 and z<=float(section.z[1])+0.001:
			return lerpf(float(section.heights[0]),float(section.heights[1]),clampf(inverse_lerp(float(section.z[0]),float(section.z[1]),z),0,1))
	return 0.0

static func cell_key(cell: Array) -> String:
	return "%d,%d" % [int(cell[0]),int(cell[1])]

static func edge_key(a: String, b: String) -> String:
	var pair := [a,b]
	pair.sort()
	return "|".join(pair)

static func reachable(original: Dictionary, closed: Array[String]) -> Dictionary:
	var map := patched_map(original)
	var adjacency: Dictionary = {}
	for r in int(original.grid.rows):
		for c in int(original.grid.cols):
			var id := cell_key([r,c])
			adjacency[id] = []
			for direction: Array in [[-1,0,"north"],[1,0,"south"],[0,-1,"west"],[0,1,"east"]]:
				var rr := r+int(direction[0])
				var cc := c+int(direction[1])
				if rr>=0 and rr<19 and cc>=0 and cc<19 and not map.grid.cellWalls[r][c][direction[2]]:
					adjacency[id].append(cell_key([rr,cc]))
	var data := config()
	for pair: Array in data.ground_close:
		var a := cell_key(pair[0])
		var b := cell_key(pair[1])
		adjacency[a].erase(b)
		adjacency[b].erase(a)
	for pair: Array in data.ground_open:
		var a := cell_key(pair[0])
		var b := cell_key(pair[1])
		if not adjacency[a].has(b):
			adjacency[a].append(b)
		if not adjacency[b].has(a):
			adjacency[b].append(a)
	for neighbor: String in ["6,15","6,17"]:
		adjacency["6,16"].erase(neighbor)
		adjacency[neighbor].erase("6,16")
	adjacency["6,16,ground"] = ["6,15","6,17"]
	adjacency["6,15"].append("6,16,ground")
	adjacency["6,17"].append("6,16,ground")
	var blocked: Dictionary = {}
	for door: Dictionary in data.doors:
		if closed.has(str(door.id)):
			blocked[edge_key(cell_key(door.edge[0]),cell_key(door.edge[1]))] = true
	var queue := ["18,0"]
	var seen := {"18,0":true}
	var index := 0
	while index < queue.size():
		var a: String = queue[index]
		index += 1
		for b: String in adjacency[a]:
			if not seen.has(b) and not blocked.has(edge_key(a,b)):
				seen[b] = true
				queue.append(b)
	return seen
