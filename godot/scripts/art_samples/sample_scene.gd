extends "res://scripts/maze_runs/maze01_base.gd"
const Lighting := preload("res://art/environments/maze01_dream_lighting.tres")
const Fade := preload("res://art/maze01/plaster_fade.gdshader")
const Plaster := preload("res://art/maze01/materials/plaster_cream.tres")
const Palette := preload("res://art/maze01/sample_palette.gd")
var floor_picker: OptionButton

func _ready() -> void:
	super()
	if not loaded_ok:
		return
	Lighting.apply(%Player.get_parent())
	# Keep the existing nine-ray thresholds and physical layers. Only replace
	# the paired visual fade shader for the locally upgraded plaster meshes.
	for group: Dictionary in wall_occlusion.groups.values():
		for entry: Dictionary in group.entries:
			if entry.mesh.get_meta("art_role","")=="plaster":
				entry.alpha.shader = Fade
				entry.alpha.set_shader_parameter("stone_color",entry.original.albedo_color)
				entry.alpha.set_shader_parameter("stone_roughness",entry.original.roughness)
				entry.alpha.set_shader_parameter("grain",Plaster.normal_texture)
				entry.alpha.set_shader_parameter("opacity",1.0)
	get_node("Heading").text = "Maze 01 · 梦境建筑样板"
	%Summary.text = "暖白石膏 · 湖蓝釉面 · 粉紫天空"
	%TopView.hide()
	%WalkButton.hide()
	for spec: Array in [["教堂全景",show_chapel],["人物试玩",show_player],["室内灯光",show_interior]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		get_node("WalkControls").add_child(button)
	floor_picker = OptionButton.new()
	floor_picker.name = "FloorPicker"
	for option: Array in Palette.FLOOR_OPTIONS:
		floor_picker.add_item(option[0])
	floor_picker.item_selected.connect(set_floor_style)
	get_node("WalkControls").add_child(floor_picker)
	get_window().title = "Maze 01 · 第二轮美术样板"
	show_chapel()

func set_floor_style(index: int) -> void:
	%GeneratedMaze.set_floor_color(Palette.FLOOR_OPTIONS[index][1])
	floor_picker.select(index)
	get_viewport().gui_release_focus()

func show_chapel() -> void:
	set_walk_mode(false)
	%CameraRig.center = Vector3(25,4.1,23.2)
	%CameraRig.world_size = Vector3(23,14,23)
	%CameraRig.extent = 23
	%CameraRig.reset_view()
	%CameraRig.yaw = -0.72
	%CameraRig.pitch = 0.43
	%CameraRig.zoom = 1.65
	%CameraRig._update_camera()
	%GeneratedMaze.update_room_view(Vector3.ZERO,false,false)

func show_player() -> void:
	set_walk_mode(true)
	%Player.reset_player()
	%Player.position = Vector3(22.8,0.04,17.5)
	%Player.visual.rotation.y = PI
	%FollowRig.reset_view()
	%FollowRig.yaw = PI
	%FollowRig.pitch = 0.26
	%FollowRig.distance = 3.8
	get_viewport().gui_release_focus()

func show_interior() -> void:
	set_walk_mode(true)
	%Player.reset_player()
	%Player.position = Vector3(24,0.04,22.8)
	%FollowRig.reset_view()
	%FollowRig.yaw = 0.8
	%FollowRig.pitch = -0.10
	get_viewport().gui_release_focus()
