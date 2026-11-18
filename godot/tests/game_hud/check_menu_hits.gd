extends "res://tests/game_hud/check_clicks.gd"
func run() -> void:
    Input.use_accumulated_input = false
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1920,1080)
    main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    main.show_scene("maze02")
    await ticks(30)
    bind()
    var menu := hud.get_node("HUDRoot/TopRightMenu")
    for i in 5:
        print("CYCLE ",i," before=",hud.overlay)
        await tap(KEY_ESCAPE)
        print("settings=",hud.overlay," hover=",root.gui_get_hovered_control())
        check(hud.overlay=="debug","ESC hit")
        await tap(KEY_ESCAPE)
        print("escape=",hud.overlay)
        await click(menu.get_child(0))
        print("exit=",hud.overlay," hover=",root.gui_get_hovered_control())
        check(hud.overlay=="exit","exit hit")
        hud.close_overlay()
    print("MENU HITS failures=",failures)
    main.queue_free()
    await ticks(5)
    quit(failures)
