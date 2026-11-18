extends SceneTree
const OUT := "D:/ChatGPT/献给阿尔吉侬的花束/.verification/unified-hud/"
var main: Control
var level: Control
var adapter: Node
var hud: CanvasLayer
var actor: CharacterBody3D
var failures := 0
var report: Array[Dictionary] = []
var layouts: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
    report.append({"ok":ok,"message":message})
    if not ok:
        failures += 1
        push_error(message)
func ticks(count: int) -> void:
    for i in count:
        await physics_frame
        await process_frame
func frames(count: int) -> void:
    for i in count: await process_frame
func tap(code: Key) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.pressed = true
    Input.parse_input_event(event)
    await process_frame
    event = InputEventKey.new()
    event.physical_keycode = code
    event.pressed = false
    Input.parse_input_event(event)
    await process_frame
func bind() -> void:
    level = main.active_scene
    adapter = level.game_hud
    hud = adapter.hud
    actor = level.get_node("%Player")
func shot(id: String) -> void:
    if DisplayServer.get_name() == "headless": return
    await process_frame
    RenderingServer.force_draw(false)
    var img := root.get_texture().get_image()
    check(img.get_size() == Vector2i(1920,1080),"1080p screenshot " + id)
    img.save_png(OUT+id+".png")
func run() -> void:
    check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920,"project width1920")
    check(ProjectSettings.get_setting("display/window/size/viewport_height") == 1080,"project height1080")
    check(ProjectSettings.get_setting("display/window/size/mode") == 3,"startup fullscreen configured")
    if DisplayServer.get_name() != "headless": check(root.mode == Window.MODE_FULLSCREEN,"native actually starts fullscreen")
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1920,1080)
    main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    for id: String in ["maze","maze02","maze03"]:
        main.show_scene(id)
        await ticks(30)
        bind()
        check(hud.scene_file_path == "res://modules/game_hud/GameHUD.tscn",id+" same packed HUD")
        check(level.get_node("%ViewportContainer").size.is_equal_approx(Vector2(1920,1080)),id+" viewport full1080p")
        check(not level.get_node("Toolbar").visible and not level.get_node("WalkControls").visible,id+" old chrome hidden")
        check(not main.get_node("Margin/Layout/Header").visible,id+" outer chrome hidden")
        check(not level.get_node("%ViewportContainer/StaminaDebugReadout").visible,id+" old stamina readout hidden")
        var layout: Dictionary = {}
        for name: String in ["TopLeftCompass","TopCenterTimer","TaskInformation","TopRightMenu","BottomLeftStamina","BottomRightInventory","CenterBottomNotification"]:
            var control: Control = hud.get_node("HUDRoot/"+name)
            layout[name] = {"position":control.position,"size":control.size}
        layouts.append(layout)
        check(layout == layouts[0],id+" identical layout rectangles")
        var before: float = adapter.clock.elapsed
        await ticks(65)
        check(adapter.clock.elapsed>before+0.9,id+" exploration clock running")
        await shot(id+"_1080")
        await tap(KEY_ESCAPE)
        check(paused and hud.overlay == "debug",id+" ESC opens/pauses")
        var frozen: float = adapter.clock.elapsed
        var stamina_frozen: float = actor.stamina.current
        await frames(25)
        check(is_equal_approx(frozen,adapter.clock.elapsed),id+" pause freezes clock")
        check(is_equal_approx(stamina_frozen,actor.stamina.current),id+" pause freezes stamina")
        check(adapter.proxies.size()>5,id+" developer functions migrated")
        if id == "maze03":
            var found_mode := false
            for proxy: Dictionary in adapter.proxies:
                if proxy.source == level.race.mode_selector: found_mode = true
            check(found_mode,"Maze3 mode selector retained in ESC")
        else:
            check(adapter.race == null,id+" no race option")
        if id == "maze": await shot("esc_debug")
        await tap(KEY_ESCAPE)
        check(not paused and hud.overlay.is_empty(),id+" ESC resumes")
        hud.open_overlay("debug")
        hud.settings_music.button_pressed = false
        check(AudioServer.is_bus_mute(AudioServer.get_bus_index("GameHUDMusic")),id+" music toggle real")
        hud.settings_volume.value = 37
        check(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("GameHUDMusic")))-0.37)<0.01,id+" volume real")
        hud.settings_music.button_pressed = true
        hud.settings_volume.value = 80
        hud.close_overlay()
        actor.stamina.current = 50.0
        actor.stamina.changed.emit()
        var bolts: Control = hud.get_node("HUDRoot/BottomLeftStamina")
        check(is_equal_approx(bolts.ratio,0.5),id+" stamina data binding")
        check(is_equal_approx(bolts.bolts[0].material.get_shader_parameter("fill"),1.0) and is_equal_approx(bolts.bolts[1].material.get_shader_parameter("fill"),0.5) and is_equal_approx(bolts.bolts[2].material.get_shader_parameter("fill"),0.0),id+" three sequential fractional fills")
        actor.stamina.restore(50.0,&"hud_test")
        if id != "maze03": await items_test(id)
        else: await race_test()
        await reset_test(id)
    for dimensions: Vector2i in [Vector2i(1600,1000),Vector2i(2100,900),Vector2i(1280,720)]:
        root.size = dimensions
        await frames(8)
        bind()
        check(hud.get_node("HUDRoot").size.is_equal_approx(Vector2(1920,1080)),"logical HUD remains16:9 at "+str(dimensions))
        check(level.get_node("%ViewportContainer").size.is_equal_approx(Vector2(1920,1080)),"3D canvas remains16:9 at "+str(dimensions))
        check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP,"letterbox keep "+str(dimensions))
    root.size = Vector2i(1920,1080)
    hud.open_overlay("exit")
    check(paused,"exit confirmation pauses")
    hud.close_overlay()
    check(main.active_scene == level and not paused,"cancel exit stays in maze")
    hud.exit_confirmed.emit()
    await ticks(3)
    check(main.active_id == "maze_select" and not paused,"exit returns original selector")
    check(main.get_node("Margin/Layout/Header").visible,"selector shell restored")
    var file := FileAccess.open(OUT+"results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"checks":report},"  "))
    file.close()
    print("UNIFIED HUD TEST checks=",report.size()," failures=",failures)
    main.queue_free()
    await ticks(4)
    quit(1 if failures>0 else 0)
func items_test(id: String) -> void:
    var items = level._items
    var inventory = items.inventory
    var rabbit = items._pickup
    actor.global_position = rabbit.global_position+Vector3.UP*0.03
    actor.velocity = Vector3.ZERO
    await ticks(65)
    check(inventory.quantity(&"LuckyRabbitFoot") == 1,id+" actual rabbit pickup")
    var widget: Control = hud.get_node("HUDRoot/BottomRightInventory")
    check(widget.icons[0].texture != null,id+" pickup appears in slot")
    var coin_id := ""
    for gate_id: String in items.key_pickups:
        if items.key_pickups[gate_id].definition.label == "幸运钱币":
            var pickup = items.key_pickups[gate_id]
            actor.global_position = pickup.global_position+Vector3.UP*0.03
            actor.velocity = Vector3.ZERO
            coin_id = gate_id
            await ticks(60)
    check(inventory.quantity(&"LuckyCoin") == 2,id+" two coins shared count")
    check(widget.snapshot[1].id == &"LuckyCoin" and widget.snapshot[2].id == &"LuckyCoin",id+" two coins occupy two actual HUD slots")
    await tap(KEY_2)
    check(inventory.selected_item() == &"LuckyCoin",id+" numeric selection")
    await tap(KEY_Q)
    await ticks(3)
    check(inventory.quantity(&"LuckyCoin") == 2,id+" Q cannot consume passive key")
    var gate: Node3D = level.get_node("%GeneratedMaze").gates[coin_id]
    actor.global_position = gate.to_global(Vector3(0,0,1.1))
    actor.velocity = Vector3.ZERO
    await ticks(4)
    await tap(KEY_E)
    await ticks(6)
    check(inventory.quantity(&"LuckyCoin") == 1,id+" real E unlock decrements HUD")
    check(items.inventory.item_count()==2,id+" HUD follows key consumption")
    var perks = level._perks
    var cake = perks.pickups[0]
    actor.global_position = cake.global_position+Vector3.UP*0.03
    actor.velocity = Vector3.ZERO
    await ticks(30)
    check(perks.boost_remaining==0.0 and inventory.quantity(&"ChocolateCake")==1,id+" cake remains stored until use")
    await tap(KEY_E)
    await ticks(5)
    check(perks.boost_remaining>0.0,id+" E activates the selected stored cake")
    check(hud.status_labels.has("cake"),id+" live cake status")
    if id == "maze":
        var flour = perks.pickups[2]
        actor.global_position = flour.global_position+Vector3.UP*0.03
        actor.velocity = Vector3.ZERO
        await ticks(20)
        check(hud.status_labels.has("flour"),"live flour status")
    else:
        level._item_effects.vision_chance = 1.0
        var capsule = level._item_effects.capsules[0]
        actor.global_position = capsule.global_position+Vector3.UP*0.03
        actor.velocity = Vector3.ZERO
        await ticks(30)
        check(level._item_effects.vision.remaining==0.0 and inventory.quantity(&"PinkCapsule")==1,"capsule stored before use")
        await tap(KEY_E)
        await ticks(8)
        check(hud.status_labels.has("vision"),"live capsule vision status")
    await shot(id+"_effects")
func reset_test(id: String) -> void:
    var old := level.get_instance_id()
    hud.restart_requested.emit()
    await ticks(20)
    bind()
    check(level.get_instance_id()!=old,id+" restart reloads current scene")
    check(actor.stamina.current==actor.stamina.settings.maximum,id+" restart resets stamina")
    check(adapter.clock.elapsed<0.6,id+" restart resets exploration timer")
    check(hud.status_labels.is_empty(),id+" restart clears statuses")
    if id != "maze03":
        check(adapter.inventory.quantity(&"LuckyCoin")==0 and adapter.inventory.quantity(&"LuckyRabbitFoot")==0,id+" restart clears inventory")
        check(not level.completed,id+" restart resets completion")
        for gate: Node3D in level.get_node("%GeneratedMaze").gates.values(): check(not gate.is_open,id+" reset closed gate")
    else:
        check(not level.race.sanctuary_used,"restart resets sanctuary entitlement")
        check(level.race.elapsed==0.0,"restart resets race clock")
func race_test() -> void:
    var manager = level.race
    check(manager.current_mode == "Explore" and manager.mouse == null,"Explore has no mouse or race UI")
    manager.request_mode("Race")
    await ticks(8)
    check(manager.state == "PREPARATION","race preparation retained")
    check(not actor.controls_enabled,"preparation movement locked")
    await ticks(220)
    check(manager.state == "RACING","GO starts race")
    check(manager.elapsed>0.0,"positive race clock starts")
    check(hud.get_node("HUDRoot/TopCenterTimer").seconds == floori(manager.elapsed),"unified timer bound to race")
    check(not manager.hud.timer.visible,"old duplicate race timer hidden")
    hud.open_overlay("debug")
    var paused_time: float = manager.elapsed
    await frames(30)
    check(is_equal_approx(manager.elapsed,paused_time),"race clock pauses in ESC")
    manager.request_mode("Explore")
    check(manager.current_mode=="Race" and manager.pending_mode=="Explore","active race mode only queues change")
    manager.pending_mode="Race"
    manager.mode_selector.select(1)
    hud.close_overlay()
    # Real deterministic run, keeping Charlie at the start so the mouse finishes first.
    while not manager.mouse_finished and manager.elapsed<60.0: await ticks(1)
    check(manager.mouse_finished and absf(manager.mouse_time-55.5)<0.02,"mouse rule is55.5seconds")
    var before: float = manager.elapsed
    await ticks(90)
    check(manager.elapsed>before+1.4 and actor.controls_enabled,"mouse first does not stop Charlie or clock")
    actor.global_position = manager.recorder.finish_trigger.global_position-Vector3.UP*0.76
    actor.velocity = Vector3.ZERO
    await ticks(6)
    check(manager.state=="FINISHED" and manager.result.outcome=="mouse","Charlie finish settles actual result")
    var final_time: float = manager.elapsed
    await ticks(12)
    check(is_equal_approx(manager.elapsed,final_time),"Charlie arrival stops unified race time")
    await shot("maze03_race_result")
