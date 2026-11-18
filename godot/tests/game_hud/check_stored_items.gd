extends "res://tests/game_hud/check_clicks.gd"
const Cake := &"ChocolateCake"
const Capsule := &"PinkCapsule"
func place(point: Vector3, count: int = 30) -> void:
    actor.global_position=point+Vector3.UP*0.03
    actor.velocity=Vector3.ZERO
    await ticks(count)
func run() -> void:
    Input.use_accumulated_input=false
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1920,1080)
    main=load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene=main
    for id: String in ["maze","maze02","maze03"]:
        main.show_scene(id)
        await ticks(35)
        bind()
        await layout_checks(id)
        if id!="maze03": await inventory_checks(id)
        else:
            check(is_instance_valid(adapter.inventory) and level._perks.pickups.size()==2,"Maze03 has two cakes using the shared inventory")
            level.race.request_mode("Race")
            while level.race.state!="RACING": await ticks(1)
            await place(Vector3(24,0,23.6),12)
            await tap(KEY_E)
            await ticks(5)
            check(level.race.sanctuary_active and level.race.sanctuary_used,"E still activates the once-per-race sanctuary")
        hud.restart_requested.emit()
        await ticks(22)
        bind()
        if id!="maze03":
            check(adapter.inventory.item_count()==0 and adapter.inventory.selected_slot()==0,id+" restart clears three-slot inventory and selection")
            check(level._perks.boost_remaining==0.0 and actor.move_speed_multiplier==1.0,id+" restart clears cake effects")
            if id=="maze02":check(level._item_effects.vision.remaining==0.0 and level._item_effects.slow_remaining==0.0,"restart clears capsule effects")
    var file:=FileAccess.open(OUT+"stored-items-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"checks":report},"  "))
    file.close()
    print("STORED ITEMS AND ALIGNMENT checks=",report.size()," failures=",failures)
    main.queue_free()
    await ticks(8)
    quit(failures)
func layout_checks(id: String) -> void:
    var ui:=hud.get_node("HUDRoot")
    var compass: Control=ui.get_node("TopLeftCompass")
    var timer: Control=ui.get_node("TopCenterTimer")
    var menu: Control=ui.get_node("TopRightMenu")
    var stamina: Control=ui.get_node("BottomLeftStamina")
    var pack: Control=ui.get_node("BottomRightInventory")
    check(compass.position.y==40 and timer.position.y==56 and menu.position.y==56,id+" updated timer/menu line below compass")
    check(compass.position.x==40 and 1920-menu.get_rect().end.x==40,id+" symmetric upper safety margins")
    check(stamina.position.x==40 and 1920-pack.get_rect().end.x==40,id+" symmetric lower safety margins")
    check(stamina.size==Vector2(360,124) and pack.size==stamina.size and stamina.position.y==pack.position.y,id+" equal lower sizes and bottom line")
    check(1080-stamina.get_rect().end.y==40,id+" 40px lower safety margin")
    check(timer.get_rect().get_center().x==960 and ui.get_node("TaskInformation").get_rect().get_center().x==960,id+" timer and task share screen center axis")
    check(timer.size==Vector2(240,64) and ui.get_node("TaskInformation").position.y-timer.get_rect().end.y==16,id+" fixed timer size and 16px task gap")
    check(pack.buttons.size()==3 and pack.buttons[1].position.x-pack.buttons[0].get_rect().end.x==12 and pack.buttons[2].get_rect().end.x==pack.size.x,id+" three cells have equal 12px spacing with no trailing extra gap")
    await shot(id+"_aligned")
    if DisplayServer.get_name()=="headless":return
    var backdrop:=CanvasLayer.new()
    backdrop.layer=19
    var flat:=ColorRect.new()
    flat.color=Color(0.18,0.22,0.26)
    flat.size=Vector2(1920,1080)
    flat.mouse_filter=Control.MOUSE_FILTER_IGNORE
    backdrop.add_child(flat)
    root.add_child(backdrop)
    await frames(3)
    RenderingServer.force_draw(false)
    var img:=root.get_texture().get_image()
    var tops: Array[int]=[]
    for rect: Rect2i in [Rect2i(218,0,24,96),Rect2i(840,0,240,120),Rect2i(1728,0,64,96),Rect2i(1816,0,64,96)]:
        tops.append(first_art_row(img,rect))
    check(abs(tops[0]-40)<=2 and abs(tops[1]-56)<=2 and abs(tops[2]-56)<=2 and abs(tops[3]-56)<=2,id+" rendered compass and lowered timer/menu positions follow revised layout "+str(tops))
    backdrop.queue_free()
    await frames(3)
func first_art_row(img: Image, rect: Rect2i) -> int:
    for y in range(rect.position.y,rect.end.y):
        var count:=0
        for x in range(rect.position.x,rect.end.x):
            var p:=img.get_pixel(x,y)
            if p.r>0.50 or p.g>0.55 or p.b>0.65:count+=1
        if count>=3:return y
    return -1
func inventory_checks(id: String) -> void:
    var items=level._items
    var inv=items.inventory
    var perks=level._perks
    var widget:=hud.get_node("HUDRoot/BottomRightInventory")
    var start: Vector3=actor.global_position
    var restores: int=actor.stamina.restore_counts.get(&"cake",0)
    await place(items._pickup.global_position)
    check(inv.item_count()==1 and inv.quantity(&"LuckyRabbitFoot")==1,id+" actual rabbit occupies one slot")
    var cake=perks.pickups[0]
    await place(cake.global_position)
    check(inv.quantity(Cake)==1 and inv.item_count()==2,id+" actual cake is stored instead of activated")
    check(perks.boost_remaining==0.0 and actor.move_speed_multiplier==1.0 and actor.stamina.restore_counts.get(&"cake",0)==restores,id+" storing cake gives neither speed nor stamina")
    await place(items.key_pickups.D1.global_position)
    check(inv.item_count()==3 and inv.quantity(&"LuckyCoin")==1,id+" key shares total three-item capacity")
    var blocked=perks.pickups[1]
    await place(blocked.global_position,40)
    check(is_instance_valid(blocked) and not blocked.claimed and blocked.monitoring,id+" fourth ground item stays visible and collectible when full")
    check(not inv.grant(Cake) and not inv.grant(&"LuckyCoin") and inv.item_count()==3,id+" direct grants and repeated copies cannot bypass total capacity")
    check(inv.snapshot().size()==3 and widget.icons[0].texture!=null and widget.icons[1].texture!=null and widget.icons[2].texture!=null,id+" UI contains exactly the same three physical items")
    await place(start,5)
    for i in 3:
        await tap([KEY_1,KEY_2,KEY_3][i])
        check(inv.selected_slot()==i and widget.active_slot==i and widget.target_scales[i]==1.10,id+" numeric key selects actual occupied slot "+str(i+1))
    await tap(KEY_2)
    await tap(KEY_ESCAPE)
    await tap(KEY_E)
    check(inv.quantity(Cake)==1 and perks.boost_remaining==0.0,id+" E cannot consume while paused")
    await tap(KEY_ESCAPE)
    await tap(KEY_E)
    await ticks(5)
    check(inv.quantity(Cake)==0 and inv.item_count()==2 and perks.boost_remaining>7.5,id+" E consumes one selected cake and starts original eight-second boost")
    check(actor.move_speed_multiplier==1.3 and actor.stamina.restore_counts.get(&"cake",0)==restores+1,id+" cake calls existing stamina restore and speed modifier once")
    await tap(KEY_E)
    check(inv.item_count()==2 and actor.stamina.restore_counts.get(&"cake",0)==restores+1,id+" E on emptied slot does not repeat consumption")
    await place(blocked.global_position,35)
    check(inv.item_count()==3 and inv.quantity(Cake)==1 and inv.snapshot()[1].id==Cake,id+" freeing a slot permits picking the formerly blocked cake without shifting other slots")
    await tap(KEY_2)
    var gate: Node3D=level.get_node("%GeneratedMaze").gates.D1
    await place(gate.to_global(Vector3(0,0,1.1)),8)
    var spent: int=actor.stamina.restore_counts.get(&"cake",0)
    await tap(KEY_E)
    await ticks(6)
    check(gate.is_open and inv.quantity(&"LuckyCoin")==0 and inv.quantity(Cake)==1,id+" door E consumes its key while selected cake is preserved")
    check(actor.stamina.restore_counts.get(&"cake",0)==spent,id+" door E does not also activate selected effect")
    await tap(KEY_E)
    check(inv.quantity(Cake)==1,id+" already-open nearby door cannot consume cake")
    var wrong: Node3D=level.get_node("%GeneratedMaze").gates.D4
    await place(wrong.to_global(Vector3(0,0,1.1)),8)
    await tap(KEY_E)
    check(not wrong.is_open and inv.quantity(Cake)==1,id+" missing required key blocks door without eating selected cake")
    if id=="maze02": await capsule_checks(start)
    else:
        await place(start,5)
        inv.clear_items()
        for i in 3: check(inv.grant(Cake),"same-kind item fills physical slot "+str(i+1))
        check(inv.item_count()==3 and inv.quantity(Cake)==3 and not inv.grant(Cake),"three same-kind copies take all slots; fourth cannot stack invisibly")
        await tap(KEY_2)
        await tap(KEY_E)
        check(inv.snapshot()[0].id==Cake and inv.snapshot()[1].id==&"" and inv.snapshot()[2].id==Cake,"using same-kind copy empties selected second slot only")
        await ticks(490)
        check(perks.boost_remaining==0.0 and actor.move_speed_multiplier==1.0,"cake expires back to original speed")
        inv.clear_items()
        for key: StringName in [&"LuckyCoin",&"LuckyHorseshoe",&"LuckyCoin"]:inv.grant(key)
        await place(items._extra_rabbits[0].global_position,35)
        check(is_instance_valid(items._extra_rabbits[0]) and not items._extra_rabbits[0].claimed,"full inventory also preserves rabbit on ground")
        var horseshoe=items.key_pickups.D4
        await place(horseshoe.global_position,35)
        check(is_instance_valid(horseshoe) and not horseshoe.claimed,"full inventory also preserves key on ground")
        await place(start,5)
        inv.clear_items()
        inv.grant(&"LuckyRabbitFoot")
        await tap(KEY_1)
        await tap(KEY_E)
        await ticks(5)
        check(inv.quantity(&"LuckyRabbitFoot")==0 and is_instance_valid(items._guide),"E uses the real rabbit guide through the existing path system")
        items.cancel_guide()
        inv.clear_items()
        inv.grant(Cake)
        inv.grant(&"LuckyCoin")
        inv.grant(&"LuckyRabbitFoot")
        await shot("maze_stored_inventory")
func capsule_checks(start: Vector3) -> void:
    var effects=level._item_effects
    var inv=adapter.inventory
    var capsule=effects.capsules[0]
    # Two occupied slots remain after consuming the gate key.
    await place(capsule.global_position,35)
    check(inv.quantity(Capsule)==1 and effects.vision.remaining==0.0 and effects.slow_remaining==0.0,"capsule pickup stores without rolling or starting effects")
    await place(start,5)
    var index: int=inv.snapshot().filter(func(entry):return entry.id==Capsule)[0].slot
    await tap([KEY_1,KEY_2,KEY_3][index])
    effects.vision_chance=1.0
    await tap(KEY_E)
    await ticks(8)
    check(inv.quantity(Capsule)==0 and effects.vision.remaining>6.5,"E consumes selected capsule and invokes existing global vision")
    await shot("maze02_stored_capsule_vision")
    effects.vision.clear()
    inv.clear_items()
    inv.grant(Cake)
    inv.grant(&"LuckyRabbitFoot")
    inv.grant(&"LuckyCoin")
    var blocked=effects.capsules[1]
    await place(blocked.global_position,35)
    check(is_instance_valid(blocked) and not blocked.claimed and inv.item_count()==3,"full inventory preserves capsule on ground")
    inv.select_slot(0)
    inv.consume(Cake)
    await ticks(30)
    check(inv.quantity(Capsule)==1 and inv.item_count()==3,"capsule can be collected in-place after capacity is released")
    await place(start,5)
    effects.vision_chance=0.0
    inv.select_item(Capsule)
    await tap(KEY_E)
    check(effects.slow_remaining>3.8 and actor.capsule_speed_factor==0.45,"stored capsule retains original negative outcome on use")
    await ticks(250)
    check(effects.slow_remaining==0.0 and actor.capsule_speed_factor==1.0,"capsule slowdown expires and restores speed")
    inv.clear_items()
    inv.grant(&"LuckyRabbitFoot")
    inv.grant(Cake)
    inv.grant(Capsule)
    hud.clear_notifications()
    await shot("maze02_stored_inventory")
