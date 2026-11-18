extends Node
## Minimal adapter: existing systems own all gameplay. This node only binds their public data/actions.
const HUD := preload("res://modules/game_hud/GameHUD.tscn")
const Preferences := preload("res://modules/game_hud/game_settings.gd")
const StaminaPresentation := preload("res://modules/game_hud/stamina_presentation.gd")
var stamina_presentation := StaminaPresentation.new()
const Clock := preload("res://modules/game_hud/session_clock.gd")

static var music_enabled := true
static var music_volume := 1.0
var scene: Control
var actor: CharacterBody3D
var hud: CanvasLayer
var clock: Node
var inventory: Node
var race: Node
var maze_number := 1
var proxies: Array[Dictionary] = []
var diagnostic: Label
var _refresh := 0.0
var _pause_owned := false
var _paused_before := false
var _changing := false
var play_flow: Node
var mouse_look: Node
var _race_readout: Control
var interaction_target: Node3D
var _interaction_offset := Vector3.ZERO
func install(level: Control) -> void:
    name = "HUDRuntime"
    process_mode = Node.PROCESS_MODE_ALWAYS
    scene = level
    actor = scene.get_node("%Player")
    maze_number = 3 if scene.scene_file_path.ends_with("Maze03.tscn") else (2 if scene.scene_file_path.ends_with("Maze02.tscn") else 1)
    race = scene.get("race")
    scene.set_meta(&"unified_hud",true)
    clock = Clock.new()
    clock.name = "PlaySessionClock"
    clock.process_mode = Node.PROCESS_MODE_PAUSABLE
    scene.add_child(clock)
    clock.install(scene)
    hud = HUD.instantiate()
    scene.add_child(hud)
    Preferences.apply(scene)
    hud.preference_changed.connect(_preference_changed)
    preload("res://modules/game_hud/settings_panel.gd").sync(hud,Preferences.snapshot())
    var rig: Node3D=scene.get_node("%FollowRig")
    rig.default_distance=7.0
    rig.default_pitch=0.45
    rig.reset_view()
    hud.exit_confirmed.connect(_exit_level)
    hud.restart_requested.connect(_restart_level)
    hud.inventory_selected.connect(_select_slot)
    hud.item_use_requested.connect(_use_item)
    hud.overlay_changed.connect(_overlay_changed)
    hud.music_toggled.connect(_music_toggle)
    hud.music_volume_changed.connect(_music_volume)
    hud.set_music(music_enabled,music_volume)
    _music_bus()
    var items = scene.get("_items")
    if is_instance_valid(items): inventory = items.inventory
    if is_instance_valid(inventory):
        inventory.changed.connect(_inventory_changed)
        inventory.notice_requested.connect(_notice)
        inventory.item_flashed.connect(_key_feedback)
        _inventory_changed()
    actor.stamina.changed.connect(_stamina_changed)
    actor.stamina.session_reset.connect(func():
        hud.clear_notifications()
        stamina_presentation.reset()
        hud.get_node("HUDRoot/BottomLeftStamina").reset_state())
    actor.stamina.restored.connect(func(amount: float, source: StringName):
        if source == &"barrier": hud.show_notification({"title":"蓝色屏障 · 体力恢复", "description":"体力 +%.0f · 加速期间不消耗体力" % amount}))
    _stamina_changed()
    if is_instance_valid(race):
        race.sanctuary_activated.connect(func():hud.show_notification({"title":"圣堂已激活","description":"全局透视 · 阿尔吉侬时间减缓"}))
        race.mouse_arrived.connect(func(_seconds: float):hud.show_notification({"title":"阿尔吉侬已抵达","description":"继续完成你的路线，计时仍在继续。"}))
        race.sanctuary.prompt.modulate.a = 0.0
    mouse_look=preload("res://modules/game_hud/mouse_look.gd").new()
    add_child(mouse_look)
    mouse_look.install(self)
    play_flow=preload("res://modules/game_hud/play_flow.gd").new()
    scene.add_child(play_flow)
    play_flow.install(self)
    _build_developer_controls()
    _hide_chrome()
    var requested: String = get_tree().root.get_meta(&"hud_restart_mode","Explore")
    if get_tree().root.has_meta(&"hud_restart_mode"): get_tree().root.remove_meta(&"hud_restart_mode")
    if is_instance_valid(race) and requested == "Race": race.request_mode("Race")
    _sync()
func _hide_chrome() -> void:
    var viewport := scene.get_node("%ViewportContainer")
    for child in scene.get_children():
        if child is Control and child != viewport: child.hide()
    var readout := viewport.get_node_or_null("StaminaDebugReadout")
    if readout != null: readout.hide()
    # Selector hosting F6 also fills the window; the normal main entry controls its own chrome.
    var host := scene.get_parent()
    if host != null and host.name == &"LevelHost":
        var selector := host.get_parent()
        var back := selector.get_node_or_null("Back")
        if back != null: back.hide()
    scene.add_theme_constant_override("separation",0)
