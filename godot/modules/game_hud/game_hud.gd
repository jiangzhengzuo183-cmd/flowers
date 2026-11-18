extends CanvasLayer
## Presentation only. Runtime adapts existing level/inventory/stamina/race interfaces.
signal exit_confirmed
signal restart_requested
signal inventory_selected(index: int)
signal item_use_requested
signal overlay_changed(open: bool)
signal preference_changed(key: String, value: float)
var setting_controls: Dictionary = {}
signal music_toggled(enabled: bool)
signal music_volume_changed(value: float)
const Layout := preload("res://modules/game_hud/layout_metrics.gd")
const Art := preload("res://modules/game_hud/assets.gd")
var overlay := ""
var chapter_label: Label
var task_label: Label
var settings_music: CheckBox
var settings_volume: HSlider
var panels: Dictionary = {}
var developer_list: VBoxContainer
var status_signature := ""
var status_labels: Dictionary = {}
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var font: Font = Art.hand_font()
    var theme := Theme.new()
    theme.default_font = font
    theme.default_font_size = 19
    theme.set_color("font_color","Label",Color("574437"))
    theme.set_color("font_color","Button",Color("574437"))
    theme.set_color("font_color","CheckBox",Color("574437"))
    theme.set_color("font_hover_color","Button",Color("574437"))
    theme.set_color("font_pressed_color","Button",Color("574437"))
    theme.set_color("font_color","OptionButton",Color("574437"))
    theme.set_color("font_disabled_color","Button",Color("897b67"))
    theme.set_color("font_hover_color","OptionButton",Color("574437"))
    theme.set_color("font_pressed_color","OptionButton",Color("574437"))
    theme.set_color("font_color","LinkButton",Color("735d48"))
    theme.set_color("font_hover_color","LinkButton",Color("574437"))
    for type: String in ["Button","OptionButton","MenuButton"]:
        for state: String in ["normal","hover","pressed","disabled","focus"]:
            var style := StyleBoxFlat.new()
            style.bg_color = Color("eee2ca") if state == "pressed" else (Color("fffdf6") if state == "hover" else Color("f5ebd9"))
            style.border_color = Color("d9cdb9")
            style.set_border_width_all(1)
            style.set_corner_radius_all(8)
            style.content_margin_left = 14
            style.content_margin_right = 14
            style.content_margin_top = 7
            style.content_margin_bottom = 7
            if state == "focus": style.bg_color.a = 0.0
            theme.set_stylebox(state,type,style)
    $HUDRoot.theme = theme
    chapter_label = _label($HUDRoot/TaskInformation,"第一章 · 迷宫一",20)
    chapter_label.position = Vector2(0,0)
    chapter_label.size = Vector2(560,24)
    chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    task_label = _label($HUDRoot/TaskInformation,"请尽情探索这个迷宫并尝试找到出口。",18)
    task_label.position = Vector2(0,32)
    task_label.size = Vector2(560,24)
    task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _image_button($HUDRoot/TopRightMenu,Art.texture("v3/derived/exit.png"),Rect2(0,0,Layout.MENU_ICON,Layout.MENU_ICON),"退出当前迷宫",func():open_overlay("exit"))
    _image_button($HUDRoot/TopRightMenu,Art.texture("v3/derived/restart.png"),Rect2(Layout.MENU_STEP,0,Layout.MENU_ICON,Layout.MENU_ICON),"重新开始",func():open_overlay("restart"))
    _image_button($HUDRoot/TopRightMenu,Art.texture("v3/derived/settings.png"),Rect2(Layout.MENU_STEP*2,0,Layout.MENU_ICON,Layout.MENU_ICON),"设置",func():open_overlay("settings"))
    $HUDRoot/BottomRightInventory.selected.connect(func(index: int):inventory_selected.emit(index))
    $HUDRoot/BottomRightInventory.use_requested.connect(func():item_use_requested.emit())
    _build_panels()
func paper(margin: float = 0.0) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("fff8e9f0")
    style.border_color = Color.WHITE
    style.set_border_width_all(1)
    style.set_corner_radius_all(16)
    style.content_margin_left = margin
    style.content_margin_right = margin
    style.content_margin_top = margin
    style.content_margin_bottom = margin
    return style
