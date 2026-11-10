extends "res://scripts/maze/maze_scene.gd"

const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const WallOcclusion := preload("res://scripts/levels/wall_occlusion.gd")
const DreamFinish := preload("res://art/maze01/maze01_dream_finish.gd")
const DreamLighting := preload("res://art/environments/maze01_formal_lighting.tres")
const SunkenCorridor := preload("res://scripts/levels/sunken_corridor.gd")
const MazeSound := preload("res://art/maze01/maze01_sound.gd")
const StoneFootsteps := preload("res://art/maze01/stone_footsteps.gd")
const ChapelBookStand := preload("res://art/maze01/landmarks/chapel_book_stand.gd")
const FinishDoctor := preload("res://art/maze01/landmarks/finish_doctor.gd")
const MazeItems := preload("res://modules/maze_items/maze_item_controller.gd")
const EXIT_GATES := ["D1","D3","D4"]
@export var dream_art_enabled := true
@export var finish_doctor_enabled := true
@export_range(1.0, 60.0, 0.5) var rabbit_guide_seconds := 24.0
@export_range(2.0, 16.0, 0.5) var rabbit_guide_distance := 14.0
var wall_occlusion: Node
var completed := false
var inspection_picker: OptionButton
var closest_switch: Node3D
var sound: MazeSound
var footprints: StoneFootsteps
var _doctor: FinishDoctor
var _items: MazeItems

func _ready() -> void:
	super()
	if not loaded_ok:
		return
	wall_occlusion = WallOcclusion.new()
	wall_occlusion.name = "LocalWallOcclusion"
	%GeneratedMaze.add_child(wall_occlusion)
	wall_occlusion.configure(%GeneratedMaze,%Player,%FollowRig,Layout.config().occlusion)
	get_window().title = "Maze 01 · 下沉石廊与拱桥修正版"
	theme = load("res://ui/game_theme.tres")
	get_node("Heading").text = "Maze 01 · 高墙庭院与圆形教堂灰模"
	%Summary.text = "8 处嵌墙拱门 / 4 扇机关门 / 6 处高低空间 / 下沉石廊与拱形桥洞"
	if dream_art_enabled:
		DreamFinish.apply(%GeneratedMaze, wall_occlusion, maze_data.checkpoints, %Player)
		DreamLighting.apply(%Player.get_parent())
		%GeneratedMaze.hide_inspection_marks = true
		sound = MazeSound.new()
		sound.install(self, %Player, %GeneratedMaze.gates)
		footprints = StoneFootsteps.new()
		footprints.install(%Player.get_parent())
		sound.foot_planted.connect(footprints.step)
		var sound_button := Button.new()
		sound_button.text = "声音：开"
		sound_button.toggle_mode = true
		sound_button.toggled.connect(func(muted: bool):
			sound.set_muted(muted)
			sound_button.text = "声音：关" if muted else "声音：开")
		get_node("WalkControls").add_child(sound_button)
		var credits := LinkButton.new()
		credits.text = "配乐署名"
		credits.uri = MazeSound.MUSIC_SOURCE
		credits.add_theme_color_override("font_color", Color("53674e"))
		credits.add_theme_color_override("font_hover_color", Color("30482e"))
		credits.add_theme_font_size_override("font_size", 14)
		credits.tooltip_text = "Enchanted Valley · Kevin MacLeod (incompetech.com)\nCC BY 4.0 · 节选与循环剪辑"
		get_node("WalkControls").add_child(credits)
		get_window().title = "Maze 01 · 梦境迷宫"
		get_node("Heading").text = "Maze 01 · 梦境迷宫"
		%Summary.text = "奶油白石膏 · 浅米石材 · 湖蓝屋顶与机关 · 紫粉云海"
	var corridor: Node3D = %GeneratedMaze.architecture.get_node("SunkenCorridor")
	SunkenCorridor.install_stars(corridor, Layout.config().sunken_corridor, %Player)
	if is_instance_valid(sound):
		%Player.get_viewport().audio_listener_enable_3d = true
		sound.bind_niche_chimes(corridor)
	%RouteA.text = "A 参考线 · 含抬高通路"
	%RouteB.text = "B 参考线 · 长路探索"
	%PaletteButton.hide()
	%Status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reset := Button.new()
	reset.text = "重置关卡与机关"
	reset.pressed.connect(reset_level)
	get_node("WalkControls").add_child(reset)
	inspection_picker = OptionButton.new()
	for label: String in ["查看关卡位置…","入口教学门","D2 门前","上桥入口","桥侧开关 S3","桥下通道","南侧抬高通路","西北庭院入口","西北下沉花庭","西北起伏回廊","中心圆形教堂","教堂北门 G6","教堂东北门 G7","教堂南门 G8","南露台 H4","东庭短高台 H3","桥前开关 S4","教堂外观总览","西北庭院总览","教堂北侧外观","桥段外观","下沉石廊 H6","下沉石廊总览","拱形桥洞近景"]:
		inspection_picker.add_item(label)
	if dream_art_enabled:
		inspection_picker.add_item("东南侧兔脚测试点")
	inspection_picker.item_selected.connect(inspect_location)
	get_node("WalkControls").add_child(inspection_picker)
	var exit := Area3D.new()
	exit.name = "ExitTrigger"
	exit.collision_layer = 0
	exit.collision_mask = 2
	exit.position = Layout.cell_point([0,18],0.8)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9,2.0,1.9)
	shape.shape = box
	exit.add_child(shape)
	exit.body_entered.connect(_on_exit_body_entered)
	%Player.get_parent().add_child(exit)
	if dream_art_enabled:
		ChapelBookStand.install(%Player.get_parent())
		if finish_doctor_enabled:
			_doctor = FinishDoctor.new()
			_doctor.name = "FinishDoctor"
			_doctor.position = exit.position + Vector3(0.65, -0.8, -0.21)
			_doctor.rotation.y = -2.12
			%Player.get_parent().add_child(_doctor)
		_items = _make_items()
		_items.install(self, %Player, %GeneratedMaze.architecture, %GeneratedMaze.gates,
			[exit], required_exit_gates(), rabbit_guide_seconds, rabbit_guide_distance, sound.play_item_pickup)
	_refresh_hud()

