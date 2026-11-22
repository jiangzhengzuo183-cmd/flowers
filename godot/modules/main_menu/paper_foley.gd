extends Node
## Short grains from the project's credited CC0 paper recording; no network at runtime.
const PAPER := preload("res://modules/visual_novel/assets/audio/paper.mp3")
var companion: Node2D
var voice: AudioStreamPlayer
var step_age := 0.0
var grain_age := 0.0
var steps := 0
var bite_voice: AudioStreamPlayer
var bite_age:=1.0
var bites_played:=0
var effects_db:=0.0
var bus_name: StringName
var mute_when_unfocused := true
func install(mouse: Node2D) -> void:
	companion = mouse
	var preferences:=ConfigFile.new()
	preferences.load("user://experience-audio.cfg")
	var gain:=clampf(float(preferences.get_value("audio","master",0.7)),0.0,1.0)*clampf(float(preferences.get_value("audio","effects",0.7)),0.0,1.0)
	effects_db=-80.0 if bool(preferences.get_value("audio","mute",false)) or gain<=0.0 else linear_to_db(gain)
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
	bite_voice=AudioStreamPlayer.new()
	bite_voice.name="GnawPaperSound"
	bite_voice.stream=PAPER
	bite_voice.bus=bus_name
	bite_voice.volume_db=-72.0
	add_child(bite_voice)
	companion.gnaw_bite.connect(_on_bite)
	companion.gnaw_stopped.connect(_stop_bite)
func _process(delta: float) -> void:
	if not is_instance_valid(voice) or not is_instance_valid(companion): return
	_update_bite(delta)
	var speed: float = companion.velocity.length()/maxf(companion.unit,0.01)
	var walking: bool = companion.enabled and companion.state==companion.State.FOLLOW and speed>22.0 and not get_tree().paused and effects_db>-75.0
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
		voice.volume_db = -55.0+effects_db
		voice.play([0.025,0.16,0.29][steps%3])
	if voice.playing:
		grain_age += delta
		var target := -31.0-3.0*(1.0-clampf(speed/270.0,0.0,1.0))
		if grain_age > 0.095:
			voice.volume_db = move_toward(voice.volume_db,-72.0,delta*700.0)
			if voice.volume_db <= -65.0: voice.stop()
		else: voice.volume_db = move_toward(voice.volume_db,target+effects_db,delta*1500.0)
func _on_bite() -> void:
	if not companion.enabled or get_tree().paused or effects_db<=-75.0: return
	if mute_when_unfocused and not get_window().has_focus(): return
	bites_played+=1
	bite_age=0.0
	bite_voice.pitch_scale=[1.16,1.08,1.21,1.12][bites_played%4]
	bite_voice.volume_db=-48.0+effects_db
	var offset: float=[0.045,0.195,0.315,0.425][bites_played%4]
	bite_voice.play(minf(offset,maxf(0.0,PAPER.get_length()-0.16)))
func _stop_bite() -> void:
	bite_age=maxf(bite_age,0.105)
func _update_bite(delta: float) -> void:
	if not is_instance_valid(bite_voice) or not bite_voice.playing: return
	bite_age+=delta
	if not companion.enabled or companion.state!=companion.State.GNAW or mute_when_unfocused and not get_window().has_focus(): _stop_bite()
	var target: float=-21.0+effects_db if bite_age<0.10 else -72.0
	bite_voice.volume_db=move_toward(bite_voice.volume_db,target,delta*1500.0)
	if bite_age>=0.16 or bite_age>0.10 and bite_voice.volume_db<=-65.0: bite_voice.stop()
func _exit_tree() -> void:
	if is_instance_valid(voice): voice.stop()
	if is_instance_valid(bite_voice): bite_voice.stop()
	var index := AudioServer.get_bus_index(bus_name)
	if index>0: AudioServer.remove_bus(index)
