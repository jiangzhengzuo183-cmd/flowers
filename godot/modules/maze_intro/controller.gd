extends Node
## One scene-local cinematic shared by all formal mazes. Gameplay keeps its own clocks.
signal started
signal completed
@export_range(4.0,8.0,0.1) var duration_seconds := 6.0
@export_range(0.0,2.0,0.05) var overview_hold_seconds := 0.8
@export_range(1.05,1.4,0.01) var overview_padding := 1.16
@export var overview_height := 0.0
@export var overview_center := Vector3.INF
var runtime: Node
var active := false
var age := 0.0
var maze_number := 1
var passage: Node3D
var camera: Camera3D
var game_camera: Camera3D
var rig: Node3D
var canvas: CanvasLayer
var blocker: Control
var start_pose := Transform3D.IDENTITY
var end_pose := Transform3D.IDENTITY
var handoff_error := 0.0
var plays := 0
var _settle_frames := 0
var _saved_rig_enabled := true
var _hud_root: Control
var _end_ready := false
var _done := false

func install(adapter: Node, information: Dictionary = {}) -> void:
    runtime=adapter
    maze_number=information.get("maze_number",runtime.maze_number)
    rig=runtime.scene.get_node("%FollowRig")
    game_camera=information.get("game_camera",rig.camera)
    overview_height=information.get("overview_height",overview_height)
    overview_center=information.get("overview_center",overview_center)
    overview_hold_seconds=information.get("overview_hold_seconds",overview_hold_seconds)
    _hud_root=runtime.hud.get_node("HUDRoot")
    process_priority=1000
    process_physics_priority=-1000
    _build_input_blocker()
    runtime.actor.stamina.session_reset.connect(begin)
    begin()

func _build_input_blocker() -> void:
    canvas=CanvasLayer.new()
    canvas.name="MazeEntranceInput"
    canvas.layer=30
    add_child(canvas)
    blocker=Control.new()
    blocker.name="InputBlocker"
    canvas.add_child(blocker)
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    blocker.mouse_filter=Control.MOUSE_FILTER_STOP

func begin() -> void:
    # The same node is reset in place, including developer 'back to entrance'.
    if not is_instance_valid(runtime) or runtime._changing:return
    _done=false
    plays+=1
    age=0.0
    active=true
    _end_ready=false
    _settle_frames=0
    handoff_error=0.0
    _clear_passage()
    runtime.scene.set_meta(&"maze_intro_active",true)
    runtime.play_flow.hold_for_intro()
    _hud_root.modulate.a=0.0
    blocker.show()
    _saved_rig_enabled=runtime.scene.walk_mode
    runtime.actor.controls_enabled=false
    if is_instance_valid(runtime.race):runtime.race.set_entrance_active(true)
    if not is_instance_valid(game_camera):
        _finish()
        return
    if not is_instance_valid(camera):
        camera=Camera3D.new()
        camera.name="MazeEntranceCamera"
        runtime.actor.get_parent().add_child(camera)
    camera.cull_mask=game_camera.cull_mask
    camera.near=game_camera.near
    camera.far=game_camera.far
    camera.fov=game_camera.fov
    camera.keep_aspect=game_camera.keep_aspect
    var size: Vector2=runtime.actor.map_size
    var centre:=Vector3(size.x*0.5,0.0,size.y*0.5) if overview_center==Vector3.INF else overview_center
    var view_size: Vector2=runtime.actor.get_viewport().get_visible_rect().size
    var aspect:=view_size.x/maxf(1.0,view_size.y)
    var span:=maxf(size.y,size.x/aspect)
    var height:=overview_height if overview_height>0.0 else span*0.5/tan(deg_to_rad(camera.fov)*0.5)*overview_padding
    camera.global_position=centre+Vector3(0,height,4.0)
    camera.look_at(centre,Vector3.UP)
    start_pose=camera.global_transform
    end_pose=game_camera.global_transform
    camera.make_current()
    rig.enabled=false
    started.emit()

func _physics_process(_delta: float) -> void:
    if not active:return
    if not is_instance_valid(runtime.actor) or not is_instance_valid(game_camera):
        _finish()
        return
    runtime.actor.controls_enabled=false
    runtime.actor.velocity.x=0.0
    runtime.actor.velocity.z=0.0
    _settle_frames+=1
    # Race setup may place Charlie beside Algernon during its first two physics frames.
    if not _end_ready and _settle_frames>=4:
        rig.reset_view()
        end_pose=game_camera.global_transform
        _end_ready=true
        passage=preload("res://modules/maze_intro/air_passage.gd").new()
        runtime.actor.get_parent().add_child(passage)
        passage.install(self,maze_number)
        rig.enabled=false
        camera.make_current()

func _process(delta: float) -> void:
    if not active:return
    if not is_instance_valid(camera) or not is_instance_valid(game_camera):
        _finish()
        return
    age+=minf(delta,0.1)
    var t:=clampf(age/duration_seconds,0.0,1.0)
    _hud_root.modulate.a=smoothstep(0.94,1.0,t)
    # Rest on the complete map, ease into the glide, then settle gently at Charlie.
    # Quintic easing has zero velocity and acceleration at both ends.
    var travel_seconds:=maxf(0.1,duration_seconds-overview_hold_seconds-0.15)
    var progress:=clampf((age-overview_hold_seconds)/travel_seconds,0.0,1.0)
    var u:=progress*progress*progress*(progress*(progress*6.0-15.0)+10.0)
    camera.global_transform=pose_at(u)
    if is_instance_valid(passage):passage.update_gain(u)
    camera.fov=game_camera.fov
    camera.make_current()
    rig.enabled=false
    if t>=1.0:_finish()

func pose_at(u: float) -> Transform3D:
    var p0:=start_pose.origin
    var p3:=end_pose.origin
    var p1:=p0.lerp(p3,0.32)
    p1.y=p0.y
    var p2:=p3+Vector3.UP*18.0
    var position:=p0.bezier_interpolate(p1,p2,p3,u)
    var rotation:=start_pose.basis.get_rotation_quaternion().slerp(end_pose.basis.get_rotation_quaternion(),u)
    return Transform3D(Basis(rotation),position)

func _clear_passage() -> void:
    if is_instance_valid(passage):
        passage.hide()
        passage.queue_free()
        passage=null

func _finish() -> void:
    if _done:return
    _done=true
    active=false
    _clear_passage()
    if is_instance_valid(camera) and is_instance_valid(game_camera):
        camera.global_transform=end_pose
        handoff_error=camera.global_position.distance_to(game_camera.global_position)
    if is_instance_valid(game_camera):game_camera.make_current()
    if is_instance_valid(camera):
        camera.queue_free()
        camera=null
    if is_instance_valid(rig):rig.enabled=_saved_rig_enabled
    if is_instance_valid(blocker):blocker.hide()
    if is_instance_valid(_hud_root):_hud_root.modulate.a=1.0
    if is_instance_valid(runtime):
        runtime.scene.set_meta(&"maze_intro_active",false)
        if is_instance_valid(runtime.race):runtime.race.set_entrance_active(false)
        runtime.play_flow.begin_gameplay()
        runtime.mouse_look.capture_cursor()
    completed.emit()

func _exit_tree() -> void:
    _clear_passage()
    # The temporary camera is parented into the 3D world, so release it explicitly.
    if is_instance_valid(camera):
        camera.queue_free()
        camera=null
    if is_instance_valid(rig):rig.enabled=_saved_rig_enabled
