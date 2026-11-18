extends Control
const Art := preload("res://modules/game_hud/assets.gd")
const Regions := preload("res://assets/UI/HUD/v2/regions.gd")
var meter: TextureRect
var rays: Array[TextureRect] = []
var ratio := 1.0
var displayed_ratio := 1.0
var active := false
var age := 0.0
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var dimensions:=Vector2(size.x,size.x*Regions.SOURCE_SIZE.y/Regions.SOURCE_SIZE.x)
    var origin:=Vector2(0,(size.y-dimensions.y)*0.5)
    meter=Art.picture(self,Art.texture("v2/derived/energy.png"),Rect2(origin,dimensions))
    meter.name="EnergyMeter"
    var paint:=ShaderMaterial.new()
    paint.shader=preload("res://modules/game_hud/energy_fill.gdshader")
    paint.set_shader_parameter("masks",Art.texture("v2/derived/energy_mask.png"))
    paint.set_shader_parameter("empty_art",Art.texture("v2/derived/energy_empty_reference.png"))
    paint.set_shader_parameter("empty_pill",Regions.EMPTY_PILL)
    for i in 3:paint.set_shader_parameter(["pill_a","pill_b","pill_c"][i],Regions.PILLS[i])
    meter.material=paint
    for i in Regions.RAYS.size():
        var rect: Rect2=Regions.RAYS[i]
        var ray:=Art.picture(self,Art.texture("v2/derived/ray_%d.png"%i),Rect2(origin+rect.position*dimensions.x/Regions.SOURCE_SIZE.x,rect.size*dimensions.x/Regions.SOURCE_SIZE.x))
        ray.material=null
        ray.pivot_offset=ray.size*0.5
        ray.show()
        rays.append(ray)
func set_ratio(value: float) -> void:
    ratio=clampf(value,0.0,1.0)
func set_active(value: bool) -> void:
    active=value
func _process(delta: float) -> void:
    if not get_tree().paused:
        displayed_ratio=lerpf(displayed_ratio,ratio,1.0-exp(-12.0*delta))
        if absf(displayed_ratio-ratio)<0.0001:displayed_ratio=ratio
        age+=delta
    meter.material.set_shader_parameter("fill",displayed_ratio)
    for i in rays.size():
        var ray:=rays[i]
        ray.visible=true
        var pulse:=sin(age*9.0-i*0.9) if active else 0.0
        ray.scale=Vector2.ONE*(1.0+0.11*pulse)
        ray.rotation=0.045*pulse
        ray.modulate.a=0.72+0.28*(pulse*0.5+0.5) if active else 1.0
