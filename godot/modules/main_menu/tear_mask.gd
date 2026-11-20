extends Node2D
## All rims first, then all interiors: overlap is a union, with no white seam inside it.
var outer_shapes: Array[PackedVector2Array]=[]
var inner_shapes: Array[PackedVector2Array]=[]
func _draw() -> void:
	for polygon in outer_shapes: _shape(polygon,Color(1,0,0,1))
	for polygon in inner_shapes: _shape(polygon,Color(1,1,0,1))
func _shape(polygon: PackedVector2Array,color: Color) -> void:
	draw_colored_polygon(polygon,color)
	var edge:=polygon.duplicate()
	edge.append(edge[0])
	draw_polyline(edge,color,0.9,true)
