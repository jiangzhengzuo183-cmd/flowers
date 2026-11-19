extends Control
const Layout := preload("res://modules/game_hud/layout_metrics.gd")
const Art := preload("res://modules/game_hud/assets.gd")
const Regions := preload("res://assets/UI/HUD/slices/compass_regions.gd")
const Needle := preload("res://modules/game_hud/compass.gdshader")
var target_heading := 0.0
var displayed_heading := 0.0
var paint: ShaderMaterial
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var image := Art.picture(self,Art.slice("compass_base"),Rect2(Vector2.ZERO,size))
    Art.align_visible_top(image,0.0,Vector2i(620,680))
    paint=ShaderMaterial.new()
    paint.shader=Needle
    paint.set_shader_parameter("needle_layer",Art.slice("compass_needle"))
    paint.set_shader_parameter("arc_layer",Art.slice("compass_arc"))
    paint.set_shader_parameter("hub_layer",Art.slice("compass_hub"))
    var regions: Dictionary=Regions.REGIONS
    for part: String in ["needle","arc","hub"]:
        var r: Array=regions[part]
        paint.set_shader_parameter(part+"_region",Vector4(r[0],r[1],r[2],r[3]))
    image.material=paint
func set_heading(radians: float) -> void:
    target_heading=radians
func _process(delta: float) -> void:
    displayed_heading=lerp_angle(displayed_heading,target_heading,1.0-exp(-delta*12.0))
    paint.set_shader_parameter("heading",displayed_heading)
