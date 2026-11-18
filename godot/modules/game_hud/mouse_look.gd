extends Node
## Shared gameplay pointer ownership. Double-click blank gameplay toggles mouse look.
const Preferences := preload("res://modules/game_hud/game_settings.gd")
var runtime: Node
var _cursor_free := false
var _focused := true
var _requested_mode := -1
var _skip_capture_warp := false
func install(adapter: Node) -> void:
    name="GameplayMouseLook"
    runtime=adapter
    process_mode=Node.PROCESS_MODE_ALWAYS
    get_window().focus_exited.connect(_focus_lost)
    get_window().focus_entered.connect(_focus_gained)
    runtime.hud.overlay_changed.connect(_overlay_changed)
    _resume_gameplay.call_deferred()
func _overlay_changed(open: bool) -> void:
    if open:sync()
    else:_resume_gameplay.call_deferred()
func _resume_gameplay() -> void:
    if not is_inside_tree() or not is_instance_valid(runtime) or runtime._changing:return
    if get_window()==null:return
    if not OS.has_feature("web") and DisplayServer.get_name()!="headless":get_window().grab_focus()
    capture_cursor()
func wants_capture() -> bool:
    return is_instance_valid(runtime) and not runtime._changing and runtime.scene.walk_mode and runtime.hud.overlay.is_empty() and not get_tree().paused and not _cursor_free and _focused
func release_cursor() -> void:
    _cursor_free=true
    sync()
func capture_cursor() -> void:
    _cursor_free=false
    sync(true)
func sync(force: bool = false) -> void:
    var desired:=Input.MOUSE_MODE_CAPTURED if wants_capture() else Input.MOUSE_MODE_VISIBLE
    if force or desired!=_requested_mode or (not OS.has_feature("web") and Input.mouse_mode!=desired):
        if desired==Input.MOUSE_MODE_CAPTURED and Input.mouse_mode!=desired:_skip_capture_warp=true
        _requested_mode=desired
        Input.mouse_mode=desired
func _process(_delta: float) -> void:
    sync()
func _over_interface() -> bool:
    var hovered: Control=get_viewport().gui_get_hovered_control()
    return hovered!=null and runtime.hud.get_node("HUDRoot").is_ancestor_of(hovered)
func _input(event: InputEvent) -> void:
    if runtime.is_intro_active():
        get_viewport().set_input_as_handled()
        return
    if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
        if event.double_click and runtime.hud.overlay.is_empty() and runtime.scene.walk_mode:
            if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:release_cursor()
            elif not _over_interface():capture_cursor()
            else:return
            get_viewport().set_input_as_handled()
            return
        if wants_capture() and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED and not _over_interface():
            sync(true)
            get_viewport().set_input_as_handled()
            return
    if event is InputEventMouseMotion and wants_capture() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
        if _skip_capture_warp:
            _skip_capture_warp=false
            get_viewport().set_input_as_handled()
            return
        var motion: InputEventMouseMotion=event.duplicate()
        var pixels: Vector2=event.screen_relative if event.screen_relative!=Vector2.ZERO else event.relative
        motion.relative=pixels*(0.0025/0.007)*Preferences.sensitivity
        motion.button_mask=MOUSE_BUTTON_MASK_RIGHT
        runtime.scene.get_node("%FollowRig").handle_input(motion)
        get_viewport().set_input_as_handled()
func _focus_lost() -> void:
    _focused=false
    sync()
func _focus_gained() -> void:
    _focused=true
    sync()
func _exit_tree() -> void:
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
