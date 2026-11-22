extends RefCounted
## Small visibility graph: the whole mouse silhouette goes around protected ink.
static func segment_clear(a: Vector2, b: Vector2, obstacles: Array[Rect2]) -> bool:
	for rect in obstacles:
		var inner := rect
		if inner.has_point(a) or inner.has_point(b): return false
		var corners := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
		for i in 4:
			if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i+1)%4]) != null:
				return false
	return true

static func nearest_free(point: Vector2, bounds: Rect2, obstacles: Array[Rect2]) -> Vector2:
	var p := point.clamp(bounds.position, bounds.end)
	for attempt in 12:
		var moved := false
		for r in obstacles:
			if not r.has_point(p): continue
			var candidates: Array[Vector2] = [Vector2(r.position.x-3, p.y), Vector2(r.end.x+3, p.y), Vector2(p.x, r.position.y-3), Vector2(p.x, r.end.y+3)]
			var best := p
			var distance := INF
			for candidate in candidates:
				if not bounds.has_point(candidate): continue
				var free := true
				for other in obstacles:
					if other.has_point(candidate): free = false
				if free and p.distance_squared_to(candidate) < distance:
					distance = p.distance_squared_to(candidate)
					best = candidate
			if distance < INF:
				p = best
				moved = true
		if not moved: break
	return p

static func route(start: Vector2, target: Vector2, bounds: Rect2, obstacles: Array[Rect2]) -> PackedVector2Array:
	var goal := nearest_free(target, bounds, obstacles)
	if segment_clear(start, goal, obstacles): return PackedVector2Array([goal])
	var nodes: Array[Vector2] = [start, goal]
	for rect in obstacles:
		var r := rect.grow(3.0)
		for point: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			if not bounds.has_point(point): continue
			var free := true
			for other in obstacles:
				if other.has_point(point): free = false
			if free: nodes.append(point)
	var distances: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for i in nodes.size():
		distances.append(INF)
		previous.append(-1)
		visited.append(false)
	distances[0] = 0.0
	for iteration in nodes.size():
		var current := -1
		for i in nodes.size():
			if not visited[i] and (current == -1 or distances[i] < distances[current]): current = i
		if current == -1 or distances[current] == INF: break
		if current == 1: break
		visited[current] = true
		for next in nodes.size():
			if visited[next] or not segment_clear(nodes[current], nodes[next], obstacles): continue
			var length := distances[current] + nodes[current].distance_to(nodes[next])
			if length < distances[next]:
				distances[next] = length
				previous[next] = current
	if previous[1] == -1: return PackedVector2Array()
	var result := PackedVector2Array()
	var index := 1
	while index != 0:
		result.insert(0, nodes[index])
		index = previous[index]
	return result
