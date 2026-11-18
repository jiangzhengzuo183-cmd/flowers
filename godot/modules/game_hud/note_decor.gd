extends Node2D
## A small translucent washi strip, kept outside the dialog's content layout and input.
func _ready() -> void:
    z_index=1
    get_parent().resized.connect(queue_redraw)
func _draw() -> void:
    var paper: Control=get_parent()
    var center:=Vector2(paper.size.x*0.5,1.0)
    var strip:=PackedVector2Array([Vector2(-47,-11),Vector2(-43,-14),Vector2(44,-12),Vector2(48,9),Vector2(43,13),Vector2(-46,11)])
    for i in strip.size():strip[i]+=center
    draw_colored_polygon(strip,Color(0.94,0.77,0.35,0.66))
