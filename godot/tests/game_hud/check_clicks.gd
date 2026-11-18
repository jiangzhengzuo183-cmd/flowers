extends "res://tests/game_hud/check_hud.gd"
func click(control: Control, double: bool = false) -> void:
    var owns_capture:=Input.mouse_mode==Input.MOUSE_MODE_CAPTURED
    if owns_capture:
        adapter.mouse_look.release_cursor()
        await process_frame
    var at: Vector2 = control.get_global_transform_with_canvas() * (control.size*0.5)
    root.warp_mouse(at)
    await process_frame
    var move := InputEventMouseMotion.new()
    move.position = at
    move.global_position = at
    Input.parse_input_event(move)
    await process_frame
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = at
    event.global_position = at
    event.pressed = true
    event.double_click = double
    event.button_mask = MOUSE_BUTTON_MASK_LEFT
    Input.parse_input_event(event)
    event = InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = at
    event.global_position = at
    event.pressed = false
    Input.parse_input_event(event)
    await process_frame
    if owns_capture and hud.overlay.is_empty():
        adapter.mouse_look.capture_cursor()
        await process_frame
func run() -> void:
    Input.use_accumulated_input = false
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1920,1080)
    main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    for id: String in ["maze","maze02","maze03"]:
        main.show_scene(id)
        await ticks(12)
        bind()
        var menu := hud.get_node("HUDRoot/TopRightMenu")
        check(menu.get_child_count()==2,id+" no settings icon")
        await tap(KEY_ESCAPE)
        check(hud.overlay == "debug" and paused,id+" ESC contains music controls")
        await shot(id+"_esc_redesign")
        await tap(KEY_ESCAPE)
        await click(menu.get_child(0))
        print("EXIT CLICK ",id," overlay=",hud.overlay," hover=",root.gui_get_hovered_control())
        check(hud.overlay == "exit" and paused,id+" actual exit icon hit target")
        var body: Node = hud.panels.exit.get_child(0)
        await click(body.get_child(2).get_child(0))
        check(hud.overlay.is_empty() and not paused,id+" actual cancel button")
        if id != "maze03":
            var items = level._items
            actor.position = items._pickup.position+Vector3.UP*0.04
            actor.velocity = Vector3.ZERO
            await ticks(65)
            for gate in level.get_node("%GeneratedMaze").gates.values(): gate.set_open_state(true)
            for i in 500:
                if items._routes.ready: break
                await ticks(1)
            var widget := hud.get_node("HUDRoot/BottomRightInventory")
            await click(widget.buttons[0])
            check(items.inventory.selected_item() == &"LuckyRabbitFoot",id+" actual inventory mouse selection")
            await tap(KEY_Q)
            await ticks(5)
            check(items.inventory.quantity(&"LuckyRabbitFoot") == 0 and is_instance_valid(items._guide),id+" Q consumes rabbit and starts real guide")
            check(widget.icons[0].texture == null,id+" used slot returns empty")
            await shot(id+"_guide")
        else:
            await tap(KEY_ESCAPE)
            var proxy: OptionButton
            for entry: Dictionary in adapter.proxies:
                if entry.source == level.race.mode_selector: proxy = entry.proxy
            proxy.select(1)
            proxy.item_selected.emit(1)
            hud.close_overlay()
            await ticks(50)
            check(level.race.state in ["PREPARATION","COUNTDOWN"],"ESC mode selector starts real race")
            await shot("maze03_countdown")
            while level.race.state != "RACING": await ticks(1)
            actor.position = Vector3(24,0.04,23.6)
            actor.velocity = Vector3.ZERO
            await ticks(8)
            await tap(KEY_E)
            await ticks(65)
            check(level.race.sanctuary_active and hud.status_labels.has("sanctuary"),"real E sanctuary and active HUD status")
            await shot("maze03_sanctuary_hud")
            hud.open_overlay("debug")
            await shot("maze03_esc_debug")
            hud.close_overlay()
        var old: int = level.get_instance_id()
        await click(menu.get_child(1))
        check(hud.overlay=="restart",id+" restart first requests confirmation")
        var restart_body: Node = hud.panels.restart.get_child(0)
        await click(restart_body.get_child(2).get_child(1))
        await ticks(16)
        bind()
        check(old != level.get_instance_id(),id+" actual restart icon reloads maze")
        if id == "maze03":
            check(level.race.current_mode == "Race" and not level.race.sanctuary_used,"HUD restart preserves selected mode and resets sanctuary")
    # Rendered pixel geometry for non-16:9 screens; the black bars belong to the window.
    for dimensions: Vector2i in [Vector2i(1600,1000),Vector2i(2100,900)]:
        root.size = dimensions
        await frames(6)
        check(hud.get_node("HUDRoot").size == Vector2(1920,1080),"native logical ratio "+str(dimensions))
        if DisplayServer.get_name() != "headless":
            RenderingServer.force_draw(false)
            root.get_texture().get_image().save_png(OUT+"aspect_"+str(dimensions.x)+"x"+str(dimensions.y)+".png")
    root.size = Vector2i(1920,1080)
    # Save fresh, clean default screenshots for all three identical HUD layouts.
    for id: String in ["maze","maze02","maze03"]:
        main.show_scene(id)
        await ticks(75)
        bind()
        await shot(id+"_1080")
    main.show_scene("maze_select")
    await ticks(4)
    var file := FileAccess.open(OUT+"click-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"checks":report},"  "))
    file.close()
    print("NATIVE HUD CLICKS checks=",report.size()," failures=",failures)
    main.queue_free()
    await ticks(6)
    quit(1 if failures>0 else 0)
