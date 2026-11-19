extends Control
var tapes: Array[Polygon2D] = []
var tape_shadows: Array[Polygon2D] = []
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var shadow := Polygon2D.new()
		shadow.color = Color(0.31,0.24,0.14,0.075)
		add_child(shadow)
		tape_shadows.append(shadow)
		var tape := Polygon2D.new()
		tape.color = Color(0.92,0.74,0.30,0.52 if i==0 else 0.43)
		add_child(tape)
		tapes.append(tape)
func place(paper: Rect2) -> void:
	var unit := paper.size.x/1920.0
	var tape_shape := PackedVector2Array([Vector2(-75,-17),Vector2(-69,-21),Vector2(-73,-24),Vector2(69,-22),Vector2(74,-15),Vector2(70,-7),Vector2(76,0),Vector2(72,9),Vector2(75,18),Vector2(65,22),Vector2(-72,21),Vector2(-76,14),Vector2(-71,5),Vector2(-76,-4)])
	for i in 2:
		var polygon := PackedVector2Array()
		var center := paper.position+Vector2(145,53)*unit if i==0 else paper.position+Vector2(1775,1012)*unit
		var angle := deg_to_rad(-16 if i==0 else -19)
		for point in tape_shape: polygon.append(center+(point*unit).rotated(angle))
		tapes[i].polygon = polygon
		var shade := PackedVector2Array()
		for point in polygon: shade.append(point+Vector2(0.5,1.5)*unit)
		tape_shadows[i].polygon = shade
