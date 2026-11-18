extends Node
## Uses existing finish flags and race outcomes. Owns preparation and result presentation only.
var runtime: Node
var countdown: Label
var result_panel: PanelContainer
var result_title: Label
var result_detail: Label
var count_age := 0.0
var preparing := false
var settled := false
var result_age := 0.0
var outcome := "完成"
func install(adapter: Node) -> void:
    runtime=adapter
    name="MazePlayFlow"
    var canvas: Control=runtime.hud.get_node("HUDRoot/RaceOverlay")
    countdown=Label.new()
    countdown.name="StartCountdown"
    countdown.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    countdown.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    countdown.add_theme_font_size_override("font_size",100)
    countdown.add_theme_color_override("font_color",Color("fff5d5"))
    countdown.add_theme_color_override("font_shadow_color",Color(0.2,0.16,0.1,0.5))
    countdown.add_theme_constant_override("shadow_offset_y",3)
    countdown.mouse_filter=Control.MOUSE_FILTER_IGNORE
    canvas.add_child(countdown)
    countdown.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    countdown.offset_left=-200
    countdown.offset_right=200
    countdown.offset_top=-95
    countdown.offset_bottom=55
    result_panel=PanelContainer.new()
    result_panel.name="CompletionPoster"
    result_panel.mouse_filter=Control.MOUSE_FILTER_STOP
    canvas.add_child(result_panel)
    result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    result_panel.offset_left=-310
    result_panel.offset_right=310
    result_panel.offset_top=-220
    result_panel.offset_bottom=150
    result_panel.add_theme_stylebox_override("panel",runtime.hud.paper(32))
    var column:=VBoxContainer.new()
    column.alignment=BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation",22)
    result_panel.add_child(column)
    result_title=runtime.hud._label(column,"完成",100)
    result_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    result_detail=runtime.hud._label(column,"",24)
    result_detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    var buttons:=HBoxContainer.new()
    buttons.alignment=BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation",24)
    column.add_child(buttons)
    runtime.hud._button(buttons,"重新开始",func():runtime.hud.open_overlay("restart"))
    runtime.hud._button(buttons,"返回选择",func():runtime.hud.open_overlay("exit"))
    runtime.actor.stamina.session_reset.connect(reset)
    reset()
func reset() -> void:
    count_age=0.0
    settled=false
    result_age=0.0
    result_panel.hide()
    countdown.hide()
    if is_instance_valid(runtime.mouse_look):runtime.mouse_look.capture_cursor.call_deferred()
    preparing=runtime.maze_number in [1,2]
    runtime.clock.ready_to_play=not preparing
    if preparing:
        runtime.actor.controls_enabled=false
        countdown.text="3"
        countdown.show()
func _physics_process(delta: float) -> void:
    if not is_instance_valid(runtime) or get_tree().paused:return
    if preparing:
        runtime.actor.controls_enabled=false
        runtime.actor.velocity.x=0.0
        runtime.actor.velocity.z=0.0
        count_age+=delta
        countdown.text=str(maxi(1,3-floori(count_age)))
        if count_age>=3.0:
            preparing=false
            runtime.clock.ready_to_play=true
            runtime.actor.controls_enabled=runtime.scene.walk_mode
            countdown.text="GO!"
        return
    if count_age<3.6 and runtime.maze_number in [1,2]:
        count_age+=delta
        if count_age>=3.55:countdown.hide()
    var race: Node=runtime.race
    var race_mode: bool=is_instance_valid(race) and race.current_mode=="Race"
    var finished: bool=(race.state=="FINISHED") if race_mode else runtime.clock.finished
    if not finished:return
    runtime.actor.controls_enabled=false
    runtime.actor.velocity.x=0.0
    runtime.actor.velocity.z=0.0
    if not settled:
        settled=true
        outcome={"charlie":"胜利","mouse":"失败","tie":"平局"}.get(race.result.get("outcome","charlie"),"完成") if race_mode else "完成"
        if not runtime.actor.visual.celebrating:runtime.actor.visual.play_victory_dance()
    result_age+=delta
    if result_age>=runtime.actor.visual.VICTORY_DURATION and not result_panel.visible:
        result_title.text=outcome
        var seconds: float=race.charlie_time if race_mode else runtime.clock.elapsed
        result_detail.text="完成用时  %02d:%02d"%[floori(seconds/60.0),floori(fmod(seconds,60.0))]
        result_panel.modulate.a=0.0
        result_panel.show()
        create_tween().tween_property(result_panel,"modulate:a",1.0,0.3)
        runtime.mouse_look.release_cursor()
