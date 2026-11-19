extends RefCounted
## Display controls only; preferences and rendering adapters live outside GameHUD.
static func build(hud: CanvasLayer) -> void:
    var body: VBoxContainer=hud._panel("settings","游戏设置",Vector2(640,520))
    var aspect:=OptionButton.new()
    aspect.name="AspectRatio"
    aspect.add_item("16:9")
    aspect.add_item("16:10")
    _row(hud,body,"画面比例",aspect)
    var quality:=OptionButton.new()
    quality.name="Quality"
    for text: String in ["低","中","高"]:quality.add_item(text)
    _row(hud,body,"画面精度",quality)
    var volume:=_slider("GameVolume",0.0,100.0,1.0)
    _row(hud,body,"游戏音量",volume)
    var sensitivity:=_slider("Sensitivity",0.25,2.0,0.05)
    _row(hud,body,"视角灵敏度",sensitivity)
    aspect.item_selected.connect(func(index: int):hud.preference_changed.emit("aspect",float(index)))
    quality.item_selected.connect(func(index: int):hud.preference_changed.emit("quality",float(index)))
    volume.value_changed.connect(func(value: float):hud.preference_changed.emit("volume",value/100.0))
    sensitivity.value_changed.connect(func(value: float):hud.preference_changed.emit("sensitivity",value))
    hud.setting_controls={"aspect":aspect,"quality":quality,"volume":volume,"sensitivity":sensitivity}
    var help: Label=hud._label(body,"双击鼠标左键：唤出鼠标；双击画面空白处：继续转动视角。",17)
    help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    hud._confirm_button(body,"完成",hud.close_overlay)
static func _row(hud: CanvasLayer, parent: Node, title: String, control: Control) -> void:
    var row:=HBoxContainer.new()
    row.custom_minimum_size.y=52
    row.add_theme_constant_override("separation",24)
    parent.add_child(row)
    var label: Label=hud._label(row,title,22)
    label.custom_minimum_size.x=168
    label.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    control.custom_minimum_size=Vector2(240,40)
    control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    control.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    control.focus_mode=Control.FOCUS_NONE
    row.add_child(control)
    if control is HSlider:
        var value: Label=hud._label(row,"",20)
        value.custom_minimum_size.x=58
        value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
        var update:=func(v: float):value.text=("%d%%"%roundi(v)) if control.name==&"GameVolume" else ("%.2f"%v)
        control.value_changed.connect(update)
        control.set_meta(&"value_label",value)
static func _slider(id: String, low: float, high: float, step: float) -> HSlider:
    var slider:=HSlider.new()
    slider.name=id
    slider.min_value=low
    slider.max_value=high
    slider.step=step
    return slider
static func sync(hud: CanvasLayer, data: Dictionary) -> void:
    var controls: Dictionary=hud.setting_controls
    controls.aspect.select(data.aspect)
    controls.quality.select(data.quality)
    controls.volume.set_value_no_signal(data.volume*100.0)
    controls.sensitivity.set_value_no_signal(data.sensitivity)
    controls.volume.get_meta(&"value_label").text="%d%%"%roundi(data.volume*100.0)
    controls.sensitivity.get_meta(&"value_label").text="%.2f"%data.sensitivity
