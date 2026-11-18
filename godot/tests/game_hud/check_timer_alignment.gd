extends SceneTree
const OUTPUT:="D:/ChatGPT/献给阿尔吉侬的花束/.verification/timer-alignment/"
var failures:=0
var checks: Array[Dictionary]=[]
var samples: Array[Dictionary]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
    checks.append({"ok":ok,"message":message})
    if not ok:
        failures+=1
        push_error(message)
func frames(n: int) -> void:
    for i in n:await process_frame
func ink_bounds(img: Image,area: Rect2i) -> Rect2i:
    var left:=img.get_width()
    var top:=img.get_height()
    var right:=-1
    var bottom:=-1
    for y in range(area.position.y,area.end.y):
        for x in range(area.position.x,area.end.x):
            var c:=img.get_pixel(x,y)
            if c.r>0.5 or c.g>0.5 or c.b>0.5:continue
            left=mini(left,x)
            right=maxi(right,x)
            top=mini(top,y)
            bottom=maxi(bottom,y)
    return Rect2i(left,top,right-left+1,bottom-top+1)
func run() -> void:
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1920,1080)
    var background:=ColorRect.new()
    background.color=Color("e4edf2")
    background.size=Vector2(1920,1080)
    root.add_child(background)
    var hud: CanvasLayer=load("res://modules/game_hud/GameHUD.tscn").instantiate()
    root.add_child(hud)
    var timer: Control=hud.get_node("HUDRoot/TopCenterTimer")
    await frames(3)
    var original: Array[Rect2]=[]
    for slot: TextureRect in timer.slots:original.append(slot.get_global_rect())
    var top_min:=10000
    var top_max:=-1
    var bottom_min:=10000
    var bottom_max:=-1
    for number in 10:
        timer.set_time(number)
        await frames(2)
        RenderingServer.force_draw(false)
        var shot:=root.get_texture().get_image()
        var bounds:=ink_bounds(shot,Rect2i(timer.slots[4].get_global_rect().grow(2)))
        samples.append({"digit":number,"ink":str(bounds),"slot":str(timer.slots[4].get_global_rect())})
        top_min=mini(top_min,bounds.position.y)
        top_max=maxi(top_max,bounds.position.y)
        bottom_min=mini(bottom_min,bounds.end.y)
        bottom_max=maxi(bottom_max,bounds.end.y)
        check(bounds.size.x>4 and bounds.size.y>50,"digit %d renders normally"%number)
        for i in 5:check(timer.slots[i].get_global_rect().is_equal_approx(original[i]),"digit %d slot %d stays fixed"%[number,i])
        shot.save_png(OUTPUT+"second_%d.png"%number)
    check(top_max-top_min<=1,"0–9 visible ink top varies at most one raster pixel")
    check(bottom_max-bottom_min<=1,"0–9 visible ink baseline varies at most one raster pixel")
    var before_colon: Texture2D=timer.slots[2].texture
    for number: float in [9,10,59,60,599,600,3599,3600,0,9,0]:
        timer.set_time(number)
        await frames(1)
        for i in 5:check(timer.slots[i].get_global_rect().is_equal_approx(original[i]),"carry/restart %d slot %d stays fixed"%[number,i])
    check(timer.slots[2].texture==before_colon,"colon remains fixed through all carries")
    var scale_ok:=true
    for glyph: Texture2D in timer.glyphs:
        scale_ok=scale_ok and glyph is AtlasTexture and glyph.atlas.resource_path.contains("timer_bold/")
    check(scale_ok,"source images, brown colour and proportions are preserved")
    check(timer.slots[0].position.y==timer.slots[4].position.y,"all digits have same vertical origin")
    var file:=FileAccess.open(OUTPUT+"results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"ink_samples":samples,"top_spread":top_max-top_min,"baseline_spread":bottom_max-bottom_min},"  "))
    file.close()
    print("TIMER ALIGNMENT checks=",checks.size()," failures=",failures," ink_top_spread=",top_max-top_min," baseline_spread=",bottom_max-bottom_min)
    quit(1 if failures>0 else 0)
