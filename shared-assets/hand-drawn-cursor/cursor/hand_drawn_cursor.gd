extends Node
## Reusable three-frame native cursor. Add this script as an Autoload for all scenes.
## No maze, HUD, mouse-look or input-mode dependencies.
const SOURCE_FRAMES: Array[Texture2D] = [
    preload("frames/frame_0.png"),
    preload("frames/frame_1.png"),
    preload("frames/frame_2.png"),
]
@export_range(1.0,24.0,0.5) var frames_per_second := 8.0
@export var hotspot := Vector2(7,6)
var frames: Array[ImageTexture] = []
var frame := 0
var updates := 0
var _age := 0.0
var _last_frame := -1
var _was_visible := false
var _owns_cursor := false
const OWNER_KEY := &"shared_hand_drawn_cursor_owner"
func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS
    var window:=get_window()
    var existing: Node=window.get_meta(OWNER_KEY) if window.has_meta(OWNER_KEY) else null
    if is_instance_valid(existing) and existing!=self:
        queue_free()
        return
    window.set_meta(OWNER_KEY,self)
    _owns_cursor=true
    # Cache native image textures once. Never allocate textures every animation frame.
    for source: Texture2D in SOURCE_FRAMES:
        frames.append(ImageTexture.create_from_image(source.get_image()))
    _apply(0)
func _apply(index: int) -> void:
    frame=index
    _last_frame=index
    updates+=1
    Input.set_custom_mouse_cursor(frames[index],Input.CURSOR_ARROW,hotspot)
    Input.set_custom_mouse_cursor(frames[index],Input.CURSOR_POINTING_HAND,hotspot)
func _process(delta: float) -> void:
    if not _owns_cursor or frames.is_empty():return
    var window:=get_window()
    var shown: bool=window!=null and window.has_focus() and Input.mouse_mode in [Input.MOUSE_MODE_VISIBLE,Input.MOUSE_MODE_CONFINED]
    if not shown:
        _was_visible=false
        return
    _age+=delta
    var next:=int(floor(_age*frames_per_second))%frames.size()
    if next!=_last_frame or not _was_visible:_apply(next)
    _was_visible=true
func _exit_tree() -> void:
    if not _owns_cursor:return
    var window:=get_window()
    if window!=null and window.has_meta(OWNER_KEY) and window.get_meta(OWNER_KEY)==self:window.remove_meta(OWNER_KEY)
    Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
    Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
