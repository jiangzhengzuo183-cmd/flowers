extends "res://tests/game_hud/check_clicks.gd"
func move_pointer(at: Vector2) -> void:
    root.warp_mouse(at)
    var move:=InputEventMouseMotion.new()
    move.position=at
    move.global_position=at
    Input.parse_input_event(move)
    await ticks(20)
func confirm(kind: String) -> void:
    var panel: PanelContainer=hud.panels[kind]
    var row: HBoxContainer=panel.get_child(0).get_child(2)
    await click(row.get_child(1))
func cancel(kind: String) -> void:
    var panel: PanelContainer=hud.panels[kind]
    var row: HBoxContainer=panel.get_child(0).get_child(2)
    await click(row.get_child(0))
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
        check(ui.theme.default_font.resource_path.ends_with("HUDHand.ttf"),id+" shared handwritten font")
        check(ui.theme.default_font.has_char("开".unicode_at(0)),id+" Chinese opening glyph")
        check(ui.get_node("TopLeftCompass").size==Vector2(384,352),id+" largest compass")
        check(ui.get_node("BottomLeftStamina").size==ui.get_node("BottomRightInventory").size,id+" equal lower widget dimensions")
        check(not ui.get_node("TaskInformation") is Panel,id+" frameless task text")
        await shot(id+"_1080")
        var menu:=ui.get_node("TopRightMenu")
        check(menu.get_child_count()==2,id+" two menu controls")
        for button: Button in menu.get_children():
            check(button.tooltip_text.is_empty(),id+" menu tooltip absent")
            var center: Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
            await move_pointer(center)
            check(absf(button.get_node("Sticker").scale.x-1.08)<0.012,id+" actual hover enlarges sticker")
            check(button.scale==Vector2.ONE,id+" hover keeps hit region stable")
        await shot(id+"_menu_hover")
        await move_pointer(Vector2(1300,400))
        check(menu.get_child(1).get_node("Sticker").scale.is_equal_approx(Vector2.ONE),id+" mouse leave returns to original size")
        if id!="maze03": await gate_feedback(id)
        else:
            level.race.request_mode("Race")
            while level.race.state!="RACING":await ticks(1)
            actor.position=Vector3(24,0.04,23.6)
            actor.velocity=Vector3.ZERO
            await ticks(12)
            check(ui.get_node("Interaction").visible and ui.get_node("Interaction").keycap.visible,"sanctuary displays yellow E key")
            await shot("maze03_sanctuary_prompt")
        var old: int=level.get_instance_id()
        await click(menu.get_child(1))
        check(hud.overlay=="restart" and paused,id+" restart opens confirmation")
        check(main.active_scene.get_instance_id()==old,id+" opening confirmation does not reset")
        var frozen: float=level.race.elapsed if id=="maze03" else adapter.clock.elapsed
        await frames(20)
        check(is_equal_approx(frozen,level.race.elapsed if id=="maze03" else adapter.clock.elapsed),id+" confirmation pauses time")
        if id=="maze":await shot("restart_confirmation")
        await cancel("restart")
        check(not paused and main.active_scene.get_instance_id()==old,id+" cancel restart preserves current session")
        await click(menu.get_child(1))
        await confirm("restart")
        await ticks(20)
        bind()
        check(level.get_instance_id()!=old,id+" confirm restart reloads scene")
        check(actor.stamina.current==actor.stamina.settings.maximum,id+" confirmed restart resets stamina")
        if id=="maze03":check(level.race.current_mode=="Race" and not level.race.sanctuary_used,"confirmed restart keeps race selection and resets once flag")
        menu=hud.get_node("HUDRoot/TopRightMenu")
        await click(menu.get_child(0))
        check(hud.overlay=="exit" and paused,id+" exit opens confirmation")
        if id=="maze":await shot("exit_confirmation")
        await cancel("exit")
        check(not paused and main.active_scene==level,id+" cancel exit keeps game")
        await click(menu.get_child(0))
        await confirm("exit")
        await ticks(8)
        check(main.active_id=="maze_select",id+" exit returns original selector")
    var file:=FileAccess.open(OUT+"polish-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"checks":report},"  "))
    file.close()
    print("HUD POLISH checks=",report.size()," failures=",failures)
    main.queue_free()
    await ticks(6)
    quit(failures)
func gate_feedback(id: String) -> void:
    var items=level._items
    var gate: Node3D=level.get_node("%GeneratedMaze").gates.D1
    actor.position=gate.to_global(Vector3(0,0,1.1))
    actor.velocity=Vector3.ZERO
    await ticks(80)
    var prompt:=hud.get_node("HUDRoot/Interaction")
    check(prompt.visible and not prompt.keycap.visible,id+" missing key states need rather than offering E")
    var pickup=items.key_pickups.D1
    actor.position=pickup.position+Vector3.UP*0.03
    actor.velocity=Vector3.ZERO
    await ticks(65)
    check(items.inventory.quantity(&"LuckyCoin")==1,id+" actual coin picked up")
    var slots:=hud.get_node("HUDRoot/BottomRightInventory")
    check(slots.backgrounds[0].visible and slots.icons[0].texture!=null,id+" acquired item stays inside circular slot")
    check(slots.icons[0].size.x<slots.buttons[0].size.x*0.7,id+" item retains paper margin")
    actor.position=gate.to_global(Vector3(0,0,1.1))
    actor.velocity=Vector3.ZERO
    await ticks(80)
    check(prompt.visible and prompt.keycap.visible and prompt.title.text=="开启",id+" cream interaction prompt with E and opening label")
    await shot(id+"_opening_prompt")
    await tap(KEY_E)
    await ticks(10)
    check(gate.is_open and items.inventory.quantity(&"LuckyCoin")==0,id+" E still performs original atomic unlock")
    check(slots.backgrounds[0].visible and slots.icons[0].texture==null,id+" used item leaves circular slot intact")
    # Render the complete real inventory data through the same existing grant interface.
    items.inventory.clear_items()
    items.inventory.grant(&"LuckyRabbitFoot")
    items.inventory.grant(&"LuckyCoin")
    items.inventory.grant(&"LuckyHorseshoe")
    hud.clear_notifications()
    hud.show_notification({"title":"获得 幸运兔脚 ×1","description":"光团提示前方路线","icon":"LuckyRabbitFoot"})
    await ticks(25)
    await shot(id+"_pickup_redesign")
