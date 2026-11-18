extends "res://tests/game_hud/check_hud.gd"
func run() -> void:
    Input.use_accumulated_input=false
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1920,1080)
    main=load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene=main
    for id: String in ["maze","maze02","maze03"]:
        main.show_scene(id)
        await ticks(30)
        bind()
        var ui:=hud.get_node("HUDRoot")
        check(ui.get_node("TopRightMenu").get_child_count()==2,id+" only exit and restart")
        check(not ui.get_node("TaskInformation") is Panel,id+" task text has no card")
        check(ui.get_node("BottomLeftStamina").size==ui.get_node("BottomRightInventory").size,id+" equal-size lower widgets")
        check(ui.get_node("BottomRightInventory").size==Vector2(360,124),id+" matched medium-size inventory")
        var unwanted:=false
        for label: Label in ui.find_children("*","Label",true,false):
            if label.is_visible_in_tree() and ("Shift" in label.text or "视线朝" in label.text or "已选中" in label.text or "设置" == label.text):unwanted=true
        check(not unwanted,id+" no persistent explanatory labels")
        var compass:=ui.get_node("TopLeftCompass")
        check(compass.size.x>=300 and compass.size.y>=270,id+" compass is largest individual HUD graphic")
        await shot(id+"_1080")
        actor.controls_enabled=false
        for yaw: float in [0.0,-PI*0.5,PI,PI*0.5]:
            actor.visual.rotation.y=yaw
            await ticks(35)
            var forward: Vector3=-actor.visual.global_basis.z
            var heading:=atan2(forward.x,-forward.z)
            check(absf(angle_difference(compass.target_heading,heading))<0.01,id+" actual character heading "+str(yaw))
            if id=="maze": await check_arc(compass,heading)
        actor.controls_enabled=true
        actor.reset_player()
        level.get_node("%FollowRig").reset_view()
        await ticks(20)
        if id!="maze03":
            var inventory=level._items.inventory
            inventory.grant(&"LuckyRabbitFoot")
            inventory.grant(&"LuckyCoin")
            inventory.grant(&"LuckyHorseshoe")
            var widget:=ui.get_node("BottomRightInventory")
            for i in 3:check(widget.icons[i].texture!=null and widget.backgrounds[i].visible,id+" acquired item retains circular paper slot "+str(i))
            hud.clear_notifications()
            hud.show_notification({"title":"获得 幸运兔脚 ×1","description":"光团提示前方路线","icon":"LuckyRabbitFoot"})
            await ticks(25)
            var notification:=ui.get_node("CenterBottomNotification")
            check(notification.size.y<=56 and notification.position.y>860,id+" compact centered lower notification")
            check(notification.get_theme_stylebox("panel").bg_color.a<0.7,id+" translucent grey notification")
            await shot(id+"_pickup_redesign")
        else:
            hud.open_overlay("debug")
            check(paused,"ESC still pauses")
            hud.settings_music.button_pressed=false
            check(AudioServer.is_bus_mute(AudioServer.get_bus_index("GameHUDMusic")),"music remains operable in ESC")
            hud.settings_music.button_pressed=true
            hud.close_overlay()
            check(not paused,"ESC resumes")
    var file:=FileAccess.open(OUT+"redesign-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"checks":report},"  "))
    file.close()
    print("HUD REDESIGN checks=",report.size()," failures=",failures)
    main.queue_free()
    await ticks(6)
    quit(failures)

func check_arc(compass: Control, expected: float) -> void:
    if DisplayServer.get_name()=="headless":return
    await process_frame
    RenderingServer.force_draw(false)
    var image:=root.get_texture().get_image()
    var source_scale: float=compass.size.x/1312.0
    var pad_y: float=(compass.size.y-1199.0*source_scale)*0.5
    var center: Vector2=compass.get_child(0).global_position+Vector2(640.0*source_scale,574.0*source_scale+pad_y)
    var vector:=Vector2.ZERO
    var count:=0
    for degree in 360:
        var angle:=deg_to_rad(float(degree))
        var direction:=Vector2(sin(angle),-cos(angle))
        for radius: float in [421.0,429.0,437.0,445.0,453.0]:
            var at:=center+direction*radius*source_scale
            var color:=image.get_pixel(roundi(at.x),roundi(at.y))
            if color.r>0.83 and color.g>0.50 and color.b<0.42:
                vector+=direction
                count+=1
    var actual:=atan2(vector.x,-vector.y)
    check(count>20 and absf(angle_difference(expected,actual))<0.22,"rendered yellow arc follows needle heading "+str(expected)+" actual="+str(actual)+" pixels="+str(count))
    image.get_region(Rect2i(compass.global_position,compass.size)).save_png(OUT+"compass_"+str(roundi(rad_to_deg(expected)))+".png")
