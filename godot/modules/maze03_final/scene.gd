extends "res://scripts/maze/maze_scene.gd"
## Finished Maze 01 is instantiated and finished first; only this scene is transformed.
const Finish := preload("res://art/maze01/maze01_dream_finish.gd")
const Occlusion := preload("res://modules/maze03_final/occlusion.gd")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const Footprints := preload("res://art/maze01/stone_footsteps.gd")
const Sound := preload("res://modules/maze03_final/sound.gd")
const PlayView := preload("res://modules/maze03_final/play_view.gd")
const Landscape := preload("res://modules/maze03_final/landscape.gd")
@export_range(1.0,2.5,0.05) var barrier_speed_multiplier := 1.35
@export_range(0.5,8.0,0.1) var barrier_duration_seconds := 3.0
var wall_occlusion: Node
var sound: Sound
var footprints: Node3D
var play_view: CanvasLayer
var earthquakes: Node3D
var race: Node
var _items: Node
var _perks: Node

func _ready() -> void:
	super()
	if not loaded_ok:
		return
	var generator := %GeneratedMaze
	var world: Node3D = %Player.get_parent()
	var initial_occlusion := Occlusion.new()
	generator.add_child(initial_occlusion)
	initial_occlusion.configure(generator, %Player, %FollowRig, Layout.config().occlusion)
	Finish.apply(generator, initial_occlusion, maze_data.checkpoints, %Player)
	# Remove the old atmosphere and all of its instantiated effects before rendering.
	for child in world.get_children():
		if child not in [%Player,%FollowRig,%WorldEnvironment,%CameraRig,generator,world.get_node("Sun"),world.get_node("SoftFill")]:
			child.free()
	initial_occlusion.free()
	generator.remodel()
	_update_local_route()
	generator.hide_inspection_marks = true
	generator.set_walk_cutaway(true)
	preload("res://modules/maze03_final/small_stone_details.gd").apply(generator)
	_finish_palette()
	preload("res://modules/maze03_final/surface_finish.gd").apply(generator)
	wall_occlusion = Occlusion.new()
	generator.add_child(wall_occlusion)
	wall_occlusion.configure(generator,%Player,%FollowRig,Layout.config().occlusion)
	_apply_environment(world)
	preload("res://modules/maze03_final/character_finish.gd").apply(%Player)
	preload("res://modules/maze03_final/sanctuary_interior.gd").install(generator.sanctuary,world.get_node("Sun"))
	world.add_child(Landscape.new())
	var water_interaction := preload("res://modules/maze03_final/water_interaction.gd").new()
	water_interaction.install(generator.sanctuary.get_node("ReflectiveRingWater"),%Player,-0.14)
	sound = Sound.new()
	sound.install(self,%Player,{})
	_items=preload("res://modules/maze03_final/cake_items.gd").new()
	add_child(_items)
	_items.install(self)
	_perks=_items.effects
	var accents := preload("res://modules/maze03_final/race_inlays.gd").new()
	accents.install(generator,%Player)
	earthquakes = preload("res://modules/maze03_final/earthquake.gd").new()
	earthquakes.install(generator,%Player,%FollowRig,sound,world.get_node("FinalTrialHorizon/WhiteMegastructureEnclosure"))
	earthquakes.bind_comet(world.get_node("FinalTrialHorizon/TrialAtmosphere/DistantSkyComet"))
	footprints = Footprints.new()
	footprints.install(world)
	sound.foot_planted.connect(footprints.step)
	%Player.boost_multiplier = barrier_speed_multiplier
	%Player.boost_seconds = barrier_duration_seconds
	for barrier in generator.barriers:
		barrier.crossed.connect(_barrier_cue)
	# Formal play-only layout/fullscreen is managed by GameHUD.
	$Heading.text = "Maze 03 · 最终试炼"
	%Summary.text = "冷白圣堂 · 环绕镜池 · 冲刺能量屏障"
	%PaletteButton.hide()
	%Legend.text = "WASD 移动 / Shift 开/关冲刺 / 空格跳跃 / 拖动视角 / F10 纯画面 / F11 全屏 / Esc 返回"
	%Status.text = "直接穿过蓝色屏障可获得 3 秒加速。"
	for label: Label3D in generator.find_children("*","Label3D",true,false):
		label.hide()
	for id in ["Entry","Exit"]:
		var marker := generator.get_node_or_null(id)
		if marker != null:
			marker.hide()
	%FollowRig.camera.far = 500
	%CameraRig.camera.far = 500
	var mute := Button.new()
	mute.text = "声音：开"
	mute.toggle_mode = true
	mute.toggled.connect(func(off: bool):
		sound.set_muted(off)
		mute.text = "声音：关" if off else "声音：开")
	$WalkControls.add_child(mute)
	preload("res://modules/stamina/runtime.gd").install(self, false, true)
	race = preload("res://modules/maze03_race/controller.gd").new()
	add_child(race)
	race.install(self)
	get_window().title = "Maze 03 · 最终竞速迷宫"

