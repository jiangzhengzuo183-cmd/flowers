extends Area3D

const TV := preload("res://modules/tv_fx/tv_fx.tscn")
const Field := preload("res://modules/maze02_items/tv_field.gdshader")
const Broadcast := preload("res://modules/maze02_items/assets/tv_science_news.mp3")
const FIELD_HEIGHT := 1.9
const IDLE_INTENSITY := 0.25
const ACTIVE_INTENSITY := 0.60
const QUIET_DB := -70.0
const ENTRY_MARGIN := 0.12

@export_range(0.4, 10.0, 0.05) var radius := 3.0
@export_range(3.5, 20.0, 0.25) var sensing_radius := 14.5
@export var broadcast: AudioStreamMP3 = Broadcast
var facing := 0.0
var noise: AudioStreamWAV
var active := false
var illuminated := false
var _tv: Node3D
var _ring: MeshInstance3D
var _ring_material: ShaderMaterial
var _ring_visibility := 0.0
var _audio: AudioStreamPlayer3D
var _speech: AudioStreamPlayer3D
var _station_time := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var collider := CollisionShape3D.new()
	collider.name = "InterferenceCylinder"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = FIELD_HEIGHT
	collider.shape = cylinder
	collider.position.y = FIELD_HEIGHT * 0.5 - 0.12
	add_child(collider)

	_ring = MeshInstance3D.new()
	_ring.name = "InterferenceRing"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	_ring.mesh = plane
	_ring.position.y = 0.023
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_material = ShaderMaterial.new()
	_ring_material.shader = Field
	_ring.material_override = _ring_material
	_ring.hide()
	add_child(_ring)

	_tv = TV.instantiate()
	_tv.rotation.y = facing
	_tv.scale = Vector3.ONE * 0.010
	_tv.intensity = IDLE_INTENSITY
	_tv.blue_glow_strength = 0.12
	_tv.screen_brightness = 0.20
	_tv.spill_energy_scale = 0.16
	add_child(_tv)
	_tv.set_symbols_enabled(false)
	var spill: OmniLight3D = _tv.blue_light
	if spill:
		# The source model is in centimeters. Give its existing light a world-space range.
		spill.reparent(self)
		spill.scale = Vector3.ONE
		spill.omni_range = radius
		spill.omni_attenuation = 2.8
		spill.light_color = Color(0.19, 0.59, 1.0)

	_audio = _make_audio("ElectronicStatic", noise)
	var program := broadcast.duplicate() as AudioStreamMP3
	program.loop = true
	_speech = _make_audio("EnglishBroadcast", program)

func _make_audio(id: String, stream: AudioStream) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = id
	player.stream = stream
	player.position.y = 0.55
	# Keep spatial panning while gain follows the player, independently of camera zoom.
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.max_distance = 0.0
	player.volume_db = QUIET_DB
	add_child(player)
	return player

func contains_player(actor: CharacterBody3D) -> bool:
	# Walls are excluded by the Area mask, including when the player is in an adjacent corridor.
	var offset := actor.global_position - global_position
	var trigger_radius := radius if active else radius - ENTRY_MARGIN
	return actor.controls_enabled and absf(offset.y) < FIELD_HEIGHT - 0.12 \
		and Vector2(offset.x, offset.z).length_squared() <= trigger_radius * trigger_radius

func update_interference(actor: CharacterBody3D, sound_enabled: bool, delta: float) -> void:
	_station_time += delta
	var entered := is_instance_valid(actor) and contains_player(actor)
	var distance := INF
	if is_instance_valid(actor) and actor.controls_enabled:
		distance = actor.global_position.distance_to(global_position)
	var light_threshold := sensing_radius if illuminated else sensing_radius - 0.18
	illuminated = distance <= light_threshold
	if entered != active:
		active = entered
	var fade_seconds := 0.35 if active else 0.55
	_ring_visibility = move_toward(_ring_visibility, 1.0 if active else 0.0, delta / fade_seconds)
	_ring_material.set_shader_parameter("presence", smoothstep(0.0, 1.0, _ring_visibility))
	_ring.visible = _ring_visibility > 0.0
	# Ease the source's existing CRT and spill together instead of flashing on entry.
	_tv.intensity = move_toward(_tv.intensity, ACTIVE_INTENSITY if illuminated else IDLE_INTENSITY, delta * 1.8)
	_tv.blue_glow_strength = move_toward(_tv.blue_glow_strength, 0.85 if illuminated else 0.12, delta * 2.8)
	_tv.screen_brightness = move_toward(_tv.screen_brightness, 0.42 if illuminated else 0.20, delta * 1.4)
	var gain := pow(1.0 - smoothstep(0.75, sensing_radius, distance), 1.4)
	var level := maxf(QUIET_DB, linear_to_db(gain) - 9.0) if gain > 0.0 else QUIET_DB
	for player: AudioStreamPlayer3D in [_audio, _speech]:
		if not sound_enabled:
			player.stop()
			player.volume_db = QUIET_DB
			continue
		if level > QUIET_DB and not player.playing:
			player.play(fmod(_station_time, player.stream.get_length()) if player == _speech else 0.0)
		var target := level + 3.0 if player == _speech and level > QUIET_DB else level
		player.volume_db = move_toward(player.volume_db, target, delta * 105.0)
		if level <= QUIET_DB and player.volume_db <= QUIET_DB:
			player.stop()

static func electronic_static() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8351
	var data := PackedByteArray()
	const SAMPLE_RATE := 16000
	const SAMPLES := SAMPLE_RATE * 2
	data.resize(SAMPLES * 2)
	var previous := 0.0
	for i in SAMPLES:
		var white := rng.randf_range(-1.0, 1.0)
		previous = lerpf(previous, white, 0.34)
		var time := float(i) / SAMPLE_RATE
		var flutter := 0.64 + 0.15 * sin(TAU * 9.0 * time) + 0.15 * sin(TAU * 17.0 * time)
		var edge := smoothstep(0.0, 0.012, time) * (1.0 - smoothstep(1.988, 2.0, time))
		var sample := ((white - previous) * 0.47 + previous * 0.22 + 0.085 * sin(TAU * 60.0 * time) + 0.045 * sin(TAU * 120.0 * time)) * flutter * edge
		data.encode_s16(i * 2, roundi(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = SAMPLES
	return stream
