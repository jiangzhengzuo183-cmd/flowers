extends Node
## Menu-owned loop; the scene transition releases it before story audio starts.
const THEME:=preload("res://modules/visual_novel/assets/audio/bakery.ogg")
var music: AudioStreamPlayer
var target_db:=-20.0
var fade: Tween
var armed:=false
var ducked:=false
var startup_frames:=3
func _ready() -> void:
	var config:=ConfigFile.new()
	config.load("user://experience-audio.cfg")
	var master:=clampf(float(config.get_value("audio","master",0.7)),0.0,1.0)
	var volume:=clampf(float(config.get_value("audio","music",0.35)),0.0,1.0)
	var muted:=bool(config.get_value("audio","mute",false))
	target_db=-80.0 if muted or master*volume<=0.0 else -7.0+linear_to_db(master*volume)
	music=AudioStreamPlayer.new()
	music.name="MenuMusic"
	music.stream=THEME.duplicate()
	music.stream.loop=true
	music.volume_db=-80.0
	add_child(music)
	set_process(not OS.has_feature("web"))
func _process(_delta: float) -> void:
	startup_frames-=1
	if startup_frames<=0:
		set_process(false)
		arm()
func arm() -> void:
	if armed: return
	armed=true
	music.play()
	_level(target_db,1.4)
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed or event is InputEventKey and event.pressed: arm()
func duck(value: bool) -> void:
	ducked=value
	if armed: _level(target_db-(5.0 if value else 0.0),0.25)
func fade_out(seconds: float) -> void:
	if armed: _level(-80.0,seconds)
func _level(db: float,seconds: float) -> void:
	if fade and fade.is_valid(): fade.kill()
	fade=create_tween()
	fade.tween_property(music,"volume_db",db,seconds).set_trans(Tween.TRANS_SINE)
func _exit_tree() -> void:
	if fade and fade.is_valid(): fade.kill()
	if is_instance_valid(music):
		music.stop()
		music.stream=null
