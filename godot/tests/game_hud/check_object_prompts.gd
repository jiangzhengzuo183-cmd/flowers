extends "res://tests/game_hud/check_clicks.gd"
const TASKS := ["请尽情探索这个迷宫并尝试找到出口。","迷宫似乎发生了变化，请尝试发现它并熟悉路线。","这是你和阿尔吉侬的终极比拼，全速前进吧！"]
func hold(code: Key, pressed: bool) -> void:
    var event:=InputEventKey.new()
    event.physical_keycode=code
    event.pressed=pressed
    Input.parse_input_event(event)
func run() -> void:
    Input.use_accumulated_input=false
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1920,1080)
    main=load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene=main
    var n:=0
    for id: String in ["maze","maze02","maze03"]:
        main.show_scene(id)
        await ticks(35)
        bind()
        var ui:=hud.get_node("HUDRoot")
        check(hud.chapter_label.text.begins_with("第一章") and hud.task_label.text==TASKS[n],id+" exact chapter and task copy")
        check(ui.get_node("TopCenterTimer").position.y==56 and ui.get_node("TopRightMenu").position.y==56,id+" timer and menu move down together")
        check(ui.get_node("TopCenterTimer").size==Vector2(240,64),id+" smaller fixed-slot numeric timer")
        check(ui.get_node("BottomLeftStamina").size==ui.get_node("BottomRightInventory").size,id+" equal lower footprint retained")
        await shot(id+"_ui_refined")
        if id=="maze":await compass_checks()
        if id!="maze03":await inventory_and_gate(id)
        else:await cube_prompt()
        await modal_checks(id)
        await exhaustion_checks(id)
        n+=1
    var file:=FileAccess.open(OUT+"object-prompts-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"checks":report},"  "))
    file.close()
    print("OBJECT PROMPTS AND HUD checks=",report.size()," failures=",failures)
    main.queue_free()
    await ticks(8)
    quit(failures)
func inventory_and_gate(id: String) -> void:
    var inv=adapter.inventory
    var widget:=hud.get_node("HUDRoot/BottomRightInventory")
    inv.clear_items()
    inv.grant(&"LuckyRabbitFoot")
    inv.grant(&"ChocolateCake")
    inv.grant(&"LuckyCoin")
    for i in 3:
        await tap([KEY_1,KEY_2,KEY_3][i])
        await ticks(15)
        check(widget.visuals[i].scale.is_equal_approx(Vector2.ONE*1.10) and widget.buttons[i].scale==Vector2.ONE,id+" selected slot visibly enlarges without changing hit area "+str(i))
        for j in 3:
            if i!=j:check(widget.visuals[j].scale.is_equal_approx(Vector2.ONE),id+" other slots restore normal size "+str(j))
    await shot(id+"_selected_slot")
    inv.clear_items()
    hud.clear_notifications()
    var cake=level._perks.pickups[0]
    actor.global_position=cake.global_position+Vector3.UP*0.03
    actor.velocity=Vector3.ZERO
    await ticks(25)
    var notice: Control=hud.get_node("HUDRoot/CenterBottomNotification")
    check(notice.visible and absf(notice.get_rect().get_center().x-960)<0.1 and notice.position.y>860,id+" actual pickup notice centered below gameplay")
    check(inv.quantity(&"ChocolateCake")==1 and level._perks.boost_remaining==0,id+" cake still stored for E use")
    await shot(id+"_centered_notice")
    inv.grant(&"LuckyCoin")
    var gate: Node3D=level.get_node("%GeneratedMaze").gates.D1
    actor.global_position=gate.to_global(Vector3(0,0,1.1))
    actor.velocity=Vector3.ZERO
    await ticks(80)
    var hint:=hud.get_node("HUDRoot/Interaction")
    var camera:=actor.get_viewport().get_camera_3d()
    var point:=camera.unproject_position(gate.global_position+Vector3.UP*1.35)
    check(hint.visible and hint.keycap.visible and hint.title.text=="开启" and not hint.detail.visible,id+" short E opening prompt")
    check(adapter.interaction_target==gate and absf(hint.position.y-point.y)<80 and hint.position.distance_to(point)<300,id+" prompt sits beside actual door rather than screen bottom")
    await shot(id+"_door_attached_prompt")
    var old: Vector2=hint.position
    level.get_node("%FollowRig").yaw+=0.35
    await ticks(18)
    check(hint.position.distance_to(old)>1.0,id+" prompt follows camera projection")
    await tap(KEY_E)
    await ticks(5)
    check(gate.is_open and inv.quantity(&"LuckyCoin")==0 and inv.quantity(&"ChocolateCake")==1,id+" relocated prompt preserves door interaction priority")
func cube_prompt() -> void:
    level.race.request_mode("Race")
    while level.race.state!="RACING":await ticks(1)
    check(hud.task_label.text==TASKS[2],"Race uses requested Maze03 task too")
    actor.global_position=Vector3(24,0.04,23.6)
    actor.velocity=Vector3.ZERO
    await ticks(80)
    var hint:=hud.get_node("HUDRoot/Interaction")
    var cube=level.race.sanctuary.cube
    var point:=actor.get_viewport().get_camera_3d().unproject_position(cube.global_position)
    check(hint.visible and hint.title.text=="激活" and hint.keycap.visible,"short cube E prompt")
    check(adapter.interaction_target==cube and hint.position.distance_to(point)<300 and absf(hint.position.y-point.y)<80,"prompt anchored beside cube")
    await shot("maze03_cube_attached_prompt")
    await tap(KEY_E)
    await ticks(8)
    check(level.race.sanctuary_used and level.race.sanctuary_active,"cube E still activates original sanctuary")
func modal_checks(id: String) -> void:
    for kind: String in ["exit","restart"]:
        hud.open_overlay(kind)
        await frames(8)
        var panel: PanelContainer=hud.panels[kind]
        var body: VBoxContainer=panel.get_child(0)
        var row: HBoxContainer=body.get_child(2)
        check(body.alignment==BoxContainer.ALIGNMENT_CENTER and row.alignment==BoxContainer.ALIGNMENT_CENTER,id+" "+kind+" content and buttons centered")
        check(body.get_child(0).horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER and body.get_child(1).horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER,id+" "+kind+" text centered")
        check(body.get_child(0).get_theme_font_size("font_size")==32 and row.get_child(1).get_theme_font_size("font_size")==24 and row.get_child(1).size.y>=56,id+" "+kind+" larger title and button")
        check(body.get_child(0).global_position.y>panel.global_position.y+55,id+" "+kind+" content lowered away from top edge")
        if id=="maze":await shot(kind+"_centered_note")
        await click(row.get_child(0))
        check(not paused and hud.overlay.is_empty(),id+" "+kind+" actual cancel remains usable")
func exhaustion_checks(id: String) -> void:
    actor.reset_player()
    actor.controls_enabled=true
    var view: Camera3D=Camera3D.new()
    actor.get_parent().add_child(view)
    var original: Camera3D=actor.movement_camera
    actor.movement_camera=view
    actor.stamina.current=0.15
    actor.stamina.is_exhausted=false
    hold(KEY_W,true)
    await tap(KEY_SHIFT)
    await ticks(6)
    check(actor.stamina.exhaustion_count>0 and not actor.sprint_toggled,id+" actual running exhaustion switches sprint toggle off")
    await tap(KEY_SHIFT)
    check(not actor.sprint_toggled,id+" pressing Shift at exhausted stamina cannot queue automatic running")
    await ticks(155)
    check(actor.stamina.can_sprint() and not actor.sprint_toggled and not actor.stamina.is_sprinting,id+" recovered stamina stays in walk mode without another Shift press")
    await tap(KEY_SHIFT)
    check(actor.sprint_toggled,id+" fresh Shift press explicitly re-enables sprint after recovery")
    hold(KEY_W,false)
    actor.sprint_toggled=false
    actor.movement_camera=original
    view.queue_free()

func compass_checks() -> void:
    var compass:=hud.get_node("HUDRoot/TopLeftCompass")
    var Art=load("res://modules/game_hud/assets.gd")
    var base: Image=Art.slice("compass_base").get_image()
    var needle: Image=Art.slice("compass_needle").get_image()
    check(base.get_pixel(640,60).a<0.1 and base.get_pixel(640,82).a>0.5,"compass retains a thinner original white rim without old outer fringe")
    check(needle.get_width()<500 and needle.get_height()<600,"independent needle carries no surrounding paper")
    check(base.get_pixel(770,400).b>0.5,"old baked needle removed from static dial")
    actor.controls_enabled=false
    for angle: float in [0.0,PI*0.5,PI,-PI*0.5]:
        actor.visual.rotation.y=-angle
        await ticks(70)
        check(absf(angle_difference(compass.paint.get_shader_parameter("heading"),angle))<0.015,"clean needle and arc update together at "+str(angle))
        await shot("compass_clean_"+str(roundi(rad_to_deg(angle))))
    hud.get_node("HUDRoot/BottomLeftStamina").set_ratio(0.5)
    await shot("thin_outline_half_stamina")
    actor.reset_player()
    actor.controls_enabled=true
