extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var main: Control = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    for id in ["maze","maze02","maze03"]:
        main.show_scene(id)
        for i in 8:
            await physics_frame
            await process_frame
        var level = main.active_scene
        if level.game_hud == null:
            push_error("HUD missing " + id)
            quit(1)
            return
        print("HUD SMOKE ",id," size=",level.game_hud.hud.get_node("HUDRoot").size," viewport=",level.get_node("%ViewportContainer").size)
    main.show_scene("maze_select")
    await process_frame
    main.queue_free()
    await process_frame
    quit()
