extends Node
## One scene-local cinematic shared by all formal mazes. Gameplay keeps its own clocks.
signal started
signal completed
@export_range(4.0,6.0,0.1) var duration_seconds := 5.0
@export_range(1.05,1.4,0.01) var overview_padding := 1.16
@export var overview_height := 0.0
@export var overview_center := Vector3.INF
var runtime: Node
var active := false
var age := 0.0
var maze_number := 1
var test_title := "第一次测试"
var game_mode := "Explore"
var camera: Camera3D
var game_camera: Camera3D
var rig: Node3D
var canvas: CanvasLayer
var blocker: Control
var clouds: ColorRect
var title_group: Control
var title: Label
var subtitle: Label
var paint: ShaderMaterial
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
    test_title=information.get("title",["第一次测试","第二次测试","第三次测试"][maze_number-1])
    rig=runtime.scene.get_node("%FollowRig")
    game_camera=information.get("game_camera",rig.camera)
    overview_height=information.get("overview_height",overview_height)
    overview_center=information.get("overview_center",overview_center)
    game_mode=information.get("game_mode","Explore")
    _hud_root=runtime.hud.get_node("HUDRoot")
    process_priority=1000
    process_physics_priority=-1000
    _build_overlay()
    runtime.actor.stamina.session_reset.connect(begin)
    begin()

func _build_overlay() -> void:
    canvas=CanvasLayer.new()
    canvas.name="MazeEntranceOverlay"
    canvas.layer=30
    add_child(canvas)
    blocker=Control.new()
    blocker.name="InputBlocker"
    canvas.add_child(blocker)
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    blocker.mouse_filter=Control.MOUSE_FILTER_STOP
    clouds=ColorRect.new()
    clouds.name="SoftCloudLayers"
    blocker.add_child(clouds)
    clouds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    clouds.mouse_filter=Control.MOUSE_FILTER_IGNORE
    paint=ShaderMaterial.new()
    paint.shader=preload("res://modules/maze_intro/clouds.gdshader")
    clouds.material=paint
    title_group=Control.new()
    title_group.name="TestTitle"
    blocker.add_child(title_group)
    title_group.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    title_group.offset_left=-400
    title_group.offset_right=400
    title_group.offset_top=-60
    title_group.offset_bottom=60
    title_group.pivot_offset=Vector2(400,60)
    title_group.mouse_filter=Control.MOUSE_FILTER_IGNORE
    title=Label.new()
    title.name="Title"
    title.text=test_title
    title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_override("font",preload("res://modules/game_hud/assets.gd").hand_font())
    title.add_theme_font_size_override("font_size",62)
    title.add_theme_color_override("font_color",Color("57493b"))
    title.mouse_filter=Control.MOUSE_FILTER_IGNORE
    title_group.add_child(title)
    title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    subtitle=Label.new()
    subtitle.name="Mode"
    subtitle.text="竞速模式"
    subtitle.add_theme_font_override("font",preload("res://modules/game_hud/assets.gd").hand_font())
    subtitle.add_theme_font_size_override("font_size",22)
    subtitle.add_theme_color_override("font_color",Color("857665"))
    subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    subtitle.position=Vector2(0,104)
    subtitle.size=Vector2(800,32)
    subtitle.mouse_filter=Control.MOUSE_FILTER_IGNORE
    title_group.add_child(subtitle)

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
    runtime.scene.set_meta(&"maze_intro_active",true)
    runtime.play_flow.hold_for_intro()
    _hud_root.modulate.a=0.0
    blocker.show()
    title_group.modulate.a=0.0
    paint.set_shader_parameter("cover",0.0)
    paint.set_shader_parameter("opening",0.0)
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
        rig.enabled=false
        camera.make_current()

func _process(delta: float) -> void:
    if not active:return
    if not is_instance_valid(camera) or not is_instance_valid(game_camera):
        _finish()
        return
    age+=minf(delta,0.1)
    var t:=clampf(age/duration_seconds,0.0,1.0)
    game_mode=runtime.race.current_mode if is_instance_valid(runtime.race) else "Explore"
    subtitle.visible=game_mode=="Race"
    var cover:=smoothstep(0.09,0.27,t)
    var clearing:=smoothstep(0.51,0.96,t)
    paint.set_shader_parameter("cover",cover)
    paint.set_shader_parameter("opening",clearing)
    paint.set_shader_parameter("age",age)
    paint.set_shader_parameter("aspect",blocker.size.x/maxf(1.0,blocker.size.y))
    title_group.modulate.a=smoothstep(0.23,0.31,t)*(1.0-smoothstep(0.51,0.62,t))
    title_group.scale=Vector2.ONE*lerpf(0.985,1.0,smoothstep(0.23,0.34,t))
    _hud_root.modulate.a=smoothstep(0.93,1.0,t)
    var u:=smoothstep(0.53,0.99,t)
    var p0:=start_pose.origin
    var p3:=end_pose.origin
    var p1:=p0.lerp(p3,0.32)
    p1.y=p0.y
    var p2:=p3+Vector3.UP*18.0
    var position:=p0.bezier_interpolate(p1,p2,p3,u)
    var rotation:=start_pose.basis.get_rotation_quaternion().slerp(end_pose.basis.get_rotation_quaternion(),u)
    camera.global_transform=Transform3D(Basis(rotation),position)
    camera.fov=game_camera.fov
    camera.make_current()
    rig.enabled=false
    if t>=1.0:_finish()

func _finish() -> void:
    if _done:return
    _done=true
    active=false
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
    # The temporary camera is parented into the 3D world, so release it explicitly.
    if is_instance_valid(camera):
        camera.queue_free()
        camera=null
    if is_instance_valid(rig):rig.enabled=_saved_rig_enabled
