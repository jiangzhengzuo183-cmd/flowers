extends Node
## Three cached native cursors. The cursor hotspot never moves; gameplay input stays with MouseLook.
const Art:=preload("res://assets/UI/HUD/hand_cursor/regions.gd")
var frames: Array[ImageTexture]=[]
var frame := 0
var updates := 0
var age := 0.0
var _last_frame := -1
var _was_visible := false
static func install(window: Window) -> Node:
    var current: Node=window.get_node_or_null("HandDrawnCursor")
    if current!=null:return current
    var cursor_script: Script=load("res://modules/game_hud/hand_cursor.gd")
    current=cursor_script.new()
    window.add_child(current)
    return current
func _ready() -> void:
    name="HandDrawnCursor"
    process_mode=Node.PROCESS_MODE_ALWAYS
    for i in 3:
        var source: Texture2D=load("res://assets/UI/HUD/hand_cursor/derived/frame_%d.png"%i)
        frames.append(ImageTexture.create_from_image(source.get_image()))
    _apply(0)
func _apply(index: int) -> void:
    frame=index
    _last_frame=index
    updates+=1
    Input.set_custom_mouse_cursor(frames[index],Input.CURSOR_ARROW,Art.HOTSPOT)
    Input.set_custom_mouse_cursor(frames[index],Input.CURSOR_POINTING_HAND,Art.HOTSPOT)
func _process(delta: float) -> void:
    var shown: bool=Input.mouse_mode in [Input.MOUSE_MODE_VISIBLE,Input.MOUSE_MODE_CONFINED] and get_window().has_focus()
    if not shown:
        _was_visible=false
        return
    age+=delta
    var next:=int(floor(age*Art.FPS))%frames.size()
    if next!=_last_frame or not _was_visible:_apply(next)
    _was_visible=true
func _exit_tree() -> void:
    Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
    Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
