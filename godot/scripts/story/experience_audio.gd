extends Node
## Persists across story scenes; only preferences are saved, never rehearsal progress.
var options := {"master":0.7,"music":0.35,"effects":0.7,"mute":false}
var players: Array[AudioStreamPlayer] = []
var current := -1
var group := ""
var requested := "bakery"
var armed := false
var fade: Tween
var silent_actions := false
var footsteps: AudioStreamPlayer
var step_timer := 0.0
var step_age := -1.0
var last_action := ""
var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/experience.json"))

func _ready() -> void:
	var preferences:=ConfigFile.new()
	if preferences.load("user://experience-audio.cfg")==OK:
		for key:String in options: options[key]=preferences.get_value("audio",key,options[key])
	for i in range(2):
		var p:=AudioStreamPlayer.new()
		p.volume_db=-80
		add_child(p)
		players.append(p)
	footsteps=AudioStreamPlayer.new()
	add_child(footsteps)

func arm() -> void:
	if armed:return
	armed=true
	group=""
	choose(requested)

func set_option(key:String,value:Variant) -> void:
	options[key]=value
	var preferences:=ConfigFile.new()
	for id:String in options:preferences.set_value("audio",id,options[id])
	preferences.save("user://experience-audio.cfg")
	var desired:=requested
	group=""
	choose(desired)

func gain() -> float:
	return -80.0 if options.mute else linear_to_db(maxf(0.0001,options.master*options.music))

func choose(id:String) -> void:
	requested=id
	if DisplayServer.get_name()=="headless": return
	if not armed or players.is_empty():return
	if id==group:return
	group=id
	var file:String={"bakery":"bakery.ogg","night":"night.mp3","lab":"lab-calm.mp3","hospital":"night.mp3"}.get(id,"bakery.ogg")
	var path:="res://assets/audio/"+file
	if not ResourceLoader.exists(path):return
	# Same recording across adjoining scenes only updates volume, never restarts.
	if current>=0 and players[current].stream!=null and players[current].stream.resource_path==path:
		players[current].volume_db=gain()
		return
	if fade:fade.kill()
	var old:=current
	current=(current+1)%2
	players[current].stream=load(path)
	if players[current].stream is AudioStreamWAV:
		players[current].stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		players[current].stream.loop_end=int(players[current].stream.get_length()*players[current].stream.mix_rate)
	else: players[current].stream.loop=true
	players[current].volume_db=-80
	players[current].play()
	fade=create_tween().set_parallel(true)
	fade.tween_property(players[current],"volume_db",gain(),float(tuning.music_fade_seconds))
	if old>=0:
		fade.tween_property(players[old],"volume_db",-80,float(tuning.music_fade_seconds))
		fade.chain().tween_callback(players[old].stop)

func effect(file:String,db:float=-10) -> void:
	if DisplayServer.get_name()=="headless": return
	if not armed or silent_actions or options.mute:return
	var path:="res://assets/audio/"+file
	if not ResourceLoader.exists(path):return
	var player:=AudioStreamPlayer.new()
	player.stream=load(path)
	player.volume_db=db+linear_to_db(maxf(0.0001,options.master*options.effects))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func action_for(scene:String,text:String) -> void:
	var key:=scene+text
	if key==last_action:return
	last_action=key
	if scene=="leaving" and "离开面包店" in text:
		step_age=0
		step_timer=0
		effect("door.wav")
	elif "递给" in text or "翻着" in text:effect("paper.mp3",-16)

func _process(dt:float) -> void:
	if step_age<0 or not armed:return
	step_age+=dt
	step_timer-=dt
	if step_age>5:step_age=-1;return
	if step_timer<=0:
		step_timer=0.48
		effect("step.ogg",-8-step_age*6)

func _exit_tree() -> void:
	if fade:fade.kill()
	for child:Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream=null
