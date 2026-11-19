extends RefCounted
## Shared preferences. Gameplay values, lighting and geometry stay with their owners.
static var path := "user://game_settings.cfg"
static var loaded := false
static var aspect := 0
static var quality := 2
static var volume := 1.0
static var sensitivity := 1.0
const CursorRuntime:=preload("res://modules/game_hud/hand_cursor.gd")
static var cursor: ImageTexture
static func ensure_loaded() -> void:
    if loaded:return
    loaded=true
    var config:=ConfigFile.new()
    if config.load(path)!=OK:return
    aspect=clampi(int(config.get_value("display","aspect",0)),0,1)
    quality=clampi(int(config.get_value("display","quality",2)),0,2)
    volume=clampf(float(config.get_value("audio","volume",1.0)),0.0,1.0)
    sensitivity=clampf(float(config.get_value("input","sensitivity",1.0)),0.25,2.0)
static func snapshot() -> Dictionary:
    ensure_loaded()
    return {"aspect":aspect,"quality":quality,"volume":volume,"sensitivity":sensitivity}
static func change(key: String, value: float) -> void:
    match key:
        "aspect":aspect=clampi(int(value),0,1)
        "quality":quality=clampi(int(value),0,2)
        "volume":volume=clampf(value,0.0,1.0)
        "sensitivity":sensitivity=clampf(value,0.25,2.0)
    var config:=ConfigFile.new()
    config.set_value("display","aspect",aspect)
    config.set_value("display","quality",quality)
    config.set_value("audio","volume",volume)
    config.set_value("input","sensitivity",sensitivity)
    config.save(path)
static func apply(level: Control) -> void:
    ensure_loaded()
    level.get_window().content_scale_size=Vector2i(1920,1080 if aspect==0 else 1200)
    level.get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
    var container: SubViewportContainer=level.get_node("%ViewportContainer")
    container.stretch_shrink=2 if quality==0 else 1
    var viewport: SubViewport=level.get_node("%Player").get_viewport()
    viewport.msaa_3d=Viewport.MSAA_2X if quality==2 else Viewport.MSAA_DISABLED
    AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,volume)))
    AudioServer.set_bus_mute(0,volume<=0.0)
    var controller: Node=CursorRuntime.install(level.get_window())
    cursor=controller.frames[0]
