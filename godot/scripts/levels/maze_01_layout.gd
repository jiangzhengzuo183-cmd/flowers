extends RefCounted

const CONFIG_PATH := "res://data/levels/maze_01_greybox.json"
static var _cached: Dictionary = {}
static var courtyard_faces: Array[PackedVector3Array] = []

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
	_build_courtyard_faces(result)
	return result

static func _nw_level(r: int,c: int) -> float:
	return float(config().northwest.levels[r-2][c]) if r>=2 and r<=5 and c>=0 and c<=3 else 0.0

static func _corner_level(r: int,c: int) -> float:
	var total := 0.0
	var count := 0
	for rr in [r-1,r]:
		for cc in [c-1,c]:
			if rr>=2 and rr<=5 and cc>=0 and cc<=3:
				total += _nw_level(rr,cc)
				count += 1
	return total/maxi(1,count)

static func _build_courtyard_faces(map: Dictionary) -> void:
	courtyard_faces.clear()
	for r in range(2,6):
		for c in range(4):
			var y := _nw_level(r,c)
			var center := cell_point([r,c],y)
			var outer: Array[Vector3] = []
			var inner: Array[Vector3] = []
			# A 1m flat landing at every cell centre; the remaining 1.4m between
			# adjacent landings carries a 0.6/0.9m rise with continuous seams.
			for p: Vector2 in [Vector2(-1,-1),Vector2(0,-1),Vector2(1,-1),Vector2(1,0),Vector2(1,1),Vector2(0,1),Vector2(-1,1),Vector2(-1,0)]:
				var h := y
				if p.x!=0 and p.y!=0:
					h = _corner_level(r+(1 if p.y>0 else 0),c+(1 if p.x>0 else 0))
				else:
					var side := "north" if p.y<0 else ("south" if p.y>0 else ("west" if p.x<0 else "east"))
					if not map.grid.cellWalls[r][c][side]:
						h = (y+_nw_level(r+int(p.y),c+int(p.x)))/2
				outer.append(center+Vector3(p.x*1.2,h-y,p.y*1.2))
				inner.append(center+Vector3(p.x*0.5,0,p.y*0.5))
			var faces := PackedVector3Array()
			for i in 8:
				var j := (i+1)%8
				faces.append_array(PackedVector3Array([center,inner[j],inner[i],inner[i],inner[j],outer[j],inner[i],outer[j],outer[i]]))
			courtyard_faces.append(faces)

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
