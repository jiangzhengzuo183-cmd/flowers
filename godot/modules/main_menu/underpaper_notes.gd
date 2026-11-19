extends Node2D
## A whole handwritten page, rendered once and exposed through the shared tear mask.
const PAGE_SIZE:=Vector2(1920,1080)
var handwriting: FontVariation
const PHRASES: Array[String]=[
	"I will try again tomorrow.",
	"One more small step, then another.",
	"There is still something new to notice.",
	"I keep a little space for questions.",
	"Some turns take longer than I expected.",
	"I remember the way the afternoon felt.",
	"A small detail can change the whole page.",
	"I want to remember this while I can.",
	"Follow the quiet signs and keep looking.",
	"Not everything has to be understood at once.",
	"The paper keeps the words for later.",
	"A little patience, a little courage."]
func _ready() -> void:
	handwriting=FontVariation.new()
	handwriting.base_font=preload("res://modules/main_menu/menu_typography.gd").font()
	handwriting.variation_transform=Transform2D(Vector2.RIGHT,Vector2(-0.22,1.0),Vector2.ZERO)
	queue_redraw()
func _draw() -> void:
	draw_texture_rect(preload("res://modules/main_menu/assets/background_clean_v2.png"),Rect2(Vector2.ZERO,PAGE_SIZE),false,Color(0.96,0.94,0.90))
	if handwriting==null: return
	for row in 25:
		var size:=23+(row%3)
		var text: String=PHRASES[(row*3)%PHRASES.size()]
		var part:=1
		while handwriting.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<1610.0:
			text+="  "+PHRASES[(row*3+part)%PHRASES.size()]
			part+=1
		var start:=Vector2(85.0+sin(row*1.7)*15.0,70.0+row*39.0+sin(row*2.3)*2.0)
		draw_set_transform(start,deg_to_rad(-0.65+sin(row*1.2)*0.20))
		draw_string(handwriting,Vector2.ZERO,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0.43,0.34,0.23,0.62))
	draw_set_transform(Vector2.ZERO)
