extends "res://tests/game_hud/check_maze03_cakes_mouse.gd"
const Preferences:=preload("res://modules/game_hud/game_settings.gd")
func double_click() -> void:
    var click_event:=InputEventMouseButton.new()
    click_event.button_index=MOUSE_BUTTON_LEFT
    click_event.pressed=true
    click_event.double_click=true
    click_event.position=Vector2(1000,700)
    click_event.global_position=click_event.position
    Input.parse_input_event(click_event)
    await frames(2)
    click_event=InputEventMouseButton.new()
    click_event.button_index=MOUSE_BUTTON_LEFT
    click_event.pressed=false
    Input.parse_input_event(click_event)
    await frames(2)
func run() -> void:
    Input.use_accumulated_input=false
    Preferences.path="user://hud_v2_test.cfg"
    Preferences.loaded=true
    Preferences.aspect=0
    Preferences.quality=2
    Preferences.sensitivity=1.0
    Preferences.volume=1.0
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1920,1080)
    root.position=Vector2i.ZERO
    main=load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene=main
    for id: String in ["maze","maze02","maze03"]:
        main.show_scene(id)
        await ticks(12)
        bind()
        root.grab_focus()
        adapter.mouse_look._focus_gained()
        if id!="maze03":
            check(not actor.controls_enabled and adapter.clock.elapsed==0.0,id+" countdown locks movement and timer")
            check(adapter.play_flow.countdown.text=="3",id+" countdown starts at3")
            await shot(id+"_countdown_v2")
            await ticks(190)
            check(actor.controls_enabled and adapter.clock.elapsed>0.0,id+" GO unlocks and starts clock")
        check(not hud.has_node("HUDRoot/TopLeftCompass"),id+" compass removed")
        var menu:=hud.get_node("HUDRoot/TopRightMenu")
        check(menu.get_child_count()==3,id+" three supplied menu buttons")
        check(menu.get_child(2).name==&"SettingsButton",id+" settings button identified")
        for button: Button in menu.get_children():
            var optical: Rect2=button.get_node("Sticker").get_meta(&"optical_bounds")
            check(is_equal_approx(optical.size.y,64.0) and is_equal_approx(optical.position.y,8.0),id+" menu glyph equal optical height/top "+button.name)
        var rig:=level.get_node("%FollowRig")
        print("DEFAULT CAMERA ",id," distance=",rig.distance," pitch=",rig.pitch)
        check(is_equal_approx(rig.distance,7.0) and is_equal_approx(rig.pitch,0.45),id+" shared distant default camera")
        adapter.mouse_look._skip_capture_warp=false
        var yaw_before: float=rig.yaw
        move_mouse(Vector2(20,0))
        await ticks(2)
        check(absf(angle_difference(yaw_before,rig.yaw)+0.05)<0.012,id+" reduced default sensitivity and single mouse delivery")
        await double_click()
        check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,id+" actual double-click releases pointer")
        yaw_before=rig.yaw
        move_mouse(Vector2(20,0))
        await ticks(2)
        check(is_equal_approx(yaw_before,rig.yaw),id+" free pointer does not turn camera")
        root.warp_mouse(Vector2(1000,700))
        await frames(2)
        await double_click()
        check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" double-click blank gameplay recaptures")
        var stamina=hud.get_node("HUDRoot/BottomLeftStamina")
        check(stamina.rays.size()==3,id+" three separately animated rays")
        actor.move_speed_multiplier=1.0
        actor.sprint_toggled=false
        adapter._stamina_changed()
        await frames(2)
        check(stamina.rays[0].visible and stamina.rays[0].scale.is_equal_approx(Vector2.ONE),id+" walking keeps three static rays")
        actor.stamina.current=50.0
        adapter._stamina_changed()
        var previous: float=stamina.displayed_ratio
        await frames(1)
        check(stamina.displayed_ratio<previous and stamina.displayed_ratio>0.5,id+" energy drains smoothly")
        await ticks(35)
        check(absf(stamina.displayed_ratio-0.5)<0.1,id+" energy follows real stamina")
        await boost_checks(id)
        await settings_checks(id)
        check(hud.get_node("HUDRoot/StatusEffects").position.x==stamina.position.x,id+" states align to meter left edge")
        rig.reset_view()
        await ticks(10)
        await shot(id+"_v2_gameplay")
        hud.show_notification({"title":"巧克力蛋糕","description":"体力恢复 · 短暂加速","icon":"cake"})
        await ticks(15)
        var notice: Control=hud.get_node("HUDRoot/CenterBottomNotification")
        check(notice.size.x==520 and notice.position.y<890,id+" shorter notification centered higher")
        if id=="maze03":await shot("notification_v2")
        if id!="maze03":await finish_checks(id)
    await cake_checks()
    await explore3_finish()
    if "--race" in OS.get_cmdline_user_args():await race_checks()
    var file:=FileAccess.open(OUT+"hud-v2-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"checks":report,"mouse_arrivals":arrivals},"  "))
    file.close()
    print("HUD V2 checks=",report.size()," failures=",failures," arrivals=",arrivals)
    main.queue_free()
    await ticks(5)
    quit(failures)
func boost_checks(id: String) -> void:
    actor.move_speed_multiplier=1.3
    actor.sprint_toggled=false
    actor.stamina.current=40
    actor.stamina.since_sprint=0.0
    var before: float=actor.stamina.current
    await ticks(5)
    check(actor._has_free_sprint() and actor.stamina.current>=before,id+" cake grants free sprint")
    actor.position=actor.spawn_point
    actor.velocity=Vector3.ZERO
    hold(KEY_W,true)
    await ticks(10)
    var free_speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
    check(absf(free_speed-3.51)<0.03,id+" walking input actually receives cake running speed")
    actor.sprint_toggled=true
    await ticks(8)
    var sprint_speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
    check(absf(sprint_speed-free_speed)<0.03 and actor.stamina.current>=before,id+" sprint input gets same speed with no stamina cost")
    hold(KEY_W,false)
    actor.sprint_toggled=false
    actor.velocity=Vector3.ZERO
    actor.position=actor.spawn_point
    check(is_equal_approx(actor._movement_modifier(),1.3),id+" cake modifier remains1.3")
    adapter._stamina_changed()
    await frames(2)
    var rays: Array=hud.get_node("HUDRoot/BottomLeftStamina").rays
    check(rays[0].visible,id+" cake activates moving rays")
    var scale_before: Vector2=rays[0].scale
    await ticks(10)
    check(not rays[0].scale.is_equal_approx(scale_before),id+" rays have motion")
    if id=="maze03":
        actor.apply_boost()
        check(is_equal_approx(actor._movement_modifier(),1.35),"barrier and cake choose maximum instead of multiplication")
        actor.boost_remaining=0.0
    actor.move_speed_multiplier=1.0
    actor.stamina.current=actor.stamina.settings.maximum
func settings_checks(id: String) -> void:
    await click(hud.get_node("HUDRoot/TopRightMenu/SettingsButton"))
    check(hud.overlay=="settings" and paused,id+" actual settings click pauses")
    var controls: Dictionary=hud.setting_controls
    controls.aspect.item_selected.emit(1)
    await frames(8)
    check(root.content_scale_size==Vector2i(1920,1200),id+" 16:10 actual logical canvas")
    check(absf(hud.get_node("HUDRoot").size.y-1200)<2,id+" HUD adapts to 16:10")
    check(root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_KEEP,id+" preserve aspect without stretching")
    controls.quality.item_selected.emit(0)
    check(level.get_node("%ViewportContainer").stretch_shrink==2 and actor.get_viewport().msaa_3d==Viewport.MSAA_DISABLED,id+" low quality changes real render resolution")
    controls.quality.item_selected.emit(1)
    check(level.get_node("%ViewportContainer").stretch_shrink==1 and actor.get_viewport().msaa_3d==Viewport.MSAA_DISABLED,id+" medium retains resolution without AA")
    controls.quality.item_selected.emit(2)
    controls.volume.value=35
    check(absf(db_to_linear(AudioServer.get_bus_volume_db(0))-0.35)<0.01,id+" actual master volume")
    controls.sensitivity.value=0.5
    check(is_equal_approx(Preferences.sensitivity,0.5),id+" sensitivity binds actual preference")
    if id=="maze03":
        await process_frame
        RenderingServer.force_draw(false)
        root.get_texture().get_image().save_png(OUT+"settings_16x10_v2.png")
    controls.aspect.item_selected.emit(0)
    controls.volume.value=100
    controls.sensitivity.value=1.0
    await frames(5)
    if id=="maze03":await shot("settings_v2")
    hud.close_overlay()
    await ticks(2)
    check(not paused,id+" closing settings resumes")
    check(Preferences.cursor!=null and Preferences.cursor.get_height()==44,id+" supplied custom cursor loaded")
func finish_checks(id: String) -> void:
    for gate in level.get_node("%GeneratedMaze").gates.values():gate.set_open_state(true)
    level.complete_level()
    await ticks(10)
    check(actor.visual.celebrating,id+" Charlie dances at finish")
    await ticks(270)
    check(actor.visual.celebrating,id+" dance extends beyond original4.2seconds")
    check(not adapter.play_flow.result_panel.visible,id+" result waits for dance")
    await ticks(165)
    check(not actor.visual.celebrating and adapter.play_flow.result_panel.visible,id+" full7.2second dance followed by poster")
    check(adapter.play_flow.result_title.text=="完成",id+" completion poster wording")
    await shot(id+"_completed_v2")

func explore3_finish() -> void:
    level.reset_walk()
    await ticks(4)
    actor.position=level.race.recorder.finish_trigger.global_position-Vector3.UP*0.8
    actor.velocity=Vector3.ZERO
    await ticks(10)
    check(actor.visual.celebrating,"Maze03 Explore Charlie dances on actual exit entry")
    await ticks(440)
    check(adapter.play_flow.result_panel.visible and adapter.play_flow.result_title.text=="完成","Maze03 Explore completion poster")
    level.reset_walk()
    await ticks(4)
    check(not adapter.play_flow.result_panel.visible and not actor.visual.celebrating,"reset removes result and celebration")
