extends "res://tests/game_hud/check_clicks.gd"
const Ring:=preload("res://modules/game_hud/stamina_widget.gd")
const RingArt:=preload("res://assets/UI/HUD/stamina_ring/regions.gd")
const Preferences:=preload("res://modules/game_hud/game_settings.gd")
const DEST:="D:/ChatGPT/献给阿尔吉侬的花束/.verification/stamina-ring/"
var ring: Control
var fixture: SubViewport
var fixture_ring: Control
func hold(key: Key, down: bool) -> void:
    var event:=InputEventKey.new()
    event.physical_keycode=key
    event.pressed=down
    Input.parse_input_event(event)
func capture(id: String) -> void:
    await process_frame
    RenderingServer.force_draw(false)
    root.get_texture().get_image().save_png(DEST+id+".png")
func run() -> void:
    Input.use_accumulated_input=false
    Preferences.path="user://ring_test_settings.cfg"
    Preferences.loaded=true
    Preferences.aspect=0
    Preferences.quality=2
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1920,1080)
    root.position=Vector2i.ZERO
    await pixel_checks()
    main=load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene=main
    for id: String in ["maze","maze02","maze03"]:
        main.show_scene(id)
        await ticks(220 if id!="maze03" else 35)
        bind()
        ring=hud.get_node("HUDRoot/BottomLeftStamina")
        check(ring.size==Vector2(200,200),id+" same prominent 200px ring")
        check(ring.position==Vector2(40,840),id+" common position and inventory bottom baseline")
        check(not ring.boosted and ring.boost_mix<0.01,id+" no previous scene blue state")
        check(ring.get_script()==Ring,id+" same shared component")
        check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" enters with mouse look without click")
        check(hud.get_node("HUDRoot/StatusEffects").position.x>=ring.get_rect().end.x+24,id+" states do not overlap ring")
        await movement_checks(id)
        await menu_checks(id)
        await cake_checks(id)
        if id=="maze03":await overlap_checks()
        else:
            while level._perks.boost_remaining>0.15:await ticks(1)
            actor.position=actor.spawn_point
            actor.stamina.current=60.0
            actor.sprint_toggled=true
            hold(KEY_W,true)
            await ticks(30)
            hold(KEY_W,false)
            actor.sprint_toggled=false
            check(actor.stamina.current<60.0,id+" boost ending during sprint resumes original stamina drain")
            await ticks(25)
            check(not ring.boosted and ring.boost_mix<0.01,id+" natural cake expiry returns yellow")
            adapter.inventory.grant(&"ChocolateCake")
            adapter.inventory.select_item(&"ChocolateCake")
            await tap(KEY_E)
            await ticks(25)
            check(ring.boosted,id+" leave level with active boost to verify next scene reset")
    level.reset_walk()
    await ticks(35)
    check(not ring.boosted and ring.boost_mix<0.01,"reset clears boost color with actual effect timers")
    var output:=FileAccess.open(DEST+"results.json",FileAccess.WRITE)
    output.store_string(JSON.stringify({"checks":report,"failures":failures},"  "))
    output.close()
    print("STAMINA RING checks=",report.size()," failures=",failures)
    main.queue_free()
    await ticks(5)
    quit(failures)
