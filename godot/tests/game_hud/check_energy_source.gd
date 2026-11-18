extends SceneTree
const Art:=preload("res://modules/game_hud/assets.gd")
const Regions:=preload("res://assets/UI/HUD/v2/regions.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1200,600)
    var viewport:=SubViewport.new()
    viewport.size=Vector2i(Regions.SOURCE_SIZE)
    viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var picture:=TextureRect.new()
    picture.texture=Art.texture("v2/derived/energy.png")
    picture.size=Regions.SOURCE_SIZE
    var paint:=ShaderMaterial.new()
    paint.shader=preload("res://modules/game_hud/energy_fill.gdshader")
    paint.set_shader_parameter("masks",Art.texture("v2/derived/energy_mask.png"))
    paint.set_shader_parameter("empty_art",Art.texture("v2/derived/energy_empty_reference.png"))
    paint.set_shader_parameter("empty_pill",Regions.EMPTY_PILL)
    for i in 3:paint.set_shader_parameter(["pill_a","pill_b","pill_c"][i],Regions.PILLS[i])
    paint.set_shader_parameter("fill",2.0/3.0)
    picture.material=paint
    viewport.add_child(picture)
    for i in 5:await process_frame
    RenderingServer.force_draw(false)
    var rendered:=viewport.get_texture().get_image()
    var source:=picture.texture.get_image()
    var masks: Image=Art.texture("v2/derived/energy_mask.png").get_image()
    var differences:=0
    var compared:=0
    for y in source.get_height():
        for x in source.get_width():
            var a:=source.get_pixel(x,y)
            if a.a<0.99:continue
            var mask: Color=masks.get_pixel(x,y)
            if maxf(mask.r,maxf(mask.g,mask.b))>0.01:continue
            var b:=rendered.get_pixel(x,y)
            compared+=1
            if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>0.025:differences+=1
    print("ENERGY FRAME SOURCE COMPARE opaque_pixels=",compared," changed_pixels=",differences)
    rendered.save_png("D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/energy_original_fill_v2.png")
    viewport.queue_free()
    await process_frame
    quit(0 if differences<compared*0.002 else 1)