func _make_items() -> MazeItems:
	return MazeItems.new()

func _process(_delta: float) -> void:
	closest_switch = null
	if not loaded_ok:
		return
	%GeneratedMaze.update_room_view(%Player.position,walk_mode,not walk_mode and %CameraRig.top_down)
	var best := 1.65
	if walk_mode:
		for button: Node3D in %GeneratedMaze.switches.values():
			var distance: float = (%Player.global_position+Vector3(0,0.9,0)).distance_to(button.global_position)
			if not button.used and distance<best and _can_see_switch(button):
				best = distance
				closest_switch = button
	_refresh_hud()

func _can_see_switch(button: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(%Player.global_position+Vector3(0,0.9,0),button.global_position,1)
	return %Player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_E or event.keycode == KEY_E):
		if walk_mode and is_instance_valid(closest_switch):
			var id: String = closest_switch.gate_id
			try_activate_gate(id)
			get_viewport().set_input_as_handled()

func try_activate_gate(id: String) -> bool:
	if not %GeneratedMaze.gates.has(id):
		return false
	%GeneratedMaze.switches[id].set_used(true)
	%GeneratedMaze.gates[id].open_gate()
	return true

func can_finish() -> bool:
	for id: String in required_exit_gates():
		if not %GeneratedMaze.gates[id].is_open:
			return false
	return true

func required_exit_gates() -> Array:
	return EXIT_GATES

func _on_exit_body_entered(body: Node3D) -> void:
	if body == %Player and can_finish():
		complete_level()

func complete_level() -> void:
	if completed:
		return
	completed = true
	%Player.visual.play_victory_dance()
	if is_instance_valid(_doctor):
		_doctor.encourage()
	if is_instance_valid(sound):
		sound.play_exit()

func _refresh_hud() -> void:
	if not loaded_ok:
		return
	%Legend.text = "WASD 移动 / Shift 跑步 / 空格跳跃 / E 开门 / 鼠标拖动视角 / 滚轮缩放" if walk_mode else "全图查看 · 两条线为原始参考走向，实际通行还需操作机关"
	var parts: Array[String] = []
	for id: String in ["D1","D2","D4","D3"]:
		parts.append(id+(" 已开" if %GeneratedMaze.gates[id].is_open else " 关闭"))
	var hint := "寻找同号开关；开启后保持。D2 可绕行；A/B 参考线不包含机关绕行。"
	if is_instance_valid(closest_switch):
		hint = "按 E 操作 "+str(closest_switch.gate_id).replace("D","S")+"，打开 "+str(closest_switch.gate_id)
	if completed:
		hint = "已到出口！可重置机关再次探索其他路线。"
	%Status.text = " / ".join(parts)+"  ·  "+hint

