extends "res://tests/game_hud/check_stamina_ring.gd"
func run() -> void:
    Input.use_accumulated_input=false
    Preferences.path="user://ring_mouse_test_settings.cfg"
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
        check(root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" default gameplay focus and look without click")
        for name: String in ["SettingsButton","ExitButton","RestartButton"]:
            adapter.mouse_look.release_cursor()
            await click(hud.get_node("HUDRoot/TopRightMenu/"+name))
            check(not hud.overlay.is_empty() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,id+" "+name+" opens free pointer")
            hud.close_overlay()
            await ticks(3)
            check(root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" "+name+" closing automatically resumes look")
        await tap(KEY_ESCAPE)
        check(hud.overlay=="debug" and paused,id+" original ESC retained")
        await tap(KEY_ESCAPE)
        await ticks(3)
        check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not paused,id+" ESC returning resumes mouse look")
        if id=="maze":
            var flour: Area3D=null
            for item in level._perks.pickups:
                if is_instance_valid(item) and item.effect==1:flour=item;break
            check(flour!=null,id+" original flour preserved")
            actor.position=flour.position+Vector3.UP*0.03
            actor.velocity=Vector3.ZERO
            await ticks(6)
            check(level._perks.flour_remaining>0.0,id+" real negative state trigger")
            adapter._sync()
            check(hud.get_node("HUDRoot/StatusEffects").find_children("*","TextureRect",true,false).is_empty(),id+" negative status remains text only")
            await capture(id+"_negative_text_status")
            await ticks(200)
            adapter._sync()
            check(not hud.status_labels.has("flour"),id+" negative status removed on expiry")
        elif id=="maze02":
            var tv: Area3D=level._item_effects.televisions[0]
            actor.global_position=tv.global_position+Vector3(0.6,0.08,0)
            actor.velocity=Vector3.ZERO
            await ticks(8)
            adapter._sync()
            check(actor.tv_reversed and hud.status_labels.has("tv"),"Maze02 actual existing TV interference state")
            check(hud.get_node("HUDRoot/StatusEffects").find_children("*","TextureRect",true,false).is_empty(),"Maze02 negative state text only")
            await capture(id+"_negative_text_status")
            actor.position=actor.spawn_point
            await ticks(8)
            adapter._sync()
            check(not actor.tv_reversed and not hud.status_labels.has("tv"),"Maze02 existing TV state clears on leaving")
    var file:=FileAccess.open(DEST+"mouse-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":report,"failures":failures},"  "))
    file.close()
    print("RING MOUSE checks=",report.size()," failures=",failures)
    main.queue_free()
    await ticks(5)
    quit(failures)
