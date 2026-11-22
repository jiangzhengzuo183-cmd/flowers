extends Control
## Native Godot overlay; no browser or web bridge.
signal finished(status: String)
const Frame := preload("res://modules/visual_novel/scripts/story/report_book_frame.gd")
var request: Dictionary = {}
var frame: Control
var previous_paused := false
var active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	previous_paused = get_tree().paused
	active = true
	get_tree().paused = true
	frame = Frame.new()
	frame.request = request
	frame.finished.connect(_returned)
	add_child(frame)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if not is_instance_valid(frame): return
	var ratio := minf(size.x/1600,size.y/900)
	frame.scale = Vector2.ONE*ratio
	frame.position = (size-Vector2(1600,900)*ratio)/2

func _returned(status: String) -> void:
	if not active: return
	_restore()
	finished.emit(status)

func _restore() -> void:
	if not active: return
	active = false
	get_tree().paused = previous_paused

func _exit_tree() -> void:
	_restore()
