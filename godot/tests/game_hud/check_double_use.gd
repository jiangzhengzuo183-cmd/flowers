extends "res://tests/game_hud/check_clicks.gd"
func run() -> void:
    Input.use_accumulated_input = false
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1920,1080)
    main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    main.show_scene("maze02")
    await ticks(15)
    bind()
    var items = level._items
    actor.position = items._pickup.position+Vector3.UP*0.03
    actor.velocity = Vector3.ZERO
    await ticks(65)
    for gate in level.get_node("%GeneratedMaze").gates.values(): gate.set_open_state(true)
    for i in 500:
        if items._routes.ready: break
        await ticks(1)
    check(items.inventory.quantity(&"LuckyRabbitFoot")==1,"real pickup before explicit double use")
    await click(hud.get_node("HUDRoot/BottomRightInventory").buttons[0],true)
    await ticks(6)
    check(items.inventory.quantity(&"LuckyRabbitFoot")==0 and is_instance_valid(items._guide),"double-click performs one real active use")
    await click(hud.get_node("HUDRoot/BottomRightInventory").buttons[0],true)
    await ticks(3)
    check(items.inventory.quantity(&"LuckyRabbitFoot")==0,"empty double-click never consumes twice")
    var file := FileAccess.open(OUT+"double-use-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"checks":report},"  "))
    file.close()
    print("DOUBLE USE failures=",failures)
    main.queue_free()
    await ticks(5)
    quit(failures)
