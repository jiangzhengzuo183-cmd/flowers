extends RefCounted
## JSON data stays independent of engine-specific scenes or meshes.

static func load_map(path: String = "res://data/maze_01.json") -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "找不到迷宫数据：" + path}
	var parser := JSON.new()
	var status := parser.parse(FileAccess.get_file_as_string(path))
	if status != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "地图 JSON 解析失败：" + parser.get_error_message()}
	var maze: Dictionary = parser.data
	var error := validate(maze)
	if not error.is_empty():
		return {"ok": false, "error": error}
	return {"ok": true, "data": maze, "metrics": metrics(maze)}

static func _cell_ok(cell: Variant, rows: int, cols: int) -> bool:
	return cell is Array and cell.size() == 2 and (cell[0] is float or cell[0] is int) and (cell[1] is float or cell[1] is int) and float(cell[0]) == floor(float(cell[0])) and float(cell[1]) == floor(float(cell[1])) and cell[0] >= 0 and cell[0] < rows and cell[1] >= 0 and cell[1] < cols

static func _matrix_ok(matrix: Variant, rows: int, cols: int) -> bool:
	if not matrix is Array or matrix.size() != rows:
		return false
	for row: Variant in matrix:
		if not row is Array or row.size() != cols:
			return false
		for value: Variant in row:
			if not value is bool:
				return false
	return true

static func validate(maze: Dictionary) -> String:
	var grid: Dictionary = maze.get("grid", {})
	var rows := int(grid.get("rows", 0))
	var cols := int(grid.get("cols", 0))
	if rows <= 0 or cols <= 0 or float(grid.get("rows", 0)) != rows or float(grid.get("cols", 0)) != cols:
		return "地图行列数必须是正整数。"
	if float(grid.get("cellSizeWorld", 0)) <= 0:
		return "地图格子边长无效。"
	if not _matrix_ok(grid.get("verticalWalls"), rows, cols + 1):
		return "verticalWalls 尺寸或内容无效。"
	if not _matrix_ok(grid.get("horizontalWalls"), rows + 1, cols):
		return "horizontalWalls 尺寸或内容无效。"
	var cells: Variant = grid.get("cellWalls")
	if not cells is Array or cells.size() != rows:
		return "cellWalls 行数无效。"
	for r in range(rows):
		if not cells[r] is Array or cells[r].size() != cols:
			return "cellWalls 列数无效。"
		for c in range(cols):
			var expected := {"north": grid.horizontalWalls[r][c], "south": grid.horizontalWalls[r + 1][c], "west": grid.verticalWalls[r][c], "east": grid.verticalWalls[r][c + 1]}
			if not cells[r][c] is Dictionary or cells[r][c] != expected:
				return "格子墙体与边界矩阵不一致：[%d, %d]" % [r, c]
	var openings: Dictionary = maze.get("openings", {})
	for id: String in ["entry", "exit"]:
		var opening: Dictionary = openings.get(id, {})
		if not _cell_ok(opening.get("cell"), rows, cols):
			return id + " 坐标无效。"
		var r := int(opening.cell[0])
		var c := int(opening.cell[1])
		var side: String = opening.get("side", "")
		var boundary := {"north": r == 0, "south": r == rows - 1, "west": c == 0, "east": c == cols - 1}
		if not boundary.get(side, false) or cells[r][c].get(side, true):
			return id + " 开口被封闭或不在地图外边界。"
	var checkpoints: Variant = maze.get("checkpoints")
	if not checkpoints is Array:
		return "检查点列表无效。"
	for checkpoint: Variant in checkpoints:
		if not checkpoint is Dictionary or not _cell_ok(checkpoint.get("cell"), rows, cols):
			return "检查点坐标无效。"
	var routes: Dictionary = maze.get("routes", {})
	for id: String in ["A", "B"]:
		var route: Dictionary = routes.get(id, {})
		var path: Variant = route.get("cellPath")
		if not path is Array or path.size() < 2:
			return "路线 " + id + " 为空。"
		for cell: Variant in path:
			if not _cell_ok(cell, rows, cols):
				return "路线 " + id + " 包含无效坐标。"
		if int(route.get("moveCount", -1)) != path.size() - 1 or path[0] != openings.entry.cell or path[-1] != openings.exit.cell:
			return "路线 " + id + " 步数或起终点不一致。"
		for i in range(1, path.size()):
			var previous: Array = path[i - 1]
			var dr := int(path[i][0] - previous[0])
			var dc := int(path[i][1] - previous[1])
			if absi(dr) + absi(dc) != 1:
				return "路线 " + id + " 有不相邻的格子。"
			var side := "north" if dr < 0 else ("south" if dr > 0 else ("west" if dc < 0 else "east"))
			if cells[int(previous[0])][int(previous[1])][side]:
				return "路线 " + id + " 穿过墙体。"
	if reachable_count(maze) != rows * cols:
		return "存在从入口不可达的格子。"
	return ""

static func reachable_count(maze: Dictionary) -> int:
	var entry := Vector2i(int(maze.openings.entry.cell[0]), int(maze.openings.entry.cell[1]))
	var queue: Array[Vector2i] = [entry]
	var seen: Dictionary = {entry: true}
	var index := 0
	var directions := [["north", -1, 0], ["south", 1, 0], ["west", 0, -1], ["east", 0, 1]]
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		for direction: Array in directions:
			var r := cell.x + int(direction[1])
			var c := cell.y + int(direction[2])
			if r < 0 or r >= int(maze.grid.rows) or c < 0 or c >= int(maze.grid.cols):
				continue
			var next := Vector2i(r, c)
			if maze.grid.cellWalls[cell.x][cell.y][direction[0]] or seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return seen.size()

static func metrics(maze: Dictionary) -> Dictionary:
	var walls := 0
	for matrix: Array in [maze.grid.verticalWalls, maze.grid.horizontalWalls]:
		for row: Array in matrix:
			for wall: bool in row:
				walls += int(wall)
	return {"walls": walls, "reachable": reachable_count(maze), "rows": int(maze.grid.rows), "cols": int(maze.grid.cols)}
