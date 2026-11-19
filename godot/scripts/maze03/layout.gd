extends RefCounted
const Base := preload("res://scripts/levels/maze_01_layout.gd")
const POOL := Rect2(15.6,15.6,18.0,15.6)
const CENTER := Vector3(24.0,0.0,22.8)
static var _settings: Dictionary={}
static func pool_rect() -> Array:
	return [POOL.position.x,POOL.end.x,POOL.position.y,POOL.end.y]
static func config() -> Dictionary:
	if _settings.is_empty():
		_settings=Base.config().duplicate(true)
		_settings.surfaces=_settings.surfaces.filter(func(s: Dictionary): return not str(s.id).begins_with("H4_"))
	return _settings
static func openings() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/maze03_openings.json"))
static func cell_point(cell: Array,y: float=0.0) -> Vector3:
	return Base.cell_point(cell,y)
static func contains(surface: Dictionary,point: Vector2,tolerance: float=0.001) -> bool:
	return Base.contains(surface,point,tolerance)
static func surface_height(surface: Dictionary,point: Vector2) -> float:
	return Base.surface_height(surface,point)
static func height_at(point: Vector2) -> float:
	if point.x<9.61 and point.y<14.41:
		return 0.0
	if Base.in_sunken_corridor(point):
		return Base.corridor_height(point.y)
	var height:=0.0
	for surface: Dictionary in config().surfaces:
		if contains(surface,point):
			height=maxf(height,surface_height(surface,point))
	return height
static func patched_map(original: Dictionary) -> Dictionary:
	var result:=Base.patched_map(original)
	for patch: Dictionary in openings():
		var matrix: Array=result.grid.verticalWalls if patch.axis=="v" else result.grid.horizontalWalls
		matrix[int(patch.row)][int(patch.col)]=false
	# The explicitly redesigned water precinct replaces the old central enclosure.
	for r in 19:
		for c in 20:
			if POOL.has_point(Vector2(c*2.4,(r+0.5)*2.4)):
				result.grid.verticalWalls[r][c]=false
	for r in 20:
		for c in 19:
			if POOL.has_point(Vector2((c+0.5)*2.4,r*2.4)):
				result.grid.horizontalWalls[r][c]=false
	# Old northwest courtyard becomes ordinary connected maze corridors.
	for item: Array in [[3,1],[3,2],[5,1]]:
		result.grid.horizontalWalls[item[0]][item[1]]=true
	for r in 19:
		for c in 19:
			result.grid.cellWalls[r][c]={"north":result.grid.horizontalWalls[r][c],"south":result.grid.horizontalWalls[r+1][c],"west":result.grid.verticalWalls[r][c],"east":result.grid.verticalWalls[r][c+1]}
	return result
