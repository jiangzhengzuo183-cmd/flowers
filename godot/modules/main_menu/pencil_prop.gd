extends Node2D
## Visual shaft and its matching capsule. This prop never intercepts button input.
const TEXTURE:=preload("res://modules/main_menu/assets/pencil_handdrawn.png")
var start:=Vector2.ZERO
var tip:=Vector2.ZERO
var half_width:=21.0
var unit:=1.0
var art: Sprite2D
var shadow: Sprite2D
var contact: Sprite2D
func _ready() -> void:
	var texture:=AtlasTexture.new()
	texture.atlas=TEXTURE
	texture.region=Rect2(5,250,2157,236)
	texture.filter_clip=true
	shadow=Sprite2D.new()
	shadow.texture=texture
	shadow.centered=false
	shadow.material=ShaderMaterial.new()
	shadow.material.shader=preload("res://modules/main_menu/pencil_shadow.gdshader")
	shadow.material.set_shader_parameter("blur_radius",15.0)
	shadow.material.set_shader_parameter("opacity",0.19)
	add_child(shadow)
	contact=Sprite2D.new()
	contact.texture=texture
	contact.centered=false
	contact.material=ShaderMaterial.new()
	contact.material.shader=preload("res://modules/main_menu/pencil_shadow.gdshader")
	contact.material.set_shader_parameter("blur_radius",4.0)
	contact.material.set_shader_parameter("opacity",0.34)
	add_child(contact)
	art=Sprite2D.new()
	art.texture=texture
	art.centered=false
	art.material=ShaderMaterial.new()
	art.material.shader=preload("res://modules/main_menu/pencil_ink.gdshader")
	art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shadow.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	contact.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(art)
func place(paper: Rect2) -> void:
	unit=paper.size.x/1920.0
	start=paper.position+Vector2(40,1960)*unit
	tip=paper.position+Vector2(310,675)*unit
	position=start
	var length:=start.distance_to(tip)
	var scale_factor:=length/2093.0
	for sprite in [shadow,contact,art]:
		sprite.offset=Vector2(-32,-116.5)
		sprite.scale=Vector2.ONE*scale_factor
		sprite.rotation=(tip-start).angle()
	shadow.position=Vector2(4.0,6.0)*unit
	contact.position=Vector2(1.0,1.7)*unit
	half_width=169.0*scale_factor*0.5
func distance_to_shaft(at: Vector2) -> float:
	return at.distance_to(Geometry2D.get_closest_point_to_segment(at,start,tip))
func contains(at: Vector2,margin: float=0.0) -> bool:
	return distance_to_shaft(at)<=half_width+margin
func would_cross(at: Vector2,velocity: Vector2) -> bool:
	if velocity.length()<18.0*unit: return false
	var axis:=(tip-start).normalized()
	var forward:=velocity.normalized()
	# Parallel travel alongside the pencil must not trigger a hop.
	if absf(axis.cross(forward))<0.32: return false
	var reach:=at+forward*velocity.length()*0.36
	var crossing: Variant=Geometry2D.segment_intersects_segment(at,reach,start,tip)
	return crossing!=null or contains(at,5.0*unit)
func blocks_gnaw(at: Vector2,radius: float=0.0) -> bool:
	return contains(at,radius+5.0*unit)
