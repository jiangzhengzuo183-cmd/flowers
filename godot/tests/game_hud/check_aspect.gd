extends "res://tests/game_hud/check_clicks.gd"
func settle() -> void:
    var until := Time.get_ticks_msec()+450
    while Time.get_ticks_msec()<until: await process_frame
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1920,1080)
    main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    main.show_scene("maze03")
    await ticks(20)
    bind()
    var layouts: Array[Dictionary] = []
    for dimensions: Vector2i in [Vector2i(1600,1000),Vector2i(2100,900),Vector2i(1280,720),Vector2i(1920,1080)]:
        root.size = dimensions
        await settle()
        await frames(4)
        RenderingServer.force_draw(false)
        var image := root.get_texture().get_image()
        var record := {"window":str(root.size),"content":str(image.get_size()),"logical_hud":str(hud.get_node("HUDRoot").size),"screen_transform":str(root.get_screen_transform()),"canvas":str(root.get_final_transform()),"compass_transform":str(hud.get_node("HUDRoot/TopLeftCompass").get_global_transform_with_canvas())}
        layouts.append(record)
        print("ASPECT ",JSON.stringify(record))
        check(image.get_width()*9==image.get_height()*16,"render target16:9 "+str(dimensions))
        check(hud.get_node("HUDRoot").size==Vector2(1920,1080),"logical1920x1080 "+str(dimensions))
        image.save_png(OUT+"aspect_"+str(dimensions.x)+"x"+str(dimensions.y)+".png")
    # Actual rendering of a fractional stamina state, retaining all white borders.
    actor.stamina.current = 50.0
    actor.controls_enabled = false
    actor.stamina.changed.emit()
    await shot("stamina_half")
    var timer := hud.get_node("HUDRoot/TopCenterTimer")
    var fixed_positions := PackedVector2Array()
    for slot: TextureRect in timer.slots: fixed_positions.append(slot.position)
    for seconds: float in [9.0,10.0,59.0,60.0,119.0,600.0]:
        timer.set_time(seconds)
        for i in timer.slots.size(): check(timer.slots[i].position==fixed_positions[i],"digit fixed slot "+str(seconds)+" / "+str(i))
    var file := FileAccess.open(OUT+"aspect-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":report,"failures":failures,"windows":layouts},"  "))
    file.close()
    print("ASPECT AND DIGITS failures=",failures)
    main.queue_free()
    await ticks(6)
    quit(failures)
