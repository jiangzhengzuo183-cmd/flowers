extends Node
## Scene-local mix. Listen to physical travel, contacts and the existing gate signals.

signal foot_planted(point: Vector3, forward: Vector3, running: bool, wet: bool, side: float)

const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const Music := preload("res://art/maze01/audio/enchanted_valley_loop.wav")
const MUSIC_SOURCE := "https://incompetech.com/music/royalty-free/index.html?Search=Search&isrc=USUAN1200093"
const RunSteps := [
	preload("res://art/maze01/audio/run_stone_1.wav"),
	preload("res://art/maze01/audio/run_stone_2.wav"),
	preload("res://art/maze01/audio/run_stone_3.wav"),
	preload("res://art/maze01/audio/run_stone_4.wav"),
]
const WaterSteps := [
	preload("res://art/maze01/audio/water_run_soft_a.wav"),
	preload("res://art/maze01/audio/water_run_soft_b.wav"),
]
const WaterTakeoff := preload("res://art/maze01/audio/water_jump_soft_takeoff.wav")
const WaterLanding := preload("res://art/maze01/audio/water_jump_soft_landing.wav")
const Takeoff := preload("res://art/maze01/audio/soft_jump_takeoff.wav")
const JumpLanding := preload("res://art/maze01/audio/soft_jump_landing.wav")
const Landing := preload("res://art/maze01/audio/landing.wav")
const GateSlide := preload("res://art/maze01/audio/gate_lowering.wav")
const GateStart := preload("res://art/maze01/audio/gate_mechanical_start.wav")
const ExitBloom := preload("res://art/maze01/audio/exit_bloom.wav")
const MUSIC_DB := -17.0
const POOL := Rect2(0.0, 4.8, 9.6, 9.6)

var _actor: CharacterBody3D
var _music: AudioStreamPlayer
var _steps: AudioStreamPlayer
var _motion: AudioStreamPlayer
var _ending: AudioStreamPlayer
var _pickup: AudioStreamPlayer
var _gate_players: Array[AudioStreamPlayer] = []
var _niche_chimes: Array[AudioStreamPlayer3D] = []
var _music_fade: Tween
var _water_level: float
var _last: Vector3
var _grounded := false
var _jumped := false
var _splash_in_air := false
var _air_peak := 0.0
var _distance := 0.0
var _stride := 0
var _muted := false

func install(parent: Node, actor: CharacterBody3D, gates: Dictionary) -> void:
	name = "MazeSound"
	process_physics_priority = 15
	_actor = actor
	_water_level = float(Layout.config().northwest.waterSurface)
	parent.add_child(self)
	_music = _player("Music")
	_music.stream = Music
	_music.volume_db = MUSIC_DB
	_steps = _player("Footsteps")
	_motion = _player("JumpAndLanding")
	_ending = _player("ExitCue")
	_pickup = _player("PickupCue")
	for gate: Node3D in gates.values():
		var player := _player(str(gate.name) + "Slide")
		var starter := _player(str(gate.name) + "Start")
		gate.legacy_chime_enabled = false
		gate.descent_started.connect(func(): _play(player, GateSlide, -7.5, 0.865))
		gate.get_node("DreamGateFinish").power_released.connect(func(): _play(starter, GateStart, -8.5, 0.88))
		gate.state_applied.connect(func(_is_open: bool):
			player.stop()
			starter.stop())
		_gate_players.append_array([player, starter])
	sync_actor()
	if not OS.has_feature("web"):
		_start_music()

func _player(id: String) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.name = id
	add_child(sound)
	return sound

func bind_niche_chimes(corridor: Node3D) -> void:
	for chime: AudioStreamPlayer3D in corridor.find_children("Chime", "AudioStreamPlayer3D", true, false):
		_niche_chimes.append(chime)

func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		_start_music()

func _start_music() -> void:
	if _muted or _music.playing:
		return
	_music.volume_db = MUSIC_DB
	_music.play()

