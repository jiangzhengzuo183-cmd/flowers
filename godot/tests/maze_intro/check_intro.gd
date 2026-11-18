extends SceneTree
const OUTPUT := "D:/ChatGPT/献给阿尔吉侬的花束/.verification/maze-intro/"
const Preferences := preload("res://modules/game_hud/game_settings.gd")
var main: Control
var level: Control
var runtime: Node
var intro: Node
var actor: CharacterBody3D
var checks: Array[Dictionary]=[]
var failures:=0
var sweeps: Array[Dictionary]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
    checks.append({"ok":ok,"message":label})
    if not ok:
        failures+=1
        push_error(label)
func ticks(n: int) -> void:
    for i in n:
        await physics_frame
        await process_frame
func key(code: Key) -> void:
    var e:=InputEventKey.new()
    e.physical_keycode=code
    e.pressed=true
    Input.parse_input_event(e)
    await process_frame
    e=InputEventKey.new()
    e.physical_keycode=code
    e.pressed=false
    Input.parse_input_event(e)
    await process_frame
func shot(id: String) -> void:
    if DisplayServer.get_name()=="headless":return
    await process_frame
    RenderingServer.force_draw(false)
    root.get_texture().get_image().save_png(OUTPUT+id+".png")
func bind() -> void:
    level=main.active_scene
    runtime=level.game_hud
    intro=runtime.intro
    actor=runtime.actor
func wait_age(seconds: float) -> void:
    var guard:=0
    while intro.active and intro.age<seconds and guard<500:
        await ticks(1)
        guard+=1
