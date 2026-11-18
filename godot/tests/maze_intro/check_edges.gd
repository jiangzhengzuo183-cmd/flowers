extends "res://tests/maze_intro/check_intro.gd"
func run() -> void:
    Preferences.path="user://intro_edge_settings.cfg"
    Preferences.loaded=true
    Preferences.aspect=0
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1920,1080)
    root.position=Vector2i.ZERO
    main=load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene=main
    main.show_scene("maze03")
    await ticks(7)
    bind()
    # Camera centre and its small clearance sphere stay clear of actual walls/roofs.
    var hits: Array=[]
    while intro.active:
        await physics_frame
        if is_instance_valid(intro.camera):
            var sphere:=SphereShape3D.new()
            sphere.radius=0.16
            var q:=PhysicsShapeQueryParameters3D.new()
            q.shape=sphere
            q.transform=Transform3D(Basis.IDENTITY,intro.camera.global_position)
            q.collision_mask=5
            q.exclude=[actor.get_rid()]
            for hit: Dictionary in actor.get_world_3d().direct_space_state.intersect_shape(q):hits.append(str(hit.collider.get_path()))
        await process_frame
    check(hits.is_empty(),"temporary camera near-plane clearance avoids walls and roofs")
    check(actor.get_parent().get_node_or_null("EntranceAirPassage")==null,"arrival releases every temporary air node")
    await ticks(225)
    check(level.race.state=="RACING","Race is available after intro and GO")
    var sanctuary: Node=level.race.sanctuary
    actor.global_position=Vector3(sanctuary.cube.global_position.x,0.04,sanctuary.cube.global_position.z)
    actor.velocity=Vector3.ZERO
    await ticks(8)
    check(sanctuary.can_interact(),"sanctuary interaction still available after intro")
    check(sanctuary.try_activate() and level.race.sanctuary_used,"existing sanctuary activates once")
    var age: float=level.race.elapsed
    await ticks(65)
    check(level.race.sanctuary_active and level.race.elapsed>age+0.9,"sanctuary keeps real race clock running")
    check(is_equal_approx(level.race.effective_mouse_speed_multiplier(),0.05),"original sanctuary slowdown unchanged")
    await ticks(310)
    check(not level.race.sanctuary_active and is_equal_approx(level.race.effective_mouse_speed_multiplier(),1.0),"sanctuary restores original opponent speed")
    # Real pending-mode and confirmed restart path, rather than opening the same active scene.
    level.race.request_mode("Explore")
    check(level.race.current_mode=="Race" and level.race.pending_mode=="Explore","active race defers mode switching")
    runtime._restart_level()
    await ticks(7)
    bind()
    check(level.race.current_mode=="Explore" and intro.active and intro.plays==1,"confirmed restart keeps explicitly selected Explore")
    await ticks(ceili(intro.duration_seconds*60.0)+10)
    check(actor.controls_enabled and runtime.clock.elapsed>0.0 and level.race.mouse==null,"Explore controls and clock restored without opponent")
    var cakes: Array=level._items.effects.pickups
    actor.global_position=cakes[0].global_position+Vector3.UP*0.03
    actor.velocity=Vector3.ZERO
    await ticks(12)
    check(runtime.inventory.quantity(&"ChocolateCake")==1,"existing cake still picks up into inventory")
    runtime.inventory.request_selected_use()
    await ticks(3)
    check(level._perks.boost_remaining>7.5 and actor._has_free_sprint(),"cake keeps original eight-second free sprint boost")
    actor.apply_boost()
    check(actor.boost_remaining>2.9 and is_equal_approx(actor._movement_modifier(),1.35),"barrier boost still uses max multiplier")
    # Restart in the middle of an entrance must reset in place and recover its clock.
    level.reset_walk()
    await ticks(30)
    level.reset_walk()
    await ticks(5)
    check(intro.active and intro.age<0.15 and intro.plays==3,"mid-intro restart resets the same controller cleanly")
    check(level.find_children("MazeIntroController","Node",false,false).size()==1,"one controller after repeated resets")
    check(actor.get_parent().find_children("EntranceAirPassage","Node3D",false,false).size()==1,"repeated resets retain only one air passage")
    # A lost temporary camera must hand back ownership and unlock, rather than strand input.
    intro.camera.free()
    await ticks(3)
    check(not intro.active and actor.controls_enabled,"missing temporary camera fails open")
    check(actor.get_viewport().get_camera_3d()==intro.game_camera,"failed intro still hands control to original camera")
    check(not intro.blocker.visible and runtime.hud.get_node("HUDRoot").modulate.a==1.0,"failure removes blocker and restores HUD")
    runtime.hud.open_overlay("settings")
    check(paused,"settings remains functional")
    runtime.hud.close_overlay()
    await ticks(3)
    check(not paused and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"closing settings returns to mouse look")
    main.show_scene("maze_select")
    await ticks(5)
    var picker: Node=main.active_scene
    picker.get_node("%Maze03").pressed.emit()
    await ticks(7)
    bind()
    check(level.race.current_mode=="Race" and intro.active,"selecting Maze03 afresh defaults to Race")
    # Actual standalone F6 selector follows the same path.
    main.queue_free()
    await ticks(4)
    var standalone: Control=load("res://scenes/levels/MazeSelect.tscn").instantiate()
    root.add_child(standalone)
    current_scene=standalone
    standalone.get_node("%Maze03").pressed.emit()
    await ticks(7)
    var isolated: Control=standalone.active_level
    check(isolated.race.current_mode=="Race" and isolated.game_hud.intro.active,"F6 selector also opens Race with shared intro")
    standalone.queue_free()
    await ticks(4)
    var file:=FileAccess.open(OUTPUT+"edge-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"near_plane_hits":hits},"  "))
    file.close()
    print("MAZE INTRO EDGES checks=",checks.size()," failures=",failures)
    quit(1 if failures>0 else 0)
