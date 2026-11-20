extends Control
## Real editable Godot text on the existing paper/artwork; SubViewport keeps it bound to the sheet.
const HAND := preload("res://assets/fonts/YeLiHangJiuLinKaTong.ttf")
var page: Dictionary = {}
var artwork: Texture2D
var cover := false
var outline: PackedVector2Array

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline = paper_outline(page.get("side","left") == "left")
	queue_redraw()

static func paper_outline(left: bool) -> PackedVector2Array:
	var points: Array[Vector2] = [Vector2(34,7)]
	var segments := [[Vector2(280,-1),Vector2(650,10)],[Vector2(731,13),Vector2(762,27)],Vector2(762,925),[Vector2(720,914),Vector2(650,910)],[Vector2(400,901),Vector2(32,909)],[Vector2(12,909),Vector2(12,882)],Vector2(12,38),[Vector2(12,9),Vector2(34,7)]]
	for segment: Variant in segments:
		if segment is Vector2: points.append(segment)
		else:
			var start := points[-1]
			for i in range(1,11):
				var t := float(i)/10.0
				points.append(start*(1-t)*(1-t)+segment[0]*2*t*(1-t)+segment[1]*t*t)
	if not left:
		for i in points.size(): points[i].x = 762-points[i].x
	return PackedVector2Array(points)

func _draw() -> void:
	if cover:
		draw_texture_rect(artwork,Rect2(0,0,530,650),false)
		draw_set_transform(Vector2(262,185),deg_to_rad(-9))
		var label := "进步报告"
		draw_string(HAND,Vector2(-HAND.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x/2,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("66523b"))
		draw_set_transform(Vector2.ZERO)
		return
	if artwork == null: return
	var uv := PackedVector2Array()
	for point: Vector2 in outline: uv.append(point/Vector2(762,925))
	draw_polygon(outline,PackedColorArray([Color.WHITE]),uv,artwork)
	for block: Dictionary in page.get("content",[]):
		var font: Font = HAND
		if block.get("letterSpacing",0)>0:
			var variation := FontVariation.new()
			variation.base_font = HAND
			variation.spacing_glyph = roundi(block.letterSpacing)
			font = variation
		var font_size := roundi(block.fontSize)
		var origin := Vector2.ZERO
		if block.has("rotation"):
			origin = Vector2(block.origin.x,block.origin.y)
			draw_set_transform(origin,deg_to_rad(block.rotation))
		for line: Dictionary in block.lines:
			var position := Vector2(line.x,line.baseline)-origin
			if block.get("textAnchor","start") == "middle": position.x -= font.get_string_size(line.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x/2
			draw_string(font,position,line.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("493f30"))
		draw_set_transform(Vector2.ZERO)