func run() -> void:
    Input.use_accumulated_input=false
    Preferences.path="user://intro_verification_settings.cfg"
    Preferences.loaded=true
    Preferences.aspect=0
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1920,1080)
    root.position=Vector2i.ZERO
    main=load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene=main
    await ticks(3)
    for id: String in ["maze","maze02","maze03"]:
        main.show_scene(id)
        await ticks(6)
        bind()
        check(intro.active and intro.plays==1,id+" one shared cinematic starts exactly once")
        check(intro.scene_file_path=="res://modules/maze_intro/MazeIntroController.tscn",id+" same reusable scene")
        check(not actor.controls_enabled and runtime.clock.elapsed==0.0,id+" input locked and clock zero")
        check(runtime.hud.get_node("HUDRoot").modulate.a<0.01,id+" HUD initially hidden")
        check(not runtime.play_flow.countdown.visible,id+" countdown hidden during cinematic")
        check(intro.title.text==["第一次测试","第二次测试","第三次测试"][["maze","maze02","maze03"].find(id)],id+" correct test title")
        var spawn: Vector3=actor.global_position
        var distance: float=intro.rig.distance
        var pitch: float=intro.rig.pitch
        var fov: float=intro.game_camera.fov
        var rig_yaw: float=intro.rig.yaw
        var v: Vector2=actor.get_viewport().get_visible_rect().size
        var map_rect:=Rect2(Vector2(4,4),v-Vector2(8,8))
        var full_map:=true
        for point: Vector3 in [Vector3.ZERO,Vector3(actor.map_size.x,0,0),Vector3(0,0,actor.map_size.y),Vector3(actor.map_size.x,0,actor.map_size.y)]:
            full_map=full_map and map_rect.has_point(intro.camera.unproject_position(point))
        check(full_map,id+" four map corners fit actual 3D overhead view")
        if id=="maze03":
            check(level.race.current_mode=="Race",id+" defaults to Race")
            check(level.race.state=="PREPARATION" and level.race.elapsed==0.0,id+" race waits for intro")
        await shot(id+"_01_overview")
        await key(KEY_E)
        await key(KEY_SHIFT)
        await key(KEY_SPACE)
        var wheel:=InputEventMouseButton.new()
        wheel.button_index=MOUSE_BUTTON_WHEEL_UP
        wheel.pressed=true
        Input.parse_input_event(wheel)
        var motion:=InputEventMouseMotion.new()
        motion.relative=Vector2(50,30)
        motion.screen_relative=motion.relative
        Input.parse_input_event(motion)
        await ticks(2)
        check(actor.global_position.distance_to(spawn)<0.08 and not actor.sprint_toggled,id+" E/Shift/jump cannot start gameplay")
        check(is_equal_approx(intro.rig.distance,distance) and is_equal_approx(intro.rig.yaw,rig_yaw),id+" cinematic blocks camera input")
        await wait_age(1.0)
        await shot(id+"_02_clouds")
        await wait_age(1.9)
        check(intro.title_group.modulate.a>0.99,id+" title stable during covered hold")
        await shot(id+"_03_title")
        check(runtime.clock.elapsed==0.0 and not actor.controls_enabled,id+" clock still zero behind title")
        await wait_age(3.35)
        await shot(id+"_04_descent")
        var last: Vector3=intro.camera.global_position
        var hits: Array=[]
        var max_step:=0.0
        while intro.active:
            await physics_frame
            if is_instance_valid(intro.camera):
                var next: Vector3=intro.camera.global_position
                var q:=PhysicsRayQueryParameters3D.create(last,next,5,[actor.get_rid()])
                var hit:=actor.get_world_3d().direct_space_state.intersect_ray(q)
                if not hit.is_empty():hits.append(str(hit.collider.get_path()))
                max_step=maxf(max_step,last.distance_to(next))
                last=next
            await process_frame
        sweeps.append({"maze":id,"hits":hits,"max_frame_move":max_step,"handoff_error":intro.handoff_error})
        check(hits.is_empty(),id+" descending camera never crosses solid geometry")
        check(intro.handoff_error<0.002,id+" exact camera handoff")
        check(actor.get_viewport().get_camera_3d()==intro.game_camera and intro.rig.enabled,id+" original follow camera restored")
        check(is_equal_approx(intro.rig.distance,distance) and is_equal_approx(intro.rig.pitch,pitch) and absf(intro.game_camera.fov-fov)<0.01,id+" original camera parameters preserved")
        check(runtime.hud.get_node("HUDRoot").modulate.a==1.0 and not intro.blocker.visible,id+" clouds gone and HUD visible")
        check(not actor.controls_enabled,id+" existing countdown follows cinematic")
        await shot(id+"_05_countdown")
        if id=="maze03":
            check(level.race.elapsed==0.0 and level.race._phase_age<0.1,id+" mouse timer/preparation only starts after intro")
        await ticks(225)
        check(actor.controls_enabled,id+" GO restores player controls")
        var elapsed: float=level.race.elapsed if id=="maze03" else runtime.clock.elapsed
        check(elapsed>0.0 and elapsed<1.0,id+" timer starts at GO excluding entire intro/countdown")
        check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" returns to automatic mouse look")
        await shot(id+"_06_gameplay")
        check(is_equal_approx(actor.visual.VICTORY_DURATION,4.5),id+" continuous dance set to 4.5 seconds")
        var before: float=elapsed
        await key(KEY_ESCAPE)
        check(paused and runtime.hud.overlay=="debug",id+" ESC tools still open")
        await ticks(8)
        var frozen: float=level.race.elapsed if id=="maze03" else runtime.clock.elapsed
        check(is_equal_approx(before,frozen) or absf(before-frozen)<0.05,id+" pause stops timer")
        runtime.hud.close_overlay()
        await ticks(2)
        if id=="maze03":await race_regression()
        else:await finish_dance(id)
    await exploration_and_reset()
    asset_checks()
    var out:=FileAccess.open(OUTPUT+"results.json",FileAccess.WRITE)
    out.store_string(JSON.stringify({"checks":checks,"failures":failures,"camera_sweeps":sweeps},"  "))
    out.close()
    print("MAZE INTRO checks=",checks.size()," failures=",failures)
    main.queue_free()
    await ticks(3)
    quit(1 if failures>0 else 0)
func finish_dance(id: String) -> void:
    # Completion uses the original long clip, at normal speed, for one uninterrupted section.
    level.completed=true
    await ticks(4)
    var animation: Animation=actor.visual.animation_player.get_animation("Dance")
    check(animation.loop_mode==Animation.LOOP_NONE,id+" dance never loops/repeats")
    await ticks(220)
    check(actor.visual.celebrating and actor.visual.animation_player.current_animation_position>3.5,id+" dance continues through original clip")
    await ticks(60)
    check(not actor.visual.celebrating and runtime.play_flow.result_panel.visible,id+" dance ends and result shown after 4.5 seconds")