func pixel_checks() -> void:
    fixture=SubViewport.new()
    fixture.size=Vector2i(RingArt.SOURCE_SIZE)
    fixture.transparent_bg=true
    fixture.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(fixture)
    fixture_ring=Ring.new()
    fixture_ring.size=RingArt.SOURCE_SIZE
    fixture.add_child(fixture_ring)
    await frames(4)
    fixture_ring.set_process(false)
    var mask: Image=load("res://assets/UI/HUD/stamina_ring/derived/masks.png").get_image()
    var base: Image=load("res://assets/UI/HUD/stamina_ring/derived/base.png").get_image()
    var source: Image=load("res://assets/UI/HUD/stamina_ring/derived/source.png").get_image()
    for value: float in [0.0,0.25,0.5,0.75,1.0]:
        var img: Image=await render_fixture(value,false)
        var bad_outside:=0
        var bad_progress:=0
        var compared:=0
        var ring_pixels:=0
        var colored:=0
        var dirty_empty:=0
        for y in range(2,img.get_height()-2,3):
            for x in range(2,img.get_width()-2,3):
                var at:=Vector2i(x,y)
                var region:=mask.get_pixelv(at)
                region*=region.a
                var result:=img.get_pixelv(at)
                var expected:=base.get_pixelv(at)
                if expected.a<0.99:continue
                if region.r<0.01:
                    compared+=1
                    var original:=source.get_pixelv(at)
                    if maxf(absf(result.r-original.r),maxf(absf(result.g-original.g),absf(result.b-original.b)))>0.025:bad_outside+=1
                    continue
                if region.r<0.99:continue
                ring_pixels+=1
                var delta:=Vector2(x,y)-RingArt.CENTER*RingArt.SOURCE_SIZE
                var turn:=fposmod(atan2(delta.y,delta.x)-RingArt.START_RADIANS,TAU)/TAU
                if absf(turn-value)<0.006:continue
                var yellow:=result.r>0.75 and result.g>0.55 and result.b<0.5
                if yellow:colored+=1
                if yellow!=(turn<value):bad_progress+=1
                if value==0.0 and (absf(result.r-246.0/255.0)>0.02 or absf(result.g-229.0/255.0)>0.02 or absf(result.b-208.0/255.0)>0.02):dirty_empty+=1
        print("PIXEL FILL ",value," out=",bad_outside," progress=",bad_progress," dirty=",dirty_empty," painted=",float(colored)/ring_pixels)
        check(bad_outside==0,"fill "+str(value)+" preserves authored contour/lightning/background: "+str(bad_outside))
        check(bad_progress<10,"fill "+str(value)+" clockwise mask follows true progress: "+str(bad_progress))
        check(absf(float(colored)/ring_pixels-value)<0.09,"fill "+str(value)+" approximate correct painted area")
        if value==0.0:check(dirty_empty==0,"empty band clean cream without dots")
        img.save_png(DEST+"ring_yellow_%03d.png"%roundi(value*100))
    var blue: Image=await render_fixture(0.5,true)
    var blue_count:=0
    for y in range(2,blue.get_height()-2,3):
        for x in range(2,blue.get_width()-2,3):
            if mask.get_pixel(x,y).r*mask.get_pixel(x,y).a>0.99:
                var color:=blue.get_pixel(x,y)
                if color.b>0.7 and color.g>0.6 and color.r<0.7:blue_count+=1
    check(blue_count>9000,"blue uses original band area, not a thin circular line")
    blue.save_png(DEST+"ring_blue_050.png")
    var stable: Image=await render_fixture(0.5,true)
    var changed_contour:=0
    var changed_core:=0
    fixture_ring.meter.material.set_shader_parameter("line_frame",1)
    fixture_ring.lightning.material.set_shader_parameter("line_frame",1)
    await frames(2)
    RenderingServer.force_draw(false)
    var moving:=fixture.get_texture().get_image()
    for y in range(5,moving.get_height()-5,2):
        for x in range(5,moving.get_width()-5,2):
            var a:=stable.get_pixel(x,y)
            var b:=moving.get_pixel(x,y)
            if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))<0.025:continue
            var region:=mask.get_pixel(x,y)
            var core: bool=region.r*region.a>0.99
            for offset: Vector2i in [Vector2i(-4,0),Vector2i(4,0),Vector2i(0,-4),Vector2i(0,4)]:
                var sample:=mask.get_pixel(x+offset.x,y+offset.y)
                core=core and sample.r*sample.a>0.99
            if core:changed_core+=1
            else:changed_contour+=1
    check(changed_contour>500 and changed_core<15,"three-frame line boil affects contour while fill interior stays stable")
    fixture.queue_free()
    await frames(3)
