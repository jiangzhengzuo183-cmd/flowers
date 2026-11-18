extends "res://scripts/maze/maze_scene.gd"
const Finish:=preload("res://art/maze03/finish.gd")
const Landscape:=preload("res://scripts/maze03/landscape.gd")
const WallOcclusion:=preload("res://scripts/levels/wall_occlusion.gd")
const FormalEnvironment:=preload("res://art/maze03/environment.tres")
@export_range(1.0,2.5,0.05) var barrier_speed_multiplier:=1.35
@export_range(0.1,8.0,0.1) var barrier_duration_seconds:=2.0
var wall_occlusion: Node
func _ready() -> void:
	super()
	if not loaded_ok:
		return
	get_window().title="Maze 03 · 银蓝圣堂"
	$Heading.text="Maze 03 · 银蓝圣堂"
	%Summary.text="白色竖向肋片 · 镜池 · 分离踏板"
	%PaletteButton.hide()
	%Status.hide()
	%Legend.text="WASD 移动 · Shift 跑步 · 空格跳跃 · 鼠标观察 · 蓝色屏障穿越加速"
	var world: Node3D=%Player.get_parent()
	var environment:=FormalEnvironment.duplicate(true) as Environment
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure=0.83
	environment.fog_enabled=true
	environment.fog_light_color=Color("c8d5df")
	environment.fog_density=0.0018
	environment.fog_sky_affect=0.0
	%WorldEnvironment.environment=environment
	world.get_node("Sun").light_color=Color("fff9f0")
	world.get_node("Sun").light_energy=0.24
	world.get_node("Sun").rotation_degrees=Vector3(-38,-32,0)
	world.get_node("Sun").shadow_opacity=0.64
	world.get_node("SoftFill").show()
	world.get_node("SoftFill").light_energy=0.045
	world.get_node("SoftFill").light_color=Color("cbdff1")
	world.add_child(Landscape.new())
	wall_occlusion=WallOcclusion.new()
	%GeneratedMaze.add_child(wall_occlusion)
	wall_occlusion.configure(%GeneratedMaze,%Player,%FollowRig)
	Finish.apply(%GeneratedMaze,wall_occlusion,%Player)
	%FollowRig.camera.far=500.0
	%CameraRig.camera.far=500.0
	%FollowRig.camera.cull_mask=7
	%CameraRig.camera.cull_mask=7
	for barrier: Area3D in %GeneratedMaze.barriers:
		barrier.speed_multiplier=barrier_speed_multiplier
		barrier.duration_seconds=barrier_duration_seconds
func set_walk_mode(enabled: bool) -> void:
	super(enabled)
	if loaded_ok:
		%Legend.text="WASD 移动 · Shift 跑步 · 空格跳跃 · 鼠标观察 · 蓝色屏障穿越加速" if enabled else "全图查看 · 左键旋转 · 滚轮缩放 · 右键平移"
