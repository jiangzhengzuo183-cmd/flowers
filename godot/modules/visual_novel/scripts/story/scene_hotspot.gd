extends Button
## 保留多边形判定但不绘制点击区域；提示由场景中的独立标签显示。
signal hint_changed(active: bool)
var polygon := PackedVector2Array()
var hint_text := ""
var pointer_inside := false
var hint_suppressed := false

func configure(vertices: PackedVector2Array, label: String) -> void:
	var bounds := Rect2(vertices[0], Vector2.ZERO)
	for vertex: Vector2 in vertices:
		bounds = bounds.expand(vertex)
	position = bounds.position
	size = bounds.size
	for vertex: Vector2 in vertices:
		polygon.append(vertex - bounds.position)
	text = label
	hint_text = label
	tooltip_text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var clear := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, clear)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)

func _ready() -> void:
	mouse_entered.connect(_pointer_entered)
	mouse_exited.connect(_pointer_exited)
	pressed.connect(cancel_hint)
	visibility_changed.connect(_visibility_changed)

func _has_point(point: Vector2) -> bool:
	return not disabled and Geometry2D.is_point_in_polygon(point, polygon)

func _pointer_entered() -> void:
	pointer_inside = true
	hint_suppressed = false
	hint_changed.emit(not disabled)

func _pointer_exited() -> void:
	pointer_inside = false
	hint_suppressed = false
	hint_changed.emit(false)

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		pointer_inside = false
		cancel_hint()

func cancel_hint() -> void:
	hint_suppressed = true
	hint_changed.emit(false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		cancel_hint()
	elif event is InputEventScreenTouch and event.pressed and _has_point(event.position):
		pointer_inside = false
		cancel_hint()
		pressed.emit()
		accept_event()
