extends RefCounted
## Preferences only; never stores or mutates narrative progress.
signal changed(key: String, value: Variant)
const PATH := "user://vn-settings.cfg"
const DEFAULTS := {"master":0.7,"music":0.35,"effects":0.7,"mute":false,"fullscreen":false,"aspect":0,"text_speed":1}
const MUSIC_BUS := "VNMusic"
const EFFECTS_BUS := "VNEffects"
static var instance: RefCounted
var values: Dictionary = DEFAULTS.duplicate()
var save_error := OK

static func shared() -> RefCounted:
	if instance == null: instance = load("res://scripts/story/story_preferences.gd").new()
	return instance

func _init() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key: String in DEFAULTS: values[key] = _validated(key,config.get_value("preferences",key,DEFAULTS[key]))
	else:
		var legacy := ConfigFile.new()
		if legacy.load("user://experience-audio.cfg") == OK:
			for key: String in ["master","music","effects","mute"]:
				values[key] = _validated(key,legacy.get_value("audio",key,DEFAULTS[key]))
	apply_audio()

func _validated(key: String, value: Variant) -> Variant:
	if key in ["master","music","effects"]:
		return clampf(float(value),0.0,1.0) if value is float or value is int else DEFAULTS[key]
	if key in ["aspect","text_speed"]: return clampi(int(value),0,2) if value is int else DEFAULTS[key]
	return value if value is bool else DEFAULTS[key]

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key): return
	values[key] = _validated(key,value)
	apply_audio()
	_save()
	changed.emit(key,values[key])

func reset() -> void:
	values.assign(DEFAULTS)
	apply_audio()
	_save()
	for key: String in DEFAULTS: changed.emit(key,values[key])

func _save() -> void:
	var config := ConfigFile.new()
	for key: String in values: config.set_value("preferences",key,values[key])
	save_error = config.save(PATH)

func apply_audio() -> void:
	for bus: String in [MUSIC_BUS,EFFECTS_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count-1
			AudioServer.set_bus_name(index,bus)
			AudioServer.set_bus_send(index,"Master")
	for entry: Array in [["Master","master"],[MUSIC_BUS,"music"],[EFFECTS_BUS,"effects"]]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(entry[0]),linear_to_db(maxf(float(values[entry[1]]),0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),values.mute or float(values.master) <= 0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS),float(values.music) <= 0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(EFFECTS_BUS),float(values.effects) <= 0)

func apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func text_rate() -> float:
	return [0.55,1.0,1.65][values.text_speed]
