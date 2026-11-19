extends CanvasLayer
## Menu-owned display of the existing three frames; native cursor resumes on scene exit.
const Art:=preload("res://assets/UI/HUD/hand_cursor/regions.gd")
var sprite: Sprite2D
var cursor_frames: Array[ImageTexture]=[]
var frame:=0
var age:=0.0
var pointer:=Vector2.ZERO
func _ready() -> void:
	layer=2000
	process_mode=Node.PROCESS_MODE_ALWAYS
	var shared:=preload("res://modules/game_hud/hand_cursor.gd").install(get_window())
	cursor_frames.assign(shared.frames)
	sprite=Sprite2D.new()
	sprite.centered=false
	sprite.texture=cursor_frames[0]
	add_child(sprite)
	pointer=get_viewport().get_mouse_position()
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
	_update_position()
	get_window().mouse_entered.connect(func():sprite.show())
	get_window().mouse_exited.connect(func():sprite.hide())
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer=event.position
		_update_position()
func _update_position() -> void:
	sprite.position=pointer-Vector2(Art.HOTSPOT)
func _process(delta: float) -> void:
	age+=delta
	var next:=int(floor(age*Art.FPS))%cursor_frames.size()
	if next!=frame:
		frame=next
		sprite.texture=cursor_frames[frame]
	_update_position()
func _exit_tree() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