func race_regression() -> void:
    # Allow a real complete opponent run: no teleporting/speed override.
    runtime.mouse_look.release_cursor()
    root.position=Vector2i(-2800,-1800)
    for i in 4000:
        if level.race.mouse_finished:break
        await ticks(1)
    var race: Node=level.race
    check(race.mouse_finished and absf(race.mouse_time-55.5)<0.035,"Race actual opponent arrival remains 55.5s")
    check(race.state=="RACING" and actor.controls_enabled,"mouse arrival leaves Charlie playing and clock running")
    var previous: float=race.elapsed
    await ticks(65)
    check(race.elapsed>previous+0.9,"race timer continues after mouse finish")
    actor.global_position=race.recorder.finish_trigger.global_position-Vector3.UP*0.8
    actor.velocity=Vector3.ZERO
    await ticks(5)
    check(race.state=="FINISHED" and race.result.outcome=="mouse","Charlie arrival after mouse resolves actual loss")
    var finished: float=race.elapsed
    await ticks(280)
    check(runtime.play_flow.result_panel.visible and is_equal_approx(finished,race.elapsed),"Race result waits 4.5s dance then clock remains stopped")
    root.position=Vector2i.ZERO
func exploration_and_reset() -> void:
    root.set_meta(&"hud_restart_mode","Explore")
    main.restart_active_maze()
    await ticks(6)
    bind()
    check(level.race.current_mode=="Explore" and level.race.mouse==null,"explicit Explore mode is retained on restart")
    await ticks(310)
    check(not intro.active and actor.controls_enabled and runtime.clock.elapsed>0.0,"Maze03 Explore starts after intro without race countdown")
    check(not is_instance_valid(level.race.hud),"Explore still has no race UI/opponent")
    level.reset_walk()
    await ticks(6)
    check(intro.active and intro.plays==2 and runtime.clock.elapsed==0.0,"developer reset reuses one controller and zeroes clock")
    check(level.find_children("MazeIntroController","Node",false,false).size()==1,"restart cannot duplicate intro controller")
    var saved: Node=intro
    # Interrupt a live cinematic with a scene change, then enter a new maze.
    main.show_scene("maze")
    await ticks(6)
    bind()
    check(not is_instance_valid(saved),"leaving during intro releases previous controller")
    check(actor.get_viewport().get_camera_3d()==intro.camera,"next maze owns its own temporary camera")
    await ticks(510)
    check(actor.controls_enabled and not intro.active,"scene change cannot leave controls locked")
func asset_checks() -> void:
    var art=load("res://assets/UI/HUD/hand_cursor/regions.gd")
    check(art.SIZE==Vector2i(53,60),"cursor enlarged from 44 to 52px visible height")
    var tip: Vector2i=art.HOTSPOT
    var frames: Array[Image]=[]
    for n in 3:frames.append(Image.load_from_file(ProjectSettings.globalize_path("res://assets/UI/HUD/hand_cursor/derived/frame_%d.png"%n)))
    var fixed:=true
    for y in range(maxi(0,tip.y-5),tip.y+6):
        for x in range(maxi(0,tip.x-5),tip.x+6):
            if frames[0].get_pixel(x,y)!=frames[1].get_pixel(x,y) or frames[0].get_pixel(x,y)!=frames[2].get_pixel(x,y):fixed=false
    check(fixed,"larger cursor keeps stable clickable tip during boil")
    var brown:=Color8(76,61,47)
    var same:=true
    var original_weight:=true
    for n in 11:
        var file: String="colon" if n==10 else "digit_%d"%n
        var src:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/UI/HUD/slices/"+file+".png"))
        var ink:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/UI/HUD/timer_bold/"+file+".png"))
        var count:=0
        var original:=0
        for y in ink.get_height():
            for x in ink.get_width():
                var c:=ink.get_pixel(x,y)
                var s:=src.get_pixel(x,y)
                if c.a>0.0:
                    if absf(c.r-brown.r)>0.005 or absf(c.g-brown.g)>0.005 or absf(c.b-brown.b)>0.005:same=false
                if c.a>0.5:count+=1
                if s.a>0.5 and s.r<0.65:original+=1
        if absf(float(count)/maxi(1,original)-1.0)>0.1:original_weight=false
    check(same,"all 11 timer glyphs have one solid brown with no white outline/seams")
    check(original_weight,"timer weight follows original brown glyph, no expansion into removed outline")
