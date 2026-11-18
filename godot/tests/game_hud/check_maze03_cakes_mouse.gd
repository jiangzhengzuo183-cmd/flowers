extends "res://tests/game_hud/check_clicks.gd"
const CakeItems:=preload("res://modules/maze03_final/cake_items.gd")
const Routes:=preload("res://modules/maze_items/walkable_routes.gd")
class TrialRoutes extends Routes:
    func configure_trial(player: CharacterBody3D, architecture: Node3D) -> void:
        _actor=player
        _size=Vector2i((player.map_size/SPACING).round())
        _capsule=player.find_children("*","CollisionShape3D",false,false)[0].shape as CapsuleShape3D
        _ray.collision_mask=player.collision_mask
        _sweep.collision_mask=player.collision_mask
        _sweep.shape=_capsule
        for body: StaticBody3D in architecture.find_children("*","StaticBody3D",true,false):
            _floor_ids[body.get_rid()]=true
var arrivals: Array[float]=[]
func hold(code: Key, pressed: bool) -> void:
    var key:=InputEventKey.new()
    key.physical_keycode=code
    key.pressed=pressed
    Input.parse_input_event(key)
func move_mouse(delta: Vector2) -> void:
    var motion:=InputEventMouseMotion.new()
    motion.relative=delta
    motion.position=Vector2(960,540)
    motion.global_position=motion.position
    motion.button_mask=0
    Input.parse_input_event(motion)
func run() -> void:
    Input.use_accumulated_input=false
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1920,1080)
    root.position=Vector2i.ZERO
    main=load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene=main
    for id: String in ["maze","maze02","maze03"]:
        main.show_scene(id)
        await ticks(35)
        bind()
        root.grab_focus()
        await ticks(5)
        var pack:=hud.get_node("HUDRoot/BottomRightInventory")
        var stamina:=hud.get_node("HUDRoot/BottomLeftStamina")
        check(pack.find_children("*","ColorRect",true,false).is_empty(),id+" selection yellow underline removed")
        check(stamina.bolts[1].position.x-stamina.bolts[0].get_rect().end.x==4,id+" tighter four-pixel flash spacing")
        check(stamina.bolts[0].position.x==8 and stamina.bolts[-1].get_rect().end.x==352,id+" stamina group centered in original footprint")
        await mouse_checks(id)
        if id!="maze03":await shot(id+"_mouse_look_hud")
    await cake_checks()
    await race_checks()
    var result:={"failures":failures,"checks":report,"mouse_arrivals":arrivals}
    var file:=FileAccess.open(OUT+"maze03-cakes-mouse-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(result,"  "))
    file.close()
    print("MAZE03 CAKES AND MOUSE checks=",report.size()," failures=",failures," arrivals=",arrivals)
    main.queue_free()
    await ticks(8)
    check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"leaving game releases pointer")
    quit(failures)
func mouse_checks(id: String) -> void:
    var rig:=level.get_node("%FollowRig")
    var look=adapter.mouse_look
    look._focus_gained()
    await ticks(3)
    check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" gameplay captures mouse by default")
    var old: float=rig.yaw
    move_mouse(Vector2(20,-8))
    await ticks(2)
    check(absf(angle_difference(old,rig.yaw)+0.14)<0.025,id+" mouse motion rotates without holding a button and only once")
    hold(KEY_ALT,true)
    await ticks(2)
    check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,id+" Alt releases pointer for HUD")
    old=rig.yaw
    move_mouse(Vector2(30,10))
    await ticks(2)
    check(is_equal_approx(old,rig.yaw),id+" released pointer does not drag the camera")
    hold(KEY_ALT,false)
    await ticks(2)
    check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" releasing Alt restores mouse look")
    await tap(KEY_ESCAPE)
    check(paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,id+" ESC pauses and releases pointer")
    old=rig.yaw
    move_mouse(Vector2(30,10))
    await frames(3)
    check(is_equal_approx(old,rig.yaw),id+" paused menu blocks camera motion")
    await tap(KEY_ESCAPE)
    await ticks(2)
    check(not paused and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" closing ESC resumes mouse capture")
    var before: float=rig.distance
    var wheel:=InputEventMouseButton.new()
    wheel.button_index=MOUSE_BUTTON_WHEEL_UP
    wheel.position=Vector2(960,540)
    wheel.global_position=wheel.position
    wheel.pressed=true
    Input.parse_input_event(wheel)
    await ticks(2)
    check(rig.distance<before,id+" wheel zoom remains usable")
    level.show_top_view()
    await ticks(2)
    check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,id+" overview releases pointer")
    level.set_walk_mode(true)
    await ticks(2)
    check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" returning to gameplay recaptures")
    look._focus_lost()
    check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,id+" focus loss releases pointer")
    look._focus_gained()
    await ticks(2)
    check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" focus return restores pointer mode")
    var menu:=hud.get_node("HUDRoot/TopRightMenu")
    await click(menu.get_child(1))
    print("HUD HIT ",id," overlay=",hud.overlay," mode=",Input.mouse_mode," alt=",look._alt_down," window=",root.position)
    check(hud.overlay=="restart" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,id+" actual HUD click opens confirmation with free cursor")
    await click(hud.panels.restart.get_child(0).get_child(2).get_child(0))
    await ticks(2)
    check(hud.overlay.is_empty() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,id+" cancel restores captured gameplay")