func reset_level() -> void:
	%GeneratedMaze.reset_mechanisms()
	completed = false
	if is_instance_valid(_items):
		_items.reset_items()
	if is_instance_valid(_doctor):
		_doctor.stand()
	reset_walk()
	set_walk_mode(true)
	inspection_picker.select(0)
	if is_instance_valid(sound):
		sound.stop_transients()

func reset_walk() -> void:
	super()
	if is_instance_valid(_items):
		_items.cancel_guide()
	if is_instance_valid(sound):
		sound.sync_actor()
	if is_instance_valid(footprints):
		footprints.clear()

func inspect_location(index: int) -> void:
	if index == 0:
		return
	if index in [21,23,24]:
		set_walk_mode(true)
		%Player.position = Vector3(3.6,-0.56,18.65) if index==21 else Vector3(37.2,0.04,15.6)
		if index==24:
			%Player.position = MazeItems.PICKUP_PREVIEW + Vector3.UP*0.04
			%Player.visual.rotation.y = -PI/2
		%Player.velocity = Vector3.ZERO
		%Player.visual.set_locomotion(0)
		if index == 21:
			%Player.visual.rotation.y = PI
		%FollowRig.reset_view()
		%FollowRig.yaw = PI if index==21 else -PI/2
		if index==24:
			%FollowRig.pitch = 0.35
		if is_instance_valid(sound):
			sound.sync_actor()
		get_viewport().gui_release_focus()
		return
	if index>=17:
		set_walk_mode(false)
		%CameraRig.center = Vector3(24,4.8,22.8) if index==17 else Vector3(4.8,0.8,9.6)
		%CameraRig.world_size = Vector3(13,13,13) if index==17 else Vector3(11.5,5.0,11.5)
		%CameraRig.extent = 12
		if index==19:
			%CameraRig.center = Vector3(25,2.8,20)
			%CameraRig.world_size = Vector3(10,7,9)
			%CameraRig.extent = 10
		elif index==20:
			%CameraRig.center = Vector3(39.6,1.7,17)
			%CameraRig.world_size = Vector3(11,7,15)
			%CameraRig.extent = 15
		elif index==22:
			%CameraRig.center = Vector3(3.6,0,21.6)
			%CameraRig.world_size = Vector3(7,4,17)
			%CameraRig.extent = 17
		%CameraRig.reset_view()
		if index==19:
			%CameraRig.yaw = PI
			%CameraRig.pitch = 0.32
			%CameraRig._update_camera()
		return
	set_walk_mode(true)
	var chapel_view := Vector3(24,0,24.07) if dream_art_enabled else Vector3(24,0,22.8)
	var points := [Vector3.ZERO,Layout.cell_point([16,1]),Layout.cell_point([14,13]),Layout.cell_point([8,18]),Vector3(37.2,2.6,18),Layout.cell_point([6,15]),Layout.cell_point([18,3]),Layout.cell_point([5,0]),Layout.cell_point([4,1],-0.6),Layout.cell_point([5,3],0.9),chapel_view,Layout.cell_point([7,9]),Layout.cell_point([7,11]),Layout.cell_point([11,10]),Layout.cell_point([12,10],1.2),Layout.cell_point([12,15],0.6),Layout.cell_point([9,18])]
	%Player.position = points[index]+Vector3(0,0.04,0)
	%Player.velocity = Vector3.ZERO
	%Player.visual.set_locomotion(0)
	%FollowRig.reset_view()
	if is_instance_valid(sound):
		sound.sync_actor()
	get_viewport().gui_release_focus()

func set_walk_mode(enabled: bool) -> void:
	if not enabled:
		%CameraRig.center = Vector3(22.8,2.5,22.8)
		%CameraRig.world_size = Vector3(47,13,47)
		%CameraRig.extent = 45.6
	super(enabled)

func _reset_camera() -> void:
	if not walk_mode:
		set_walk_mode(false)
	super()
