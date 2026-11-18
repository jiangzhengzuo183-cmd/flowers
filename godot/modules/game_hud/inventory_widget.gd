extends Control
signal selected(index: int)
signal use_requested
const Layout := preload("res://modules/game_hud/layout_metrics.gd")
const Art := preload("res://modules/game_hud/assets.gd")

var buttons: Array[Button] = []
var visuals: Array[Control] = []
var target_scales: Array[float] = [0,0,0]
var icons: Array[TextureRect] = []
var backgrounds: Array[TextureRect] = []
var counts: Array[Label] = []
var active_slot := 0
var snapshot: Array = []
var previous_ids: Array[StringName] = [&"", &"", &""]
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    for i in 3:
        var button := Button.new()
        button.position=Vector2(i*Layout.CELL_STEP,0)
        button.size=Layout.CELL_SIZE
        button.flat=true
        button.focus_mode=Control.FOCUS_NONE
        for style in ["normal","hover","pressed","focus"]: button.add_theme_stylebox_override(style,StyleBoxEmpty.new())
        button.pressed.connect(func():selected.emit(i))
        button.gui_input.connect(func(event: InputEvent):
            if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
                selected.emit(i)
                use_requested.emit()
                get_viewport().set_input_as_handled())
        add_child(button)
        buttons.append(button)
        var visual:=Control.new()
        visual.size=Layout.CELL_SIZE
        visual.pivot_offset=Vector2(Layout.CELL_SIZE.x*0.5,Layout.CELL_SIZE.y)
        visual.mouse_filter=Control.MOUSE_FILTER_IGNORE
        button.add_child(visual)
        visuals.append(visual)
        backgrounds.append(Art.picture(visual,Art.slice("slot_"+str(i)),Rect2(Vector2.ZERO,Layout.CELL_SIZE)))
        icons.append(Art.picture(visual,null,Rect2(20,15,72,86)))
        var count := Label.new()
        count.position=Vector2(84,98)
        count.size=Vector2(34,26)
        count.add_theme_font_size_override("font_size",20)
        count.add_theme_color_override("font_color",Color("574437"))
        count.add_theme_color_override("font_outline_color",Color.WHITE)
        count.add_theme_constant_override("outline_size",3)
        count.mouse_filter=Control.MOUSE_FILTER_IGNORE
        visual.add_child(count)
        counts.append(count)
    update_items([],0)
func update_items(items: Array, choice: int) -> void:
    snapshot=items
    active_slot=choice
    for i in buttons.size():
        var entry: Dictionary=items[i] if i<items.size() else {}
        var id: StringName=StringName(entry.get("id", ""))
        icons[i].texture=Art.icon(String(id)) if id!=&"" else null
        backgrounds[i].visible=true
        if id!=&"" and id!=previous_ids[i]: _arrival(i)
        previous_ids[i]=id
        counts[i].text=""
        _selection_scale(i,1.10 if choice==i else 1.0)
        buttons[i].tooltip_text=str(entry.get("label","空道具槽")) if id!=&"" else ""
func _selection_scale(index: int, factor: float) -> void:
    if target_scales[index]==factor:return
    target_scales[index]=factor
    var visual:=visuals[index]
    visual.z_index=1 if factor>1.0 else 0
    var old: Tween=visual.get_meta(&"selection_motion") if visual.has_meta(&"selection_motion") else null
    if is_instance_valid(old):old.kill()
    var tween:=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    visual.set_meta(&"selection_motion",tween)
    tween.tween_property(visual,"scale",Vector2.ONE*factor,0.16)
func _arrival(index: int) -> void:
    var image := icons[index]
    var previous: Tween = image.get_meta(&"sticker_motion") if image.has_meta(&"sticker_motion") else null
    if is_instance_valid(previous): previous.kill()
    image.pivot_offset=image.size*0.5
    image.scale=Vector2.ONE*0.95
    var tween:=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    image.set_meta(&"sticker_motion",tween)
    tween.tween_property(image,"scale",Vector2.ONE*1.045,0.14)
    tween.tween_property(image,"scale",Vector2.ONE,0.20)
func flash(id: StringName) -> void:
    var i := previous_ids.find(id)
    if i<0:return
    var image := icons[i]
    image.pivot_offset=image.size*0.5
    var tween := create_tween()
    tween.tween_property(image,"scale",Vector2.ONE*1.045,0.12)
    tween.tween_property(image,"scale",Vector2.ONE,0.25)
