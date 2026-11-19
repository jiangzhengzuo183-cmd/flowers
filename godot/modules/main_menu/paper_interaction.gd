extends Node2D
## Non-destructive tears over the supplied composite; UV anchors survive resizing.
var paper_rect := Rect2()
var holes: Array[Dictionary] = []
var active_hole := -1
var redraw_pending := false

func place(rect: Rect2) -> void:
	paper_rect = rect
	queue_redraw()

func begin_gnaw(at: Vector2) -> void:
	if holes.size() >= 8: holes.pop_front()
	holes.append({"uv": (at - paper_rect.position) / paper_rect.size, "bites": 0, "seed": holes.size() * 1.733 + 0.62, "growth": 0.0})
	active_hole = holes.size() - 1

func bite() -> void:
	if active_hole < 0: return
	holes[active_hole].bites = mini(4, int(holes[active_hole].bites) + 1)
	redraw_pending = true

func stop_gnaw() -> void:
	active_hole = -1

func _process(delta: float) -> void:
	if not redraw_pending: return
	var moving := false
	for hole in holes:
		var goal := float(hole.bites)
		hole.growth = move_toward(float(hole.growth), goal, delta * 4.0)
		if absf(float(hole.growth) - goal) > 0.001: moving = true
	redraw_pending = moving
	queue_redraw()

func _draw() -> void:
	var unit := paper_rect.size.x / 1920.0
	for hole in holes:
		var growth := float(hole.growth)
		if growth <= 0.01: continue
		var center: Vector2 = paper_rect.position + Vector2(hole.uv) * paper_rect.size
		var radius := (4.0 + growth * 2.1) * unit
		var points := PackedVector2Array()
		for i in 32:
			var angle := TAU * i / 32.0
			var irregular := 1.0 + sin(i * 2.73 + float(hole.seed)) * 0.12 + cos(i * 1.77) * 0.07
			points.append(center + Vector2(cos(angle), sin(angle) * 0.73) * radius * irregular)
		# Warm under-paper, a fine torn rim and restrained inner shade.
		draw_colored_polygon(points, Color("d6c8a9"))
		points.append(points[0])
		draw_polyline(points, Color(0.43, 0.34, 0.22, 0.24), 1.2 * unit, true)
		for i in range(1, 31, 4):
			var p := points[i]
			var outward := (p - center).normalized()
			draw_line(p, p + outward * 2.1 * unit + Vector2(0, -unit), Color(1.0, 0.97, 0.88, 0.84), 0.8 * unit, true)
