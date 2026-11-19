extends Node
## Short grains from the project's credited CC0 paper recording; no network at runtime.
const PAPER := preload("res://modules/visual_novel/assets/audio/paper.mp3")
var companion: Node2D
var voice: AudioStreamPlayer
var step_age := 0.0
var grain_age := 0.0
var steps := 0
var bus_name: StringName
var mute_when_unfocused := true
func install(mouse: Node2D) -> void:
	companion = mouse
	bus_name = StringName("MenuPaperFoley_%s" % get_instance_id())
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index,bus_name)
	AudioServer.set_bus_send(index,"Master")
	var high := AudioEffectHighPassFilter.new()
	high.cutoff_hz = 240.0
	AudioServer.add_bus_effect(index,high)
	var low := AudioEffectLowPassFilter.new()
	low.cutoff_hz = 3400.0
	AudioServer.add_bus_effect(index,low)
	voice = AudioStreamPlayer.new()
	voice.stream = PAPER
	voice.bus = bus_name
	voice.volume_db = -60.0
	add_child(voice)
func _process(delta: float) -> void:
	if not is_instance_valid(voice) or not is_instance_valid(companion): return
	var speed: float = companion.velocity.length()/maxf(companion.unit,0.01)
	var walking: bool = companion.enabled and companion.state==companion.State.FOLLOW and speed>22.0 and not get_tree().paused
	if mute_when_unfocused and not get_window().has_focus(): walking = false
	if not walking:
		step_age = 0.0
		if voice.playing:
			voice.volume_db = move_toward(voice.volume_db,-72.0,delta*650.0)
			if voice.volume_db <= -65.0: voice.stop()
		return
	step_age += delta*clampf(speed/230.0,0.55,1.2)
	if step_age >= 0.20:
		step_age = fmod(step_age,0.20)
		steps += 1
		grain_age = 0.0
		voice.pitch_scale = [0.99,1.03,0.97,1.01][steps%4]
		voice.volume_db = -55.0
		voice.play([0.025,0.16,0.29][steps%3])
	if voice.playing:
		grain_age += delta
		var target := -31.0-3.0*(1.0-clampf(speed/270.0,0.0,1.0))
		if grain_age > 0.095:
			voice.volume_db = move_toward(voice.volume_db,-72.0,delta*700.0)
			if voice.volume_db <= -65.0: voice.stop()
		else: voice.volume_db = move_toward(voice.volume_db,target,delta*1500.0)
func _exit_tree() -> void:
	if is_instance_valid(voice): voice.stop()
	var index := AudioServer.get_bus_index(bus_name)
	if index>0: AudioServer.remove_bus(index)
