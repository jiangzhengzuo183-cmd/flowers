extends "res://scripts/maze/maze_scene.gd"

const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const WallOcclusion := preload("res://scripts/levels/wall_occlusion.gd")
var wall_occlusion: Node
var completed := false
var inspection_picker: OptionButton
var closest_switch: Node3D

func _ready() -> void:
	super()
	wall_occlusion = WallOcclusion.new()
	wall_occlusion.name = "LocalWallOcclusion"
	%GeneratedMaze.add_child(wall_occlusion)
	wall_occlusion.configure(%GeneratedMaze,%Player,%FollowRig,Layout.config().occlusion)
	get_window().title = "Maze 01 · 下沉石廊与拱桥修正版"
	theme = load("res://ui/game_theme.tres")
	get_node("Heading").text = "Maze 01 · 高墙庭院与圆形教堂灰模"
	%Summary.text = "8 处嵌墙拱门 / 4 扇机关门 / 6 处高低空间 / 下沉石廊与拱形桥洞"
	%RouteA.text = "A 参考线 · 含抬高通路"
	%RouteB.text = "B 参考线 · 长路探索"
	%PaletteButton.hide()
	%Status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reset := Button.new()
	reset.text = "重置关卡与机关"
	reset.pressed.connect(reset_level)
	get_node("WalkControls").add_child(reset)
	inspection_picker = OptionButton.new()
	for label: String in ["灰模检查位置…","入口教学门","D2 门前","上桥入口","桥侧开关 S3","桥下通道","南侧抬高通路","西北庭院入口","西北下沉花庭","西北起伏回廊","中心圆形教堂","教堂北门 G6","教堂东北门 G7","教堂南门 G8","南露台 H4","东庭短高台 H3","桥前开关 S4","教堂外观总览","西北庭院总览","教堂北侧外观","桥段外观","下沉石廊 H6","下沉石廊总览","拱形桥洞近景"]:
		inspection_picker.add_item(label)
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
	exit.body_entered.connect(func(body: Node3D):
		if body == %Player and %GeneratedMaze.gates.D1.is_open and %GeneratedMaze.gates.D3.is_open and %GeneratedMaze.gates.D4.is_open:
			completed = true)
	%Player.get_parent().add_child(exit)
	_refresh_hud()

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
			closest_switch.set_used(true)
			%GeneratedMaze.gates[id].open_gate()
			get_viewport().set_input_as_handled()

func _refresh_hud() -> void:
	if not loaded_ok:
		return
	%Legend.text = "WASD 移动 / Shift 跑步 / E 开门 / 按住鼠标拖动可平视、轻微仰视 / 滚轮缩放" if walk_mode else "全图查看 · 两条线为原始参考走向，实际通行还需操作机关"
	var parts: Array[String] = []
	for id: String in ["D1","D2","D4","D3"]:
		parts.append(id+(" 已开" if %GeneratedMaze.gates[id].is_open else " 关闭"))
	var hint := "寻找同号开关；开启后保持。D2 可绕行；A/B 参考线不包含机关绕行。"
	if is_instance_valid(closest_switch):
		hint = "按 E 操作 "+str(closest_switch.gate_id).replace("D","S")+"，打开 "+str(closest_switch.gate_id)
	if completed:
		hint = "已到出口，灰模通关！可重置机关再次检查其他路线。"
	%Status.text = " / ".join(parts)+"  ·  "+hint

func reset_level() -> void:
	%GeneratedMaze.reset_mechanisms()
	completed = false
	reset_walk()
	set_walk_mode(true)
	inspection_picker.select(0)

func inspect_location(index: int) -> void:
	if index == 0:
		return
	if index in [21,23]:
		set_walk_mode(true)
		%Player.position = Vector3(3.6,-0.56,21.6) if index==21 else Vector3(37.2,0.04,15.6)
		%Player.velocity = Vector3.ZERO
		%Player.visual.set_locomotion(0)
		%FollowRig.reset_view()
		%FollowRig.yaw = PI if index==21 else -PI/2
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
	var points := [Vector3.ZERO,Layout.cell_point([16,1]),Layout.cell_point([14,13]),Layout.cell_point([8,18]),Vector3(37.2,2.6,18),Layout.cell_point([6,15]),Layout.cell_point([18,3]),Layout.cell_point([5,0]),Layout.cell_point([4,1],-0.6),Layout.cell_point([5,3],0.9),Vector3(24,0,22.8),Layout.cell_point([7,9]),Layout.cell_point([7,11]),Layout.cell_point([11,10]),Layout.cell_point([12,10],1.2),Layout.cell_point([12,15],0.6),Layout.cell_point([9,18])]
	%Player.position = points[index]+Vector3(0,0.04,0)
	%Player.velocity = Vector3.ZERO
	%Player.visual.set_locomotion(0)
	%FollowRig.reset_view()
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
