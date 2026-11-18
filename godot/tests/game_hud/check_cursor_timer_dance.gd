extends "res://tests/game_hud/check_stamina_ring.gd"
const CursorArt:=preload("res://assets/UI/HUD/hand_cursor/regions.gd")
const OUTPUT:="D:/ChatGPT/献给阿尔吉侬的花束/.verification/cursor-timer/"
var pointer: Node
var pointer_id := 0
func capture_latest(id: String) -> void:
    await process_frame
    RenderingServer.force_draw(false)
    root.get_texture().get_image().save_png(OUTPUT+id+".png")
func run() -> void:
    Input.use_accumulated_input=false
    Preferences.path="user://cursor_timer_test_settings.cfg"
    Preferences.loaded=true
    Preferences.aspect=0
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1920,1080)
    root.position=Vector2i.ZERO
    asset_checks()
    main=load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene=main
    await ticks(8)
    pointer=root.get_node_or_null("HandDrawnCursor")
    check(pointer!=null,"new cursor installed on initial maze selection")
    pointer_id=pointer.get_instance_id()
    for id: String in ["maze","maze02","maze03"]:
        main.show_scene(id)
        await ticks(220 if id!="maze03" else 35)
        bind()
        check(root.get_node("HandDrawnCursor").get_instance_id()==pointer_id,id+" reuses same cursor controller")
        check(pointer.frames.size()==3,id+" three textures cached")
        check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" default mouse look preserved")
        var previous: int=pointer.updates
        await ticks(15)
        check(pointer.updates==previous,id+" captured gameplay does not keep resetting native cursor")
        var timer: Control=hud.get_node("HUDRoot/TopCenterTimer")
        for slot: TextureRect in timer.slots:
            check(slot.texture.resource_path.contains("timer_bold/") and slot.material==null,id+" plain bold timer art without sticker shader")
        check(timer.slots[0].size==Vector2(52,64) and timer.slots[2].size==Vector2(32,64),id+" timer/colon fixed slot dimensions unchanged")
        var positions: Array=[]
        for slot: TextureRect in timer.slots:positions.append(slot.position.x)
        timer.set_time(3599)
        timer.set_time(3600)
        var after: Array=[]
        for slot: TextureRect in timer.slots:after.append(slot.position.x)
        check(positions==after,id+" time changes do not shift horizontal slots")
        await click(hud.get_node("HUDRoot/TopRightMenu/SettingsButton"))
        check(hud.overlay=="settings" and paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,id+" actual settings click with new cursor")
        root.warp_mouse(Vector2(960,760))
        await frames(3)
        var mouse_position: Vector2=root.get_mouse_position()
        var frame: int=pointer.frame
        previous=pointer.updates
        await ticks(12)
        check(pointer.frame!=frame and pointer.updates>previous,id+" hand cursor animates during paused menu")
        check(root.get_mouse_position().is_equal_approx(mouse_position),id+" animation leaves actual pointer position fixed")
        await capture_latest(id+"_settings")
        hud.close_overlay()
        await ticks(4)
        check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" closing menu restores look automatically")
        await capture_latest(id+"_hud")
        await dance_checks(id)
    # Race mode uses the same continuous Charlie clip, in addition to Explore finish checks above.
    var race: Node=level.race
    race.pending_mode="Race"
    level.reset_walk()
    for i in 500:
        if race.state=="RACING":break
        await ticks(1)
    check(race.state=="RACING","race countdown still works")
    actor.global_position=race.recorder.finish_trigger.global_position-Vector3.UP*0.8
    actor.velocity=Vector3.ZERO
    await ticks(8)
    await ticks(270)
    check(actor.visual.celebrating and actor.visual.animation_player.current_animation_position>4.2,"Race Charlie also continues beyond original short section")
    await ticks(170)
    check(race.state=="FINISHED" and adapter.play_flow.result_panel.visible,"race settles after continuous dance")
    var out:=FileAccess.open(OUTPUT+"results.json",FileAccess.WRITE)
    out.store_string(JSON.stringify({"checks":report,"failures":failures},"  "))
    out.close()
    print("CURSOR TIMER DANCE checks=",report.size()," failures=",failures)
    main.queue_free()
    await ticks(5)
    quit(failures)
