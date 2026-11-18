extends PanelContainer
var queue: Array[Dictionary] = []
var age := 0.0

var title: Label
var description: Label
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var surface := StyleBoxFlat.new()
    surface.bg_color=Color(0.30,0.29,0.27,0.34)
    surface.set_corner_radius_all(36)
    surface.content_margin_left=13
    surface.content_margin_right=13
    surface.content_margin_top=8
    surface.content_margin_bottom=8
    add_theme_stylebox_override("panel",surface)
    resized.connect(_sync_radius)
    _sync_radius.call_deferred()
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",12)
    row.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(row)
    var column:=VBoxContainer.new()
    column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    column.alignment=BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation",2)
    column.mouse_filter=Control.MOUSE_FILTER_IGNORE
    row.add_child(column)
    title=Label.new()
    title.add_theme_font_size_override("font_size",20)
    title.add_theme_color_override("font_color",Color("fffdf8"))
    title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    title.mouse_filter=Control.MOUSE_FILTER_IGNORE
    column.add_child(title)
    description=Label.new()
    description.add_theme_font_size_override("font_size",18)
    description.add_theme_color_override("font_color",Color("e8e9eb"))
    description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    description.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    description.mouse_filter=Control.MOUSE_FILTER_IGNORE
    column.add_child(description)
    hide()
func _sync_radius() -> void:
    (get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(ceili(size.y*0.5))
func enqueue(data: Dictionary) -> void:
    if queue.size()>=4:queue.pop_front()
    queue.append(data)
    if not visible:_next()
func _next() -> void:
    if queue.is_empty():
        hide()
        return
    var data: Dictionary = queue.pop_front()
    title.text=data.get("title","")
    description.text=data.get("description","")
    description.visible=not description.text.is_empty()
    age=0.0
    modulate.a=0.0
    show()
func _process(delta: float) -> void:
    if not visible or get_tree().paused:return
    age+=delta
    var rise:=6.0*(1.0-smoothstep(0.0,0.20,age))
    offset_top=-248.0+rise
    offset_bottom=-176.0+rise
    modulate.a=minf(smoothstep(0.0,0.16,age),1.0-smoothstep(2.35,2.8,age))
    if age>=2.8:_next()
func clear() -> void:
    queue.clear()
    age=0.0
    offset_top=-232.0
    offset_bottom=-176.0
    hide()