func _build_developer_controls() -> void:
    var target: VBoxContainer = hud.developer_list
    for id: String in ["Toolbar","WalkControls"]:
        var original := scene.get_node(id)
        var caption := Label.new()
        caption.text = "视角与路线" if id == "Toolbar" else "场景调试"
        target.add_child(caption)
        var flow := HFlowContainer.new()
        flow.add_theme_constant_override("h_separation",10)
        flow.add_theme_constant_override("v_separation",10)
        flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        target.add_child(flow)
        for source in original.get_children():
            if not source is BaseButton or not source.visible: continue
            var proxy: BaseButton
            if source is OptionButton:
                var option := OptionButton.new()
                for i in source.item_count: option.add_item(source.get_item_text(i),source.get_item_id(i))
                option.select(source.selected)
                option.item_selected.connect(func(index: int):
                    source.select(index)
                    source.item_selected.emit(index)
                    if source == scene.get("inspection_picker"): hud.close_overlay())
                proxy = option
            elif source is MenuButton:
                var menu := MenuButton.new()
                var popup: PopupMenu = source.get_popup()
                for i in popup.item_count:
                    if popup.is_item_separator(i): menu.get_popup().add_separator()
                    else: menu.get_popup().add_item(popup.get_item_text(i),popup.get_item_id(i))
                menu.get_popup().id_pressed.connect(func(id_pressed: int):
                    popup.id_pressed.emit(id_pressed)
                    hud.close_overlay())
                proxy = menu
            elif source is LinkButton:
                var link := LinkButton.new()
                link.uri = source.uri
                link.pressed.connect(func():source.pressed.emit())
                proxy = link
            else:
                proxy = Button.new()
                proxy.toggle_mode = source.toggle_mode
                if source.toggle_mode:
                    proxy.toggled.connect(func(on: bool): source.button_pressed = on)
                proxy.pressed.connect(func(): source.pressed.emit())
            proxy.text = source.text
            proxy.tooltip_text = source.tooltip_text
            proxy.focus_mode = Control.FOCUS_NONE
            proxy.add_theme_font_size_override("font_size",17)
            flow.add_child(proxy)
            proxies.append({"source":source,"proxy":proxy})
    var fullscreen := Button.new()
    fullscreen.text = "切换全屏 · F11"
    fullscreen.pressed.connect(_toggle_fullscreen)
    target.add_child(fullscreen)
    diagnostic = Label.new()
    diagnostic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    diagnostic.add_theme_font_size_override("font_size",16)
    target.add_child(diagnostic)
func _sync_proxies() -> void:
    for entry: Dictionary in proxies:
        var source: BaseButton = entry.source
        var proxy: BaseButton = entry.proxy
        proxy.disabled = source.disabled
        proxy.visible = source.visible
        proxy.text = source.text
        if proxy is OptionButton:
            if proxy.item_count == source.item_count:
                for i in source.item_count: proxy.set_item_text(i,source.get_item_text(i))
                proxy.select(source.selected)
        elif proxy.toggle_mode: proxy.set_pressed_no_signal(source.button_pressed)
    var s = actor.stamina
    diagnostic.text = "体力 %.1f / %.1f · 冲刺 %s · 恢复 %s\n恢复区域 %s · 屏障恢复 %d 次\n%s\n%s" % [s.current,s.settings.maximum,s.is_sprinting,s.is_recovering,str(s.zones.values()),s.restore_counts.get(&"barrier",0),"WASD 移动 · Shift 开关冲刺 · 空格跳跃 · 鼠标移动观察 · 双击左键切换鼠标 · E 使用/交互",scene.get_node("%Status").text]
    if is_instance_valid(race) and race.pending_mode != race.current_mode:
        diagnostic.text += "\n已选择%s，点击右上角重开或“回到入口”后生效。" % ("比赛模式" if race.pending_mode == "Race" else "探索模式")
func _process(delta: float) -> void:
    if not is_instance_valid(scene) or _changing: return
    hud.update_timer(race.elapsed if is_instance_valid(race) and race.current_mode == "Race" else clock.elapsed)
    if is_instance_valid(race) and is_instance_valid(race.hud) and race.hud != _race_readout:
        _race_readout = race.hud
        _race_readout.reparent(hud.get_node("HUDRoot/RaceOverlay"),false)
        _race_readout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        _race_readout.timer.hide()
        _race_readout.external_result=true
        _race_readout.result_panel.hide()
        _race_readout.message.offset_top = 202
        _race_readout.message.offset_bottom = 238
    _refresh -= delta
    if _refresh <= 0.0:
        _refresh = 0.08
        _sync()
    _position_interaction()
