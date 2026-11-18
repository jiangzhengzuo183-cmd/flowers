extends "res://art/maze01/maze01_sound.gd"
const RaceMusic := preload("res://modules/maze03_final/our_expanse.mp3")
const WindBed := preload("res://art/maze02/audio/sand_wind_bed.wav")
const WindSettings := preload("res://modules/maze03_final/wind_settings.tres")
var _wind_audio: AudioStreamPlayer
var _wind_elapsed := 0.0
var barrier_whoosh: AudioStreamWAV
var quake_audio: AudioStreamPlayer
var quake_rumble: AudioStreamWAV

func _start_music() -> void:
	if not _music.stream is AudioStreamMP3:
		var track := RaceMusic.duplicate() as AudioStreamMP3
		track.loop = true
		_music.stream = track
	super()
	_start_wind()

func _in_water(point: Vector3) -> bool:
	return preload("res://modules/maze03_final/sanctuary.gd").POOL.has_point(Vector2(point.x,point.z)) and point.y < -0.165

func play_barrier() -> void:
	if _muted:
		return
	if barrier_whoosh == null:
		barrier_whoosh = _make_whoosh()
	_play(_pickup,barrier_whoosh,-15.0)

func _make_whoosh() -> AudioStreamWAV:
	# A short air-rise cue only. The downloaded race music is left unchanged.
	var rate := 22050
	var count := int(rate*0.64)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 30511
	var filtered := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i)/rate
		var u := float(i)/count
		filtered = lerpf(filtered,rng.randf_range(-1,1),0.14+u*0.12)
		phase += TAU*lerpf(240.0,810.0,smoothstep(0.0,0.8,u))/rate
		var envelope := sin(PI*u)*exp(-u*1.5)
		var sample := (filtered*0.74+sin(phase)*0.075)*envelope
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _exit_tree() -> void:
	# Release scene-local playback when returning to the chooser or reloading.
	for player in get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	barrier_whoosh = null

func _start_wind() -> void:
	if _muted or not is_instance_valid(_music) or not _music.playing:
		return
	if not is_instance_valid(_wind_audio):
		_wind_audio = _player("WindAmbience")
		var bed := WindBed.duplicate() as AudioStreamWAV
		bed.loop_mode = AudioStreamWAV.LOOP_FORWARD
		bed.loop_begin = 0
		bed.loop_end = int(bed.get_length()*bed.mix_rate)
		_wind_audio.stream = bed
		_wind_audio.volume_db = -48.0
	if not _wind_audio.playing:
		_wind_audio.play()

func set_muted(muted: bool) -> void:
	super(muted)
	if muted and is_instance_valid(quake_audio):
		quake_audio.stop()
	if muted and is_instance_valid(_wind_audio):
		_wind_audio.stop()
	elif not muted:
		_start_wind()

func _process(delta: float) -> void:
	_wind_elapsed += delta
	if not is_instance_valid(_wind_audio) or not _wind_audio.playing:
		return
	var gust: float = WindSettings.gust_at(_wind_elapsed)
	var moving := clampf(Vector2(_actor.velocity.x,_actor.velocity.z).length()/3.6,0.0,1.0)
	var indoors := absf(_actor.position.x-24.0)<3.45 and absf(_actor.position.z-22.8)<3.45
	var target: float = WindSettings.base_volume_db+gust*WindSettings.gust_volume_db+moving*1.5-(8.0 if indoors else 0.0)
	_wind_audio.volume_db = lerpf(_wind_audio.volume_db,target,1.0-exp(-delta*1.8))
	_wind_audio.pitch_scale = 0.98+gust*0.035

func prepare_quake() -> void:
	quake_audio = _player("SpaceResonanceRumble")
	var rate := 22050
	var count := int(rate*3.7)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 170311
	var low := 0.0
	var grit := 0.0
	for i in count:
		var u := float(i)/count
		low = lerpf(low,rng.randf_range(-1.0,1.0),0.020)
		grit = lerpf(grit,rng.randf_range(-1.0,1.0),0.16)
		var envelope := smoothstep(0.0,0.10,u)*(1.0-smoothstep(0.45,1.0,u))
		var sample := (low*3.5+grit*0.18)*envelope*(0.8+sin(u*37.0)*0.12)
		bytes.encode_s16(i*2,int(clampf(sample,-0.95,0.95)*32767))
	quake_rumble = AudioStreamWAV.new()
	quake_rumble.format = AudioStreamWAV.FORMAT_16_BITS
	quake_rumble.mix_rate = rate
	quake_rumble.data = bytes
func play_quake() -> void:
	if not _muted:
		_play(quake_audio,quake_rumble,-13.0)
func stop_transients() -> void:
	super()
	if is_instance_valid(quake_audio):
		quake_audio.stop()


func play_minor_quake() -> void:
	if not _muted and not quake_audio.playing:
		_play(quake_audio,quake_rumble,-26.0,1.25)