func _label(parent: Node, text: String, font_size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size",font_size)
    parent.add_child(label)
    return label
func _button(parent: Node, text: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(action)
    parent.add_child(button)
    return button
func _confirm_button(parent: Node, text: String, action: Callable) -> Button:
    var button:=_button(parent,text,action)
    var gold:=StyleBoxFlat.new()
    gold.bg_color=Color("f5ce63")
    gold.set_corner_radius_all(10)
    gold.content_margin_left=22
    gold.content_margin_right=22
    gold.content_margin_top=10
    gold.content_margin_bottom=10
    button.add_theme_stylebox_override("normal",gold)
    var hover:StyleBoxFlat=gold.duplicate()
    hover.bg_color=Color("ffdb79")
    button.add_theme_stylebox_override("hover",hover)
    button.add_theme_stylebox_override("pressed",gold)
    return button
func _image_button(parent: Node, texture: Texture2D, rect: Rect2, hint: String, action: Callable) -> void:
    var button := Button.new()
    button.name="ExitButton" if hint=="退出当前迷宫" else ("SettingsButton" if hint=="设置" else "RestartButton")
    button.position=rect.position-Vector2.ONE*Layout.HIT_PADDING
    button.size=rect.size+Vector2.ONE*Layout.HIT_PADDING*2
    button.flat=true
    button.tooltip_text=""
    button.focus_mode=Control.FOCUS_NONE
    for style: String in ["normal","hover","pressed","focus"]:
        button.add_theme_stylebox_override(style,StyleBoxEmpty.new())
    parent.add_child(button)
    var image:=Art.picture(button,texture,Rect2(Vector2.ONE*Layout.HIT_PADDING,rect.size))
    # Equal optical height, independent of each PNG's transparent border and aspect.
    image.material=null
    var pixels:=texture.get_image()
    var left:=pixels.get_width()
    var right:=0
    var top:=pixels.get_height()
    var bottom:=0
    for y in pixels.get_height():
        for x in pixels.get_width():
            if pixels.get_pixel(x,y).a<0.2:continue
            left=mini(left,x)
            right=maxi(right,x)
            top=mini(top,y)
            bottom=maxi(bottom,y)
    var visible_size:=Vector2(right-left+1,bottom-top+1)
    var factor:=rect.size.y/visible_size.y
    image.size=Vector2(texture.get_size())*factor
    image.position=Vector2(Layout.HIT_PADDING+(rect.size.x-visible_size.x*factor)*0.5-left*factor,Layout.HIT_PADDING-top*factor)
    image.set_meta(&"optical_bounds",Rect2(Vector2(left,top)*factor+image.position,visible_size*factor))
    image.name="Sticker"
    image.pivot_offset=image.size*0.5
    button.mouse_entered.connect(func():_hover_sticker(image,1.08))
    button.mouse_exited.connect(func():_hover_sticker(image,1.0))
    button.button_down.connect(func():_hover_sticker(image,0.98))
    button.button_up.connect(func():_hover_sticker(image,1.08 if button.is_hovered() else 1.0))
    button.pressed.connect(action)
func _hover_sticker(image: TextureRect, scale_factor: float) -> void:
    var previous: Tween=image.get_meta(&"hover_motion") if image.has_meta(&"hover_motion") else null
    if is_instance_valid(previous): previous.kill()
    var tween:=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    image.set_meta(&"hover_motion",tween)
    tween.tween_property(image,"scale",Vector2.ONE*scale_factor,0.14)
func _panel(id: String, title: String, dimensions: Vector2) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.name = id.capitalize()+"Panel"
    $HUDRoot/ModalLayer.add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.offset_left = -dimensions.x/2
    panel.offset_right = dimensions.x/2
    panel.offset_top = -dimensions.y/2
    panel.offset_bottom = dimensions.y/2
    panel.add_theme_stylebox_override("panel",paper(26))
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation",16)
    panel.add_child(body)
    var heading := _label(body,title,32 if id in ["exit","restart"] else 26)
    if id in ["exit","restart"]:
        heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        body.alignment=BoxContainer.ALIGNMENT_CENTER
        body.add_theme_constant_override("separation",20)
    panel.hide()
    panels[id] = panel
    if id in ["exit","restart"]:
        var surface:=paper(32)
        surface.content_margin_top=44
        surface.content_margin_bottom=36
        surface.bg_color=Color("fff5dffb")
        surface.shadow_color=Color(0.21,0.16,0.10,0.07)
        surface.shadow_size=4
        surface.shadow_offset=Vector2(0,2)
        panel.add_theme_stylebox_override("panel",surface)
        panel.pivot_offset=dimensions*0.5
        panel.rotation_degrees=-0.55 if id=="exit" else 0.55
        panel.add_child(preload("res://modules/game_hud/note_decor.gd").new())
    return body
func _build_panels() -> void:
    var debug := _panel("debug","开发调试 · ESC 返回",Vector2(900,660))
    _label(debug,"打开面板时暂停；关上后按所选视角继续。",17)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(820,430)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    debug.add_child(scroll)
    developer_list = VBoxContainer.new()
    developer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    developer_list.add_theme_constant_override("separation",10)
    scroll.add_child(developer_list)
    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation",16)
    debug.add_child(actions)
    settings_music=CheckBox.new()
    settings_music.text="背景音乐"
    settings_music.focus_mode=Control.FOCUS_NONE
    settings_music.toggled.connect(func(value: bool):music_toggled.emit(value))
    actions.add_child(settings_music)
    settings_volume=HSlider.new()
    settings_volume.min_value=0
    settings_volume.max_value=100
    settings_volume.step=1
    settings_volume.custom_minimum_size=Vector2(210,32)
    settings_volume.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    settings_volume.value_changed.connect(func(value: float):music_volume_changed.emit(value/100.0))
    actions.add_child(settings_volume)
    _button(actions,"继续",close_overlay)
    var restart := _panel("restart","重新开始这次探索？",Vector2(580,340))
    var restart_detail:=_label(restart,"当前迷宫的进度将重新开始。",24)
    restart_detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    var restart_buttons := HBoxContainer.new()
    restart_buttons.add_theme_constant_override("separation",24)
    restart_buttons.alignment=BoxContainer.ALIGNMENT_CENTER
    restart.add_child(restart_buttons)
    _button(restart_buttons,"继续探索",close_overlay)
    _confirm_button(restart_buttons,"重新开始",func():restart_requested.emit())
    var exit := _panel("exit","返回迷宫选择？",Vector2(580,340))
    var exit_detail:=_label(exit,"本次探索的进度不会保留。",24)
    exit_detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation",24)
    buttons.alignment=BoxContainer.ALIGNMENT_CENTER
    exit.add_child(buttons)
    _button(buttons,"取消",close_overlay)
    _confirm_button(buttons,"确认退出",func():exit_confirmed.emit())
    for row: HBoxContainer in [restart_buttons,buttons]:
        for button: Button in row.get_children():
            button.custom_minimum_size=Vector2(176,56)
            button.add_theme_font_size_override("font_size",24)
    preload("res://modules/game_hud/settings_panel.gd").build(self)
    $HUDRoot/ModalLayer.hide()
func open_overlay(id: String) -> void:
    overlay = id
    $HUDRoot/ModalLayer.show()
    for key: String in panels: panels[key].visible = key == id
    overlay_changed.emit(true)
func close_overlay() -> void:
    overlay = ""
    $HUDRoot/ModalLayer.hide()
    overlay_changed.emit(false)
    get_viewport().gui_release_focus()
func set_music(enabled: bool, volume: float) -> void:
    settings_music.set_pressed_no_signal(enabled)
    settings_volume.set_value_no_signal(volume*100)
func update_task(chapter: String, task: String) -> void:
    chapter_label.text = chapter
    task_label.text = task
func update_timer(seconds: float) -> void:
    $HUDRoot/TopCenterTimer.set_time(seconds)
func update_stamina(ratio: float, sprinting: bool) -> void:
    $HUDRoot/BottomLeftStamina.set_ratio(ratio)
    $HUDRoot/BottomLeftStamina.set_active(sprinting)
func update_inventory(items: Array, selected: int) -> void:
    $HUDRoot/BottomRightInventory.update_items(items,selected)
func update_interaction(text: String) -> void:
    $HUDRoot/Interaction.set_prompt(text)
func position_interaction(anchor: Vector2, in_front: bool) -> void:
    var hint: Control=$HUDRoot/Interaction
    hint.visible=in_front and not hint.text.is_empty() and overlay.is_empty()
    if not hint.visible:return
    var at:=anchor+Vector2(24,-hint.size.y*0.5)
    var canvas: Vector2=$HUDRoot.size
    if at.x+hint.size.x>canvas.x-40:at.x=anchor.x-hint.size.x-24
    hint.position=Vector2(clampf(at.x,40,canvas.x-40-hint.size.x),clampf(at.y,48,canvas.y-80-hint.size.y))
func update_status_effects(effects: Array[Dictionary]) -> void:
    var keys := PackedStringArray()
    for effect: Dictionary in effects: keys.append(effect.id)
    var signature := "|".join(keys)
    if signature != status_signature:
        status_signature = signature
        for child in $HUDRoot/StatusEffects.get_children(): child.free()
        status_labels.clear()
        for effect: Dictionary in effects:
            var box := VBoxContainer.new()
            box.mouse_filter = Control.MOUSE_FILTER_IGNORE
            box.custom_minimum_size=Vector2(112,72)
            $HUDRoot/StatusEffects.add_child(box)
            var icon: Texture2D = Art.icon(effect.get("icon",""))
            if icon != null:
                var image := TextureRect.new()
                image.texture = icon
                image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                image.custom_minimum_size = Vector2(40,40)
                image.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
                image.mouse_filter = Control.MOUSE_FILTER_IGNORE
                box.add_child(image)
            var label := _label(box,"",16)
            label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
            label.custom_minimum_size=Vector2(112,28)
            label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
            label.add_theme_stylebox_override("normal",paper(4))
            status_labels[effect.id] = label
    for effect: Dictionary in effects:
        var seconds: float = effect.get("remaining",0.0)
        status_labels[effect.id].text = ("− " if effect.get("negative",false) else "+ ") + effect.label + (" %ds" % ceili(seconds) if seconds>0.0 else "")
func show_notification(data: Dictionary) -> void:
    $HUDRoot/CenterBottomNotification.enqueue(data)
func clear_notifications() -> void:
    $HUDRoot/CenterBottomNotification.clear()