func cake_checks() -> void:
    var inv=adapter.inventory
    var perks=level._perks
    check(is_instance_valid(inv) and inv==level._items.inventory,"Maze03 binds existing shared inventory")
    check(perks.pickups.size()==2 and not perks.enable_flour,"exactly two cakes; no punishment props added")
    var nav:=TrialRoutes.new()
    nav.configure_trial(actor,level.get_node("%GeneratedMaze"))
    for batch in 500:
        nav.build_batch()
        if nav.ready:break
        if batch%10==0:await ticks(1)
    check(nav.ready,"build real Maze03 walking graph")
    for i in 2:
        var cake=perks.pickups[i]
        var route: String=CakeItems.PLACEMENTS[i].route
        check(cake.position.is_equal_approx(CakeItems.PLACEMENTS[i].point),"correct "+route+" cake location")
        var path:=nav.path_to_nearest(actor.spawn_point,PackedVector3Array([cake.position]))
        check(path.size()>1,"route "+route+" cake accessible from entrance through actual collision graph")
        var floor_hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cake.position+Vector3.UP*0.3,cake.position-Vector3.UP*0.3,1))
        check(not floor_hit.is_empty() and absf(floor_hit.position.y-cake.position.y)<0.05,"route "+route+" cake sits above real floor")
        check(cake.collision_layer==0 and cake.find_children("*","PhysicsBody3D",true,false).is_empty(),"route "+route+" cake has no blocking body")
        actor.controls_enabled=false
        var inspection:=Camera3D.new()
        actor.get_parent().add_child(inspection)
        inspection.look_at_from_position(cake.position+Vector3(0.7,1.9,1.5),cake.position+Vector3.UP*0.85)
        inspection.make_current()
        await ticks(4)
        await shot("maze03_route_"+route+"_cake")
        inspection.queue_free()
        level.get_node("%FollowRig").camera.make_current()
        actor.controls_enabled=true
        actor.global_position=cake.global_position+Vector3.UP*0.03
        actor.velocity=Vector3.ZERO
        await ticks(30)
        check(inv.quantity(&"ChocolateCake")==i+1,"route "+route+" actual pickup enters a separate physical slot")
        check(perks.boost_remaining==0.0,"route "+route+" pickup waits for active use")
    var pack:=hud.get_node("HUDRoot/BottomRightInventory")
    check(pack.icons[0].texture!=null and pack.icons[1].texture!=null,"Maze03 cakes visible in shared HUD")
    actor.global_position=actor.spawn_point
    actor.velocity=Vector3.ZERO
    await ticks(25)
    await tap(KEY_1)
    var restored: int=actor.stamina.restore_counts.get(&"cake",0)
    await tap(KEY_E)
    await ticks(5)
    check(inv.quantity(&"ChocolateCake")==1 and perks.boost_remaining>7.5,"E uses one stored Maze03 cake")
    check(actor.move_speed_multiplier==1.3 and actor.stamina.restore_counts.get(&"cake",0)==restored+1,"Maze03 cake uses original stamina and speed effects")
    await shot("maze03_cake_inventory")
    level.reset_walk()
    await ticks(8)
    check(inv.item_count()==0 and perks.boost_remaining==0 and perks.pickups.size()==2,"restart clears inventory/effect and restores both cakes")
func race_checks() -> void:
    var manager=level.race
    check(manager.settings.target_seconds==55.5,"race target configured55.5")
    for attempt in 3:
        manager.pending_mode="Race"
        level.reset_walk()
        for phase in 600:
            if manager.state in ["RACING","ERROR"]:break
            await ticks(1)
        check(manager.state=="RACING","race "+str(attempt+1)+" starts successfully")
        if manager.state!="RACING":
            print("RACE START ERROR state=",manager.state," paused=",paused," overlay=",hud.overlay," position=",actor.position)
            break
        for frame in 3500:
            if manager.mouse_finished:break
            if frame%600==0:print("RUN PROGRESS ",attempt+1," state=",manager.state," elapsed=",manager.elapsed," paused=",paused," overlay=",hud.overlay," mouse=",is_instance_valid(manager.mouse))
            await ticks(1)
        arrivals.append(manager.mouse_time)
        check(manager.mouse_finished and absf(manager.mouse_time-55.5)<0.025,"race "+str(attempt+1)+" actual mouse arrival55.5: "+str(manager.mouse_time))
        check(manager.hesitation_count==2 and manager.mouse.current_clip==&"Dance","fixed route hesitations and finish animation retained")
        var before: float=manager.elapsed
        await ticks(65)
        check(manager.elapsed>before+1.0 and actor.controls_enabled,"mouse first still leaves Charlie moving and clock running")
        print("MOUSE55.5 run=",attempt+1," actual=",manager.mouse_time)
        if attempt==0:
            actor.global_position=manager.recorder.finish_trigger.global_position-Vector3.UP*0.8
            actor.velocity=Vector3.ZERO
            await ticks(10)
            check(manager.state=="FINISHED" and manager.result.outcome=="mouse","Charlie subsequently finishes and receives actual result")
    check(arrivals.size()==3 and arrivals.max()-arrivals.min()<0.002,"three full runs are deterministic")

