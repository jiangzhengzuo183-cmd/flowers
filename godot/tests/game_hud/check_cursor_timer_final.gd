extends "res://tests/game_hud/check_cursor_timer_dance.gd"
func run() -> void:
    Input.use_accumulated_input=false
    Preferences.path="user://cursor_timer_final_settings.cfg"
    Preferences.loaded=true
    Preferences.aspect=0
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1920,1080)
    root.position=Vector2i.ZERO
    main=load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene=main
    for id: String in ["maze","maze02","maze03"]:
        main.show_scene(id)
        await ticks(220 if id!="maze03" else 35)
        bind()
        var timer: Control=hud.get_node("HUDRoot/TopCenterTimer")
        for slot: TextureRect in timer.slots:
            var image:=slot.texture.get_image()
            var white:=0
            for y in image.get_height():
                for x in image.get_width():
                    var pixel:=image.get_pixel(x,y)
                    if pixel.a>0.5 and maxf(pixel.r,maxf(pixel.g,pixel.b))>0.6:white+=1
            check(white==0,id+" actual imported timer has no white pixels")
        await click(hud.get_node("HUDRoot/TopRightMenu/SettingsButton"))
        var cursor: Node=root.get_node("HandDrawnCursor")
        var before: int=cursor.updates
        await ticks(12)
        check(cursor.updates>before,id+" final cursor animates during menu")
        hud.close_overlay()
        await ticks(3)
        check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" menu resumes look")
        await capture_latest(id+"_hud_final")
    print("CURSOR TIMER FINAL checks=",report.size()," failures=",failures)
    main.queue_free()
    await ticks(5)
    quit(failures)