func render_fixture(value: float, blue: bool) -> Image:
    fixture_ring.set_state({"ratio":value,"running":false,"boosted":blue,"boost_serial":0})
    fixture_ring.displayed_ratio=value
    fixture_ring.boost_mix=1.0 if blue else 0.0
    fixture_ring.activation_age=1.0
    fixture_ring.age=0.0
    fixture_ring._process(0.0)
    await frames(2)
    RenderingServer.force_draw(false)
    return fixture.get_texture().get_image()
func movement_checks(id: String) -> void:
    var stamina=actor.stamina
    check(stamina.settings.maximum==100 and stamina.settings.sprint_cost_per_second==18 and stamina.settings.recovery_per_second==14 and stamina.settings.recovery_delay==0.9,id+" balance unchanged")
    actor.position=actor.spawn_point
    actor.sprint_toggled=false
    stamina.current=75
    stamina.since_sprint=0
    hold(KEY_W,true)
    await ticks(10)
    check(not ring.running,id+" walk has stable lightning")
    var before: float=stamina.current
    await tap(KEY_SHIFT)
    await ticks(15)
    check(stamina.current<before-3 and ring.running,id+" actual run drains stamina and animates lightning")
    check(ring.displayed_ratio>ring.ratio and ring.displayed_ratio-ring.ratio<0.05,id+" continuous smoothly following drain")
    await tap(KEY_SHIFT)
    hold(KEY_W,false)
    await ticks(3)
    check(not ring.running and ring.lightning.scale.is_equal_approx(Vector2.ONE),id+" stop run immediately stops lightning pulse")
    var position_before: Vector2=ring.position
    var frame_before: int=ring._line_frame
    await ticks(9)
    check(ring.position==position_before and ring._line_frame!=frame_before,id+" idle line boil changes frame without moving widget")
    before=stamina.current
    await ticks(85)
    check(stamina.current>before and not ring.running,id+" original delayed recovery updates ring")
    stamina.current=0
    actor.controls_enabled=false
    adapter._stamina_changed()
    await ticks(40)
    check(ring.ratio==0 and ring.displayed_ratio==0,id+" exhausted ring reaches exact zero")
    actor.controls_enabled=true
    stamina.restore(60,&"test")
    actor.position=actor.spawn_point
    await ticks(35)
    await capture(id+"_walking_ring")
func menu_checks(id: String) -> void:
    adapter.mouse_look.release_cursor()
    await frames(2)
    await click(hud.get_node("HUDRoot/TopRightMenu/SettingsButton"))
    check(paused and hud.overlay=="settings" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,id+" settings opens with pointer")
    hud.close_overlay()
    await ticks(3)
    check(not paused and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" close top-right menu recaptures even after manual pointer release")
    var rig:=level.get_node("%FollowRig")
    adapter.mouse_look._skip_capture_warp=false
    var before: float=rig.yaw
    var motion:=InputEventMouseMotion.new()
    motion.relative=Vector2(12,0)
    Input.parse_input_event(motion)
    await ticks(2)
    check(absf(angle_difference(before,rig.yaw)+0.03)<0.012,id+" resumed mouse motion turns camera without button")
    rig.reset_view()