func _position_interaction() -> void:
    if not is_instance_valid(interaction_target):return
    var camera: Camera3D=actor.get_viewport().get_camera_3d()
    if camera==null:return
    var world: Vector3=interaction_target.global_position+_interaction_offset
    var point:=camera.unproject_position(world)
    var frame: Control=scene.get_node("%ViewportContainer")
    var viewport_size: Vector2=actor.get_viewport().get_visible_rect().size
    point=frame.global_position+point*frame.size/viewport_size
    hud.position_interaction(point,not camera.is_position_behind(world) and Rect2(Vector2.ZERO,frame.size).has_point(point-frame.global_position))
func _sync() -> void:
    var mode := "Race" if is_instance_valid(race) and race.current_mode == "Race" else "Explore"
    var copy: Resource = scene.hud_configuration
    hud.update_task(copy.chapter + " · " + copy.maze_names[maze_number-1],copy.race_task if mode == "Race" else copy.explore_tasks[maze_number-1])
    _stamina_changed()
    hud.update_status_effects(_effects())
    var hint := ""
    interaction_target=null
    _interaction_offset=Vector3.ZERO
    if not get_tree().paused:
        if is_instance_valid(race):
            if race.sanctuary.can_interact():
                hint = "E  激活圣堂"
                interaction_target=race.sanctuary.cube
        elif scene.has_method("_nearest_key_gate"):
            var gate: String = scene._nearest_key_gate()
            if not gate.is_empty():
                hint = scene._gate_hint(gate)
                interaction_target=scene.get_node("%GeneratedMaze").gates[gate]
                _interaction_offset=Vector3.UP*1.35
    hud.update_interaction(hint)
    if hud.overlay == "debug": _sync_proxies()
func _effects() -> Array[Dictionary]:
    var effects: Array[Dictionary] = []
    var perks = scene.get("_perks")
    if is_instance_valid(perks):
        if perks.boost_remaining > 0.0: effects.append({"id":"cake","label":"加速","icon":"cake","remaining":perks.boost_remaining})
        if perks.flour_remaining > 0.0: effects.append({"id":"flour","label":"面粉干扰","negative":true,"remaining":perks.flour_remaining})
    var capsules = scene.get("_item_effects")
    if is_instance_valid(capsules):
        if capsules.slow_remaining > 0.0: effects.append({"id":"slow","label":"减速","icon":"capsule","negative":true,"remaining":capsules.slow_remaining})
        if capsules.vision.remaining > 0.0: effects.append({"id":"vision","label":"透视","icon":"capsule","remaining":capsules.vision.remaining})
        if actor.tv_reversed: effects.append({"id":"tv","label":"电视干扰","negative":true})
    if maze_number == 3:
        if actor.boost_remaining > 0.0: effects.append({"id":"barrier","label":"屏障加速","remaining":actor.boost_remaining})
        if race.sanctuary_active: effects.append({"id":"sanctuary","label":"圣堂","remaining":maxf(0.0,race.sanctuary.deadline-race.sanctuary.age)})
    if is_instance_valid(inventory):
        var items = scene.get("_items")
        var guide = items.get("_guide")
        if is_instance_valid(guide) and not guide.fading:
            effects.append({"id":"guide","label":"引路","icon":"LuckyRabbitFoot","remaining":items.get("_remaining")})
    return effects
func _inventory_changed() -> void:
    hud.update_inventory(inventory.snapshot(),inventory.selected_slot())
func _key_feedback(id: StringName) -> void:
    hud.get_node("HUDRoot/BottomRightInventory").flash(id)
    hud.show_notification({"title":"机关已激活","description":"神秘符号正在点亮，机关门即将下沉。","icon":String(id)})
func _stamina_changed() -> void:
    hud.update_stamina_state(stamina_presentation.read(actor,scene.get("_perks")))
func _preference_changed(key: String, value: float) -> void:
    Preferences.change(key,value)
    Preferences.apply(scene)
    preload("res://modules/game_hud/settings_panel.gd").sync(hud,Preferences.snapshot())
func _select_slot(index: int) -> void:
    if is_instance_valid(inventory): inventory.select_slot(index)
func _interact_or_use() -> void:
    if not actor.controls_enabled or not scene.walk_mode: return
    if is_instance_valid(race) and race.sanctuary.can_interact():
        race.sanctuary.try_activate()
        return
    if scene.has_method("_nearest_key_gate"):
        var gate: String=scene._nearest_key_gate()
        if not gate.is_empty():
            scene.try_activate_gate(gate)
            return
    _use_item()
func _use_item() -> void:
    if get_tree().paused or not actor.controls_enabled or not is_instance_valid(inventory): return
    inventory.request_selected_use()
