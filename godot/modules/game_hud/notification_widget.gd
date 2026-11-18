extends PanelContainer
const Art := preload("res://modules/game_hud/assets.gd")
var queue: Array[Dictionary] = []
var age := 0.0

var item_icon: TextureRect
var title: Label
var description: Label
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var surface := StyleBoxFlat.new()
    surface.bg_color=Color(0.30,0.29,0.27,0.34)
    surface.set_corner_radius_all(16)
    surface.content_margin_left=13
    surface.content_margin_right=13
    surface.content_margin_top=8
    surface.content_margin_bottom=8
    add_theme_stylebox_override("panel",surface)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",12)
    row.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(row)
    item_icon=TextureRect.new()
    item_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    item_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    item_icon.custom_minimum_size=Vector2(30,30)
    item_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
    row.add_child(item_icon)
    title=Label.new()
    title.add_theme_font_size_override("font_size",20)
    title.add_theme_color_override("font_color",Color("fffdf8"))
    title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    title.size_flags_stretch_ratio=0.46
    title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    title.mouse_filter=Control.MOUSE_FILTER_IGNORE
    row.add_child(title)
    description=Label.new()
    description.add_theme_font_size_override("font_size",18)
    description.add_theme_color_override("font_color",Color("e8e9eb"))
    description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    description.size_flags_stretch_ratio=0.54
    description.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    description.mouse_filter=Control.MOUSE_FILTER_IGNORE
    row.add_child(description)
    hide()
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
    item_icon.texture=Art.icon(data.get("icon",""))
    item_icon.visible=item_icon.texture!=null
    age=0.0
    modulate.a=0.0
    show()
func _process(delta: float) -> void:
    if not visible or get_tree().paused:return
    age+=delta
    var rise:=6.0*(1.0-smoothstep(0.0,0.20,age))
    offset_top=-232.0+rise
    offset_bottom=-176.0+rise
    modulate.a=minf(smoothstep(0.0,0.16,age),1.0-smoothstep(2.35,2.8,age))
    if age>=2.8:_next()
func clear() -> void:
    queue.clear()
    age=0.0
    offset_top=-232.0
    offset_bottom=-176.0
    hide()