func set_muted(muted: bool) -> void:
	_muted = muted
	for chime: AudioStreamPlayer3D in _niche_chimes:
		chime.volume_db = -80.0 if muted else -5.0
	if _muted:
		_music.stop()
		stop_transients()
	else:
		_start_music()

func sync_actor() -> void:
	_last = _actor.position
	_grounded = _actor.is_on_floor()
	_air_peak = _last.y
	_jumped = false
	_splash_in_air = false
	_distance = 0.0

func stop_transients() -> void:
	_steps.stop()
	_motion.stop()
	_ending.stop()
	_pickup.stop()
	for player: AudioStreamPlayer in _gate_players:
		player.stop()
	for chime: AudioStreamPlayer3D in _niche_chimes:
		chime.stop()
	if is_instance_valid(_music_fade):
		_music_fade.kill()
	_music.volume_db = MUSIC_DB
	sync_actor()

func play_exit() -> void:
	if _muted:
		return
	_play(_ending, ExitBloom, -11.0)
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", MUSIC_DB - 5.0, 0.23)
	_music_fade.tween_interval(1.9)
	_music_fade.tween_property(_music, "volume_db", MUSIC_DB, 1.55)

func play_item_pickup(cue: AudioStream) -> void:
	_play(_pickup, cue, -10.5)

func _physics_process(delta: float) -> void:
	var point := _actor.position
	var travel := point - _last
	var step := Vector2(travel.x, travel.z).length()
	if not _actor.controls_enabled or step > 0.40 or absf(travel.y) > 0.42:
		sync_actor()
		return
	var grounded := _actor.is_on_floor()
	var wet := _in_water(point)
	if not grounded:
		_distance = 0.0
		_air_peak = maxf(_air_peak, point.y)
		if _grounded and travel.y > delta * 1.4 and _actor.velocity.y > 2.0:
			_jumped = true
			if _in_water(_last):
				_play(_motion, WaterTakeoff, -18.0)
			else:
				_play(_motion, Takeoff, -9.0)
		elif wet and not _in_water(_last) and travel.y < -delta:
			_splash_in_air = true
			_play(_motion, WaterLanding, -15.0)
	elif not _grounded:
		if not _splash_in_air and (_jumped or _air_peak - point.y > 0.16):
			var landing := JumpLanding if _jumped else Landing
			if wet:
				_play(_motion, WaterLanding, -15.0)
			else:
				_play(_motion, landing, -11.0)
		_jumped = false
		_splash_in_air = false
		_air_peak = point.y
		_distance = 0.0
	else:
		_air_peak = point.y
		if step > 0.004:
			var running := step > delta * 2.08
			# The run clip has roughly one contact every 0.32 seconds at full speed.
			_distance = _distance + step if running else 0.0
			if _distance >= 0.84:
				_distance -= 0.84
				_footstep(point, Vector3(travel.x,0,travel.z).normalized(), wet)
		else:
			_distance = minf(_distance, 0.19)
	_grounded = grounded
	_last = point

func _in_water(point: Vector3) -> bool:
	return point.y < _water_level - 0.02 and POOL.has_point(Vector2(point.x, point.z))

func _footstep(point: Vector3, forward: Vector3, wet: bool) -> void:
	_stride += 1
	foot_planted.emit(point, forward, true, wet, -1.0 if _stride % 2 == 0 else 1.0)
	var pitch := randf_range(0.975, 1.026)
	var volume := -12.8 + randf_range(-0.8, 0.8)
	if wet:
		_play(_steps, WaterSteps[_stride % WaterSteps.size()], volume - 3.0, pitch)
	else:
		_play(_steps, RunSteps[_stride % RunSteps.size()], volume, pitch)

func _play(player: AudioStreamPlayer, stream: AudioStream, volume: float, pitch: float = 1.0) -> void:
	if _muted:
		return
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	player.play()