func _barrier_cue() -> void:
	sound.play_barrier()

func _finish_palette() -> void:
	var wall_materials: Dictionary = {}
	var grain: Texture2D = load("res://art/maze01/materials/plaster_cream.tres").normal_texture
	for mesh: MeshInstance3D in %GeneratedMaze.find_children("*","MeshInstance3D",true,false):
		var role := str(mesh.get_meta("art_role",""))
		var original: Material = mesh.material_override
		if original==null:
			continue
		if mesh.has_meta("accent_tint"):
			mesh.remove_meta("accent_tint")
		var wall_role := role in ["plaster","prism_plaster","wall_banded","moulding","chapel_wall","plinth","pool_rail","porch_roof","roof"]
		var new_white: bool = original is StandardMaterial3D and original.albedo_color.is_equal_approx(Color("e9e9e5"))
		if wall_role or new_white:
			var legacy: bool = original is ShaderMaterial and original.get_shader_parameter("legacy_winding")==true
			if not wall_materials.has(legacy):
				var finish := ShaderMaterial.new()
				finish.shader = preload("res://modules/maze03_final/wall_finish.gdshader")
				finish.set_shader_parameter("stone_color",Color("e9e9e5"))
				finish.set_shader_parameter("legacy_winding",legacy)
				finish.set_shader_parameter("grain",grain)
				wall_materials[legacy] = finish
			mesh.material_override = wall_materials[legacy]
func _apply_environment(world: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://modules/maze03_final/sky.gdshader")
	sky.sky_material = material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e6edf4")
	environment.ambient_light_energy = 0.38
	environment.reflected_light_source = 1
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 0.86
	environment.fog_enabled = true
	environment.fog_light_color = Color("d6e8f2")
	environment.fog_density = 0.0012
	environment.fog_sky_affect = 0.0
	%WorldEnvironment.environment = environment
	var sun := world.get_node("Sun") as DirectionalLight3D
	sun.light_color = Color("fffaf2")
	sun.light_energy = 0.45
	sun.rotation_degrees = Vector3(-46,-34,0)
	sun.shadow_opacity = 0.35
	var fill := world.get_node("SoftFill") as DirectionalLight3D
	fill.light_color = Color("dce8f4")
	fill.light_energy = 0.25

func reset_walk() -> void:
	super()
	if is_instance_valid(_items):
		_items.reset_items()
	if is_instance_valid(sound):
		sound.stop_transients()
	if is_instance_valid(earthquakes):
		earthquakes.reset_run()
	for barrier in %GeneratedMaze.barriers:
		barrier.reset_contact()
	if is_instance_valid(race):
		race.restart()

func _update_local_route() -> void:
	maze_data = maze_data.duplicate(true)
	var original: Array = maze_data.routes.B.cellPath
	var start := -1
	var end := -1
	for i in original.size():
		if Layout.cell_key(original[i]) == "5,10":
			start = i
		if Layout.cell_key(original[i]) == "9,14":
			end = i
	if start < 0 or end <= start:
		push_error("Could not locate the sanctuary portion of route B")
		return
	var local_cells: Array = [[5,10],[5,9.5],[5.375,9.5],[6,9.5],[7,9.5],[8,9.5],[9,9.5],[10,9.5],[11,9.5],[12,9.5],[12.833333,9.5],[12.833333,13.25],[11,13.25],[10,13.25],[9,13.25],[9,14]]
	maze_data.routes.B.cellPath = original.slice(0,start) + local_cells + original.slice(end+1)
	_update_northwest_reference()
	maze_data.routes.B.moveCount = maze_data.routes.B.cellPath.size()-1
	%GeneratedMaze.refresh_reference_routes(maze_data)
	%RouteB.text = "路线 B · 圣堂贯通"
func _update_northwest_reference() -> void:
	var path: Array = maze_data.routes.B.cellPath
	var start := -1
	var end := -1
	for i in path.size():
		if Layout.cell_key(path[i])=="5,0":
			start = i
		if start>=0 and Layout.cell_key(path[i])=="4,4":
			end = i
			break
	if start<0 or end<=start:
		push_error("Northwest reference connection not found")
		return
	# Actual curved-maze route, mapped only into this scene's inspection reference.
	var points := [Vector2(1.2,13.2),Vector2(1.65,12.0),Vector2(1.65,10.0),Vector2(2.2,8.0),Vector2(4.7,8.0),Vector2(6.8,8.4),Vector2(7.9,9.6),Vector2(8.6,10.8),Vector2(10.8,10.8)]
	var cells: Array = []
	for p: Vector2 in points:
		cells.append([p.y/2.4-0.5,p.x/2.4-0.5])
	maze_data.routes.B.cellPath = path.slice(0,start)+cells+path.slice(end+1)








func set_walk_mode(enabled: bool) -> void:
	super(enabled)
	if is_instance_valid(race):
		race.sync_controls()
