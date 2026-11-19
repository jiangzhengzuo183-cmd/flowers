extends "res://tests/game_hud/check_v2.gd"
func run() -> void:
    Input.use_accumulated_input=false
    Preferences.path="user://hud_v2_race_test.cfg"
    Preferences.loaded=true
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1280,720)
    root.position=Vector2i(-2800,-1800)
    main=load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene=main
    main.show_scene("maze03")
    await ticks(30)
    bind()
    adapter.mouse_look.release_cursor()
    hud.close_overlay()
    paused=false
    await race_checks()
    var race: Node=level.race
    check(race.mouse_finished,"mouse finishes final full run")
    var facing: Vector3=-race.mouse.pose.global_basis.z
    var toward_approach: Vector3=(race.route.points[-2]-race.route.points[-1]).normalized()
    check(facing.dot(toward_approach)>0.99,"finish mouse faces back toward approaching Charlie")
    actor.position=race.recorder.finish_trigger.global_position-Vector3.UP*0.8
    actor.velocity=Vector3.ZERO
    await ticks(8)
    check(race.state=="FINISHED" and actor.visual.celebrating,"race Charlie dances after actual arrival")
    await ticks(280)
    check(actor.visual.celebrating,"race dance lasts longer than4.2seconds")
    await ticks(165)
    check(adapter.play_flow.result_panel.visible and adapter.play_flow.result_title.text=="失败","mouse-first final defeat poster")
    check(not race.hud.result_panel.visible,"legacy race result is not duplicated")
    race.pending_mode="Race"
    level.reset_walk()
    for i in 500:
        if race.state=="RACING":break
        await ticks(1)
    check(race.state=="RACING" and not adapter.play_flow.result_panel.visible,"restart resets result countdown and race")
    actor.position=race.recorder.finish_trigger.global_position-Vector3.UP*0.8
    actor.velocity=Vector3.ZERO
    await ticks(8)
    check(race.result.outcome=="charlie" and actor.visual.celebrating,"Charlie-first victory still judged on actual arrival")
    await ticks(440)
    check(adapter.play_flow.result_panel.visible and adapter.play_flow.result_title.text=="胜利","Charlie-first victory poster")
    var file:=FileAccess.open(OUT+"race-v2-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":report,"failures":failures,"arrivals":arrivals},"  "))
    file.close()
    print("RACE V2 checks=",report.size()," failures=",failures," arrivals=",arrivals)
    main.queue_free()
    await ticks(5)
    quit(failures)