func _notice(text: String) -> void:
    var data := {"title":text,"description":"","icon":""}
    if "幸运兔脚" in text or "蓝色光团" in text:
        data.icon = "LuckyRabbitFoot"
        data.description = "光团提示前方路线"
        if text.begins_with("获得"): data.title = "获得 幸运兔脚 ×1"
    elif "钱币" in text:
        data.icon = "LuckyCoin"
        data.description = "对应门前按 E 解锁"
    elif "马蹄铁" in text:
        data.icon = "LuckyHorseshoe"
        data.description = "对应门前按 E 解锁"
    elif "蛋糕" in text:
        data.icon = "cake"
        data.title = "巧克力蛋糕"
        data.description = "已存入道具栏 · 选中后按 E 使用" if text.begins_with("获得") else "体力恢复 · 短暂加速"
    elif "胶囊" in text or "药丸" in text:
        data.icon = "capsule"
        data.title = "粉色药丸"
        data.description = "已存入道具栏 · 选中后按 E 使用" if text.begins_with("获得") else "透视或短暂减速"
    elif "干扰" in text: data.description = "短暂干扰"
    hud.show_notification(data)
func _overlay_changed(open: bool) -> void:
    if open:
        if not _pause_owned:
            _paused_before = get_tree().paused
            _pause_owned = true
        get_tree().paused = true
        _sync_proxies()
    elif _pause_owned:
        get_tree().paused = _paused_before
        _pause_owned = false
func _music_bus() -> int:
    var bus := AudioServer.get_bus_index(&"GameHUDMusic")
    if bus < 0:
        bus = AudioServer.bus_count
        AudioServer.add_bus()
        AudioServer.set_bus_name(bus,&"GameHUDMusic")
    AudioServer.set_bus_mute(bus,not music_enabled)
    AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(0.0001,music_volume)))
    var sound = scene.get("sound")
    if is_instance_valid(sound) and is_instance_valid(sound._music): sound._music.bus = &"GameHUDMusic"
    return bus
func _music_toggle(enabled: bool) -> void:
    music_enabled = enabled
    AudioServer.set_bus_mute(_music_bus(),not enabled)
func _music_volume(value: float) -> void:
    music_volume = clampf(value,0.0,1.0)
    AudioServer.set_bus_volume_db(_music_bus(),linear_to_db(maxf(0.0001,music_volume)))
func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo or _changing: return
    var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
    if code == KEY_ESCAPE:
        if hud.overlay.is_empty(): hud.open_overlay("debug")
        else: hud.close_overlay()
    elif code == KEY_F11: _toggle_fullscreen()
    elif code == KEY_F10: hud.close_overlay()
    elif get_tree().paused: return
    elif code == KEY_E: _interact_or_use()
    elif code == KEY_Q: _use_item()
    elif code in [KEY_1,KEY_2,KEY_3]: _select_slot(code-KEY_1)
    else: return
    get_viewport().set_input_as_handled()
func _toggle_fullscreen() -> void:
    if OS.has_feature("web"):
        JavaScriptBridge.eval("document.fullscreenElement ? document.exitFullscreen() : (document.getElementById('playtest') || document.documentElement).requestFullscreen().catch(console.warn)")
    else:
        get_window().mode = Window.MODE_WINDOWED if get_window().mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN
func _restart_level() -> void:
    if _changing: return
    _changing = true
    _perform_restart.call_deferred()
func _perform_restart() -> void:
    var mode: String = race.pending_mode if is_instance_valid(race) else "Explore"
    hud.close_overlay()
    get_tree().root.set_meta(&"hud_restart_mode",mode)
    var parent := scene.get_parent()
    while parent != null:
        if parent.has_method("restart_active_maze"):
            parent.restart_active_maze()
            return
        if parent.has_method("open_maze") and parent.get("active_level") == scene:
            parent.open_maze(maze_number-1)
            return
        parent = parent.get_parent()
    if get_tree().current_scene == scene: get_tree().reload_current_scene()
    else:
        var host := scene.get_parent()
        var next: Control = (load(scene.scene_file_path) as PackedScene).instantiate()
        host.remove_child(scene)
        scene.queue_free()
        host.add_child(next)
        next.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _exit_level() -> void:
    if _changing: return
    _changing = true
    _perform_exit.call_deferred()
func _perform_exit() -> void:
    hud.close_overlay()
    var parent := scene.get_parent()
    while parent != null:
        if parent.has_method("show_scene"):
            parent.show_scene("maze_select")
            return
        if parent.has_method("show_selection"):
            parent.show_selection()
            return
        parent = parent.get_parent()
    get_tree().change_scene_to_file("res://scenes/levels/MazeSelect.tscn")
func _exit_tree() -> void:
    if _pause_owned: get_tree().paused = _paused_before
