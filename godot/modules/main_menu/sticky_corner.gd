extends Node2D
const FOLD_SIZE := 58.0
func _ready() -> void:
	z_index=2
	get_parent().resized.connect(queue_redraw)
func _draw() -> void:
	var paper: Control=get_parent()
	var origin:=paper.size
	var hinge_a:=origin-Vector2(FOLD_SIZE,0)
	var hinge_b:=origin-Vector2(0,FOLD_SIZE)
	var lifted:=origin-Vector2(FOLD_SIZE-3,FOLD_SIZE-4)
	# A small folded paper back with close contact shading on the original sheet.
	for layer in range(4,0,-1):
		var shade:=PackedVector2Array([hinge_a,hinge_b,lifted-Vector2(layer*1.4,layer*0.8)])
		draw_colored_polygon(shade,Color(0.39,0.29,0.13,0.028))
	draw_colored_polygon(PackedVector2Array([hinge_a,hinge_b,lifted]),Color("fff7d3"))
	draw_colored_polygon(PackedVector2Array([hinge_a,hinge_b,lifted.lerp(hinge_a,0.30)]),Color(0.89,0.75,0.40,0.14))
	draw_line(hinge_a,hinge_b,Color(0.65,0.48,0.22,0.24),1.0,true)
	draw_polyline(PackedVector2Array([hinge_a,lifted,hinge_b]),Color(1.0,0.99,0.90,0.72),1.0,true)