func cake_checks(id: String) -> void:
    var effects: Node=level._perks
    var inv: Node=adapter.inventory
    inv.clear_items()
    var pickup: Area3D=null
    for item in effects.pickups:
        if is_instance_valid(item) and item.effect==0:pickup=item;break
    check(pickup!=null,id+" existing cake pickup found")
    actor.position=pickup.position+Vector3.UP*0.03
    actor.velocity=Vector3.ZERO
    await ticks(40)
    check(inv.quantity(&"ChocolateCake")>=1 and effects.boost_remaining==0.0,id+" real pickup stores cake without activating blue")
    inv.select_item(&"ChocolateCake")
    var quantity: int=inv.quantity(&"ChocolateCake")
    await tap(KEY_E)
    await ticks(30)
    check(inv.quantity(&"ChocolateCake")==quantity-1 and effects.boost_remaining>7,id+" actual E use preserves cake duration")
    check(ring.boosted and ring.boost_mix>0.99,id+" cake smoothly reaches shared blue state")
    actor.position=actor.spawn_point
    actor.velocity=Vector3.ZERO
    actor.stamina.current=45
    adapter._stamina_changed()
    await ticks(30)
    check(ring.boost_mix>0.99 and absf(ring.displayed_ratio-actor.stamina.percentage())<0.03 and ring.displayed_ratio<0.7,id+" blue length remains real stamina, not full")
    var before: float=actor.stamina.current
    hold(KEY_W,true)
    await ticks(10)
    check(actor.stamina.current>=before and ring.boosted and ring.running,id+" boosted run remains blue and keeps existing free stamina")
    hold(KEY_W,false)
    actor.velocity=Vector3.ZERO
    actor.position=actor.spawn_point
    hud.clear_notifications()
    hud.show_notification({"title":"使用巧克力蛋糕","description":"体力恢复 · 加速期间不消耗体力","icon":"cake"})
    await ticks(12)
    var notice: Control=hud.get_node("HUDRoot/CenterBottomNotification")
    var midpoint: float=notice.get_global_rect().get_center().x
    check(absf(notice.title.get_global_rect().get_center().x-midpoint)<1 and absf(notice.description.get_global_rect().get_center().x-midpoint)<1,id+" both notification text rows truly centered")
    check(notice.get_theme_stylebox("panel").corner_radius_top_left>=notice.size.y*0.5,id+" notification fully rounded capsule")
    check(notice.find_children("*","TextureRect",true,false).is_empty(),id+" pickup notification has no item illustration")
    check(hud.get_node("HUDRoot/StatusEffects").find_children("*","TextureRect",true,false).is_empty(),id+" status chips have no illustrations")
    await capture(id+"_cake_blue_ring")
func cross_barrier() -> void:
    var barrier: Area3D=level.get_node("%GeneratedMaze").barriers[0]
    actor.position=actor.spawn_point
    await ticks(3)
    for i in 19:
        actor.global_position=barrier.to_global(Vector3(0,0.08,0.90-float(i)*0.10))
        actor.velocity=Vector3.ZERO
        await ticks(1)
    actor.position=actor.spawn_point
    await ticks(4)
func overlap_checks() -> void:
    var effects: Node=level._perks
    while effects.boost_remaining>1.0:await ticks(1)
    var count: int=actor.stamina.restore_counts.get(&"barrier",0)
    await cross_barrier()
    check(actor.boost_remaining>2.0 and actor.stamina.restore_counts.get(&"barrier",0)==count+1,"actual barrier crossing applies boost and existing restore")
    while effects.boost_remaining>0.0:await ticks(1)
    await ticks(12)
    check(actor.boost_remaining>0.0 and ring.boosted and ring.boost_mix>0.99,"cake ending first keeps barrier blue")
    while actor.boost_remaining>0.0:await ticks(1)
    await ticks(35)
    check(not ring.boosted and ring.boost_mix<0.01,"all effects ending restores yellow")
    await cross_barrier()
    adapter.inventory.grant(&"ChocolateCake")
    adapter.inventory.select_item(&"ChocolateCake")
    await tap(KEY_E)
    check(is_equal_approx(actor._movement_modifier(),1.35),"overlap max speed rule unchanged")
    while actor.boost_remaining>0.0:await ticks(1)
    await ticks(12)
    check(effects.boost_remaining>0.0 and ring.boosted and ring.boost_mix>0.99,"barrier ending first keeps cake blue")
    await capture("maze03_overlap_blue_ring")
    while effects.boost_remaining>0.0:await ticks(1)
    await ticks(35)
    check(not ring.boosted and ring.boost_mix<0.01,"second overlap order ends cleanly")
