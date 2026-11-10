extends "res://scripts/levels/maze01_key_scene.gd"
## Maze02 owns its environment resources; gameplay remains in the shared scene script.

@export var maze02_lighting: Resource
@export var maze02_music: AudioStream
const Sand := preload("res://art/maze02/environment/Maze02_SandParticles.tscn")
const Plaster := preload("res://art/maze02/environment/memory_plaster.gd")
const WindBed := preload("res://art/maze02/audio/sand_wind_bed.wav")
const DryGarden := preload("res://art/maze02/environment/maze02_dry_garden.gd")
const FishLeaps := preload("res://art/maze02/environment/maze02_fish_leaps.gd")
const Ruins := preload("res://art/maze02/ruins/maze02_ruins.gd")
const FloorDebris := preload("res://art/maze02/ruins/maze02_floor_debris.gd")
const GateWear := preload("res://art/maze02/ruins/maze02_gate_wear.gd")
const KeysOnly := preload("res://scripts/levels/maze02_key_items.gd")
const Room := preload("res://scripts/levels/round_hall.gd")
const RUIN_INSPECTION := 100
var _chapel_blend := 0.0
var _music_player: AudioStreamPlayer
var _wind_audio: AudioStreamPlayer

func _ready() -> void:
	super()
	if loaded_ok and dream_art_enabled:
		var world: Node3D = %Player.get_parent()
		_install_music()
		_install_wind_audio()
		maze02_lighting.apply(world)
		Plaster.apply(%GeneratedMaze, wall_occlusion)
		_install_floor_debris(world)
		GateWear.apply(%GeneratedMaze.gates)
		world.add_child(Sand.instantiate())
		DryGarden.apply(%GeneratedMaze.get_node("EarthBearer"))
		FishLeaps.new().install(%GeneratedMaze.architecture.get_node("NorthwestCourtyard"),
			float(Layout.config().northwest.waterSurface))
		if is_instance_valid(_key_items):
			for slot: String in [String(MazeItems.RABBIT), "UseItem"]:
				var control := _key_items.inventory.get_node(slot) as Control
				control.hide()
				# The shared fullscreen layout may restore hidden controls on exit.
				control.visibility_changed.connect(_keep_hidden.bind(control))
		if inspection_picker.item_count > 24:
			inspection_picker.remove_item(24)
		var ruins := Ruins.inspection_sites()
		for i in ruins.size():
			inspection_picker.add_item(ruins[i].label, RUIN_INSPECTION + i)
		get_window().title = "Maze 02 · Memory Distortion"
		$Heading.text = "Maze 02 · Memory Distortion"
		%Summary.text = "金橙天光 · 青蓝余辉 · 断拱遗迹"

func _install_music() -> void:
	_music_player = sound.get_node("Music") as AudioStreamPlayer
	var was_playing := _music_player.playing
	_music_player.stream = maze02_music
	if was_playing:
		_music_player.play()
	for child: Node in $WalkControls.get_children():
		if child is LinkButton and child.uri == MazeSound.MUSIC_SOURCE:
			var title := Label.new()
			title.text = "配乐 · 沙中回廊"
			title.tooltip_text = "Maze 02 原创循环配乐"
			title.add_theme_color_override("font_color", Color("53674e"))
			title.add_theme_font_size_override("font_size", 14)
			child.replace_by(title)
			child.queue_free()
			break

func _install_wind_audio() -> void:
	_wind_audio = AudioStreamPlayer.new()
	_wind_audio.name = "SandWindBed"
	_wind_audio.stream = WindBed
	_wind_audio.volume_db = -27.0
	sound.add_child(_wind_audio)

func _install_floor_debris(world: Node3D) -> void:
	var debris := FloorDebris.new()
	debris.name = "Maze02FloorDebris"
	debris.protected_points.append(%Player.position)
	for gate: Node3D in %GeneratedMaze.gates.values():
		debris.protected_points.append(gate.position)
	if is_instance_valid(_key_items):
		for pickup: Node3D in _key_items.key_pickups.values():
			debris.protected_points.append(pickup.position)
	world.add_child(debris)

func _update_wind_audio(delta: float, indoors: bool) -> void:
	var level := -41.0 if indoors else -27.0
	_wind_audio.volume_db = move_toward(_wind_audio.volume_db, level, delta * 16.0)
	if _music_player.playing and not _wind_audio.playing:
		_wind_audio.play()
	elif not _music_player.playing and _wind_audio.playing:
		_wind_audio.stop()

func inspect_location(index: int) -> void:
	if index < 0 or index >= inspection_picker.item_count:
		return
	var site_index := inspection_picker.get_item_id(index) - RUIN_INSPECTION
	var ruins := Ruins.inspection_sites()
	if site_index < 0 or site_index >= ruins.size():
		super(index)
		return
	var site: Dictionary = ruins[site_index]
	set_walk_mode(true)
	var point := Layout.cell_point(site.preview)
	point.y = Layout.height_at(Vector2(point.x, point.z)) + 0.04
	%Player.position = point
	%Player.velocity = Vector3.ZERO
	%Player.visual.set_locomotion(0)
	%FollowRig.reset_view()
	%FollowRig.yaw = float(site.get("yaw", 0.0 if site_index == 0 else -PI * 0.5))
	if is_instance_valid(sound):
		sound.sync_actor()
	get_viewport().gui_release_focus()

func _make_items() -> MazeItems:
	if not use_gate_keys:
		return super()
	_key_items = KeysOnly.new()
	return _key_items

func _keep_hidden(control: Control) -> void:
	if control.visible:
		control.hide()

func _process(delta: float) -> void:
	super(delta)
	if not loaded_ok or not dream_art_enabled:
		return
	var feet: Vector3 = %Player.position
	var indoors := walk_mode and Room.contains(Vector2(feet.x, feet.z), Layout.config().building)
	_update_wind_audio(delta, indoors)
	var next := move_toward(_chapel_blend, 1.0 if indoors else 0.0, delta * 2.4)
	if next == _chapel_blend:
		return
	_chapel_blend = next
	var outdoor: Environment = maze02_lighting.environment
	var environment: Environment = %WorldEnvironment.environment
	environment.fog_density = lerpf(outdoor.fog_density, 0.00045, next)
	environment.ambient_light_energy = lerpf(outdoor.ambient_light_energy, 0.39, next)
	environment.ambient_light_color = outdoor.ambient_light_color.lerp(Color(0.95, 0.96, 1.0), next)
