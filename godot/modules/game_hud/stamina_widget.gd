extends Control
## Shared authored-art ring. Progress, color and lightning motion are independent.
const Art := preload("res://modules/game_hud/assets.gd")
const Regions := preload("res://assets/UI/HUD/stamina_ring/regions.gd")
var meter: TextureRect
var lightning: TextureRect
var ratio := 1.0
var displayed_ratio := 1.0
var running := false
var boosted := false
var boost_mix := 0.0
var age := 0.0
var activation_age := 1.0
var _boost_serial := 0
var _line_frame := -1
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var dimensions:=Vector2(size.x,size.x*Regions.SOURCE_SIZE.y/Regions.SOURCE_SIZE.x)
    var origin:=Vector2(0,(size.y-dimensions.y)*0.5)
    meter=Art.picture(self,Art.texture("stamina_ring/derived/base.png"),Rect2(origin,dimensions))
    meter.name="PaintedStaminaRing"
    var paint:=ShaderMaterial.new()
    paint.shader=preload("res://modules/game_hud/stamina_ring.gdshader")
    paint.set_shader_parameter("fill_mask",Art.texture("stamina_ring/derived/masks.png"))
    paint.set_shader_parameter("pigment",Art.texture("stamina_ring/derived/source.png"))
    paint.set_shader_parameter("ring_center",Regions.CENTER)
    paint.set_shader_parameter("art_size",Regions.SOURCE_SIZE)
    paint.set_shader_parameter("start_angle",Regions.START_RADIANS)
    paint.set_shader_parameter("display_size",dimensions)
    meter.material=paint
    lightning=Art.picture(self,Art.texture("stamina_ring/derived/lightning.png"),Rect2(origin,dimensions))
    lightning.name="AuthoredLightning"
    var line_paint:=ShaderMaterial.new()
    line_paint.shader=preload("res://modules/game_hud/stamina_lightning.gdshader")
    line_paint.set_shader_parameter("masks",Art.texture("stamina_ring/derived/masks.png"))
    line_paint.set_shader_parameter("display_size",dimensions)
    lightning.material=line_paint
    lightning.pivot_offset=Regions.BOLT_PIVOT*dimensions
func set_state(data: Dictionary) -> void:
    set_ratio(data.ratio)
    running=data.running
    boosted=data.boosted
    var serial: int=data.boost_serial
    if serial!=_boost_serial and boosted:activation_age=0.0
    _boost_serial=serial
    if not running and activation_age>=0.45:lightning.scale=Vector2.ONE
func set_ratio(value: float) -> void:
    ratio=clampf(value,0.0,1.0)
func set_active(value: bool) -> void:
    running=value
func reset_state() -> void:
    ratio=1.0
    displayed_ratio=1.0
    running=false
    boosted=false
    boost_mix=0.0
    activation_age=1.0
    _boost_serial=0
    lightning.scale=Vector2.ONE
func _process(delta: float) -> void:
    if not get_tree().paused:
        displayed_ratio=lerpf(displayed_ratio,ratio,1.0-exp(-14.0*delta))
        boost_mix=lerpf(boost_mix,1.0 if boosted else 0.0,1.0-exp(-16.0*delta))
        if absf(displayed_ratio-ratio)<0.0002:displayed_ratio=ratio
        if absf(boost_mix-(1.0 if boosted else 0.0))<0.0002:boost_mix=1.0 if boosted else 0.0
        age+=delta
        activation_age+=delta
    var line_frame:=int(floor(age*8.0))%3
    if line_frame!=_line_frame:
        _line_frame=line_frame
        meter.material.set_shader_parameter("line_frame",line_frame)
        lightning.material.set_shader_parameter("line_frame",line_frame)
    var activation:=maxf(0.0,1.0-activation_age/0.45)
    meter.material.set_shader_parameter("fill",displayed_ratio)
    meter.material.set_shader_parameter("boosted",boost_mix)
    meter.material.set_shader_parameter("activation",activation)
    meter.material.set_shader_parameter("activation_age",activation_age)
    # The authored ring never moves. Only its lightning has a restrained pulse.
    var pulse:=0.006*(1.0+sin(age*11.0)) if running else 0.0
    var kick:=sin(clampf(activation_age/0.45,0.0,1.0)*PI)*0.023 if activation>0.0 else 0.0
    lightning.scale=Vector2.ONE*(1.0+pulse+kick)