func asset_checks() -> void:
    var previous: Image
    var hashes: Array=[]
    for i in 3:
        var frame:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/UI/HUD/hand_cursor/derived/frame_%d.png"%i))
        check(frame.get_size()==CursorArt.SIZE,"cursor frame has stable size "+str(i))
        hashes.append(hash(frame.get_data()))
        if previous!=null:
            var changed:=0
            var tip_changed:=0
            for y in frame.get_height():
                for x in frame.get_width():
                    if frame.get_pixel(x,y)==previous.get_pixel(x,y):continue
                    changed+=1
                    if Vector2(x,y).distance_to(CursorArt.HOTSPOT)<=8.0:tip_changed+=1
            check(changed>100 and tip_changed==0,"cursor changes contour/body while tip region is identical "+str(i))
        previous=frame
    check(hashes[0]!=hashes[1] and hashes[1]!=hashes[2],"three cursor frames visually distinct")
    var closed_samples:=0
    for i in 11:
        var name: String="colon" if i==10 else "digit_"+str(i)
        var plain:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/UI/HUD/timer_bold/"+name+".png"))
        var original:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/UI/HUD/slices/"+name+".png"))
        var white:=0
        var inconsistent:=0
        var dark_before:=0
        var dark_after:=0
        check(plain.get_size()==original.get_size(),name+" source proportions unchanged")
        for y in plain.get_height():
            for x in plain.get_width():
                var a:=plain.get_pixel(x,y)
                var b:=original.get_pixel(x,y)
                if a.a>0.01:
                    if a.r>0.6 or a.g>0.6 or a.b>0.6:white+=1
                    if absf(a.r-76.0/255.0)>0.005 or absf(a.g-61.0/255.0)>0.005 or absf(a.b-47.0/255.0)>0.005:inconsistent+=1
                if b.a>0.99 and b.r<0.6:dark_before+=1
                if a.a>0.99:dark_after+=1
                if b.a<0.9 and a.a>0.99:closed_samples+=1
        check(white==0 and inconsistent==0,name+" entirely uniform dark brown without white veins")
        check(dark_after>dark_before*1.15,name+" bold stroke occupies former white outline")
    check(closed_samples>0,"fine internal alpha seams filled")
func dance_checks(id: String) -> void:
    if id!="maze03":
        for gate in level.get_node("%GeneratedMaze").gates.values():gate.set_open_state(true)
    var exit: Area3D=level.race.recorder.finish_trigger if id=="maze03" else actor.get_parent().get_node("ExitTrigger")
    actor.global_position=exit.global_position-Vector3.UP*0.8
    actor.velocity=Vector3.ZERO
    await ticks(8)
    var player: AnimationPlayer=actor.visual.animation_player
    var source: Animation=player.get_animation(&"Dance")
    check(source.length>20.0 and source.loop_mode==Animation.LOOP_NONE,id+" original long dance retained and non-looping")
    check(actor.visual.celebrating and player.current_animation==&"Dance",id+" actual exit triggers Charlie dance")
    var previous: float=player.current_animation_position
    var wraps:=0
    for i in 410:
        await ticks(1)
        if player.current_animation==&"Dance":
            var at: float=player.current_animation_position
            if at+0.01<previous:wraps+=1
            previous=at
        if i==270:await capture_latest(id+"_dance_after_4s")
    check(wraps==0 and player.current_animation_position>6.7,id+" original animation progresses continuously past6.7s without repeating")
    check(actor.visual.celebrating and not adapter.play_flow.result_panel.visible,id+" full new duration preserved before poster")
    await ticks(28)
    check(not actor.visual.celebrating and adapter.play_flow.result_panel.visible,id+" dance completes at7.2seconds then shows result")
    await capture_latest(id+"_completed")
