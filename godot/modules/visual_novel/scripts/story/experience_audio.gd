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
var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://modules/visual_novel/data/experience.json"))

# Story audio belongs to visible story hosts, never to a running maze.
const MAZE_SCENES := ["res://scenes/maze.tscn", "res://scenes/levels/maze_01_greybox.tscn", "res://scenes/levels/Maze02.tscn", "res://scenes/levels/Maze03.tscn"]
var _story_hosts: Dictionary = {}
var _maze_hosts: Dictionary = {}
var _context_paused := true

const STORY_BUS := &"VisualNovelAudio"

func _story_bus() -> int:
	var index := AudioServer.get_bus_index(STORY_BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, STORY_BUS)
		AudioServer.set_bus_send(index, &"Master")
	return index

func route_story_player(player: AudioStreamPlayer) -> void:
	# Embedded mazes live below the chapter too; their sounds keep their own buses.
	for reference: WeakRef in _maze_hosts.values():
		var maze = reference.get_ref()
		if is_instance_valid(maze) and maze.is_ancestor_of(player): return
	var index := _story_bus()
	player.bus = STORY_BUS
	AudioServer.set_bus_mute(index, _context_paused)

func _watch_story_player(node: Node) -> void:
	if not node is AudioStreamPlayer: return
	for reference: WeakRef in _story_hosts.values():
		var host = reference.get_ref()
		if is_instance_valid(host) and host.is_ancestor_of(node):
			route_story_player(node)
			return

func register_story(host: Control) -> void:
	var id := host.get_instance_id()
	if _story_hosts.has(id): return
	_story_hosts[id] = weakref(host)
	for player: AudioStreamPlayer in host.find_children("*", "AudioStreamPlayer", true, false):
		route_story_player(player)
	host.visibility_changed.connect(_sync_context)
	host.tree_exiting.connect(_story_left.bind(id), CONNECT_ONE_SHOT)
	_sync_context()

func _story_left(id: int) -> void:
	_story_hosts.erase(id)
	_sync_context()

func _watch_maze(node: Node) -> void:
	if node.scene_file_path not in MAZE_SCENES: return
	register_maze(node)

func register_maze(node: Node) -> void:
	var id := node.get_instance_id()
	if _maze_hosts.has(id): return
	_maze_hosts[id] = weakref(node)
	node.tree_exiting.connect(_maze_left.bind(id), CONNECT_ONE_SHOT)
	_sync_context()

func _maze_left(id: int) -> void:
	_maze_hosts.erase(id)
	_sync_context()

func _sync_context() -> void:
	var visible_story := false
	for id: int in _story_hosts.keys():
		var host = _story_hosts[id].get_ref()
		if not is_instance_valid(host):
			_story_hosts.erase(id)
		elif host.is_inside_tree() and host.is_visible_in_tree():
			visible_story = true
	for id: int in _maze_hosts.keys():
		if not is_instance_valid(_maze_hosts[id].get_ref()): _maze_hosts.erase(id)
	var blocked := not visible_story or not _maze_hosts.is_empty()
	# Isolate every story source, including chapter ambience outside this node.
	AudioServer.set_bus_mute(_story_bus(), blocked)
	if blocked == _context_paused: return
	_context_paused = blocked
	if fade: fade.kill()
	if blocked:
		for i in range(players.size()):
			if i == current: players[i].stream_paused = true
			else: players[i].stop()
		for child: Node in get_children():
			if child is AudioStreamPlayer and child not in players: child.stop()
	else:
		if current >= 0:
			players[current].stream_paused = false
			players[current].volume_db = gain()
		group = ""
		choose(requested)

func _ready() -> void:
	var preferences:=ConfigFile.new()
	if preferences.load("user://experience-audio.cfg")==OK:
		for key:String in options: options[key]=preferences.get_value("audio",key,options[key])
	for i in range(2):
		var p:=AudioStreamPlayer.new()
		route_story_player(p)
		p.volume_db=-80
		add_child(p)
		players.append(p)
	footsteps=AudioStreamPlayer.new()
	route_story_player(footsteps)
	add_child(footsteps)
	get_tree().node_added.connect(_watch_maze)
	get_tree().node_added.connect(_watch_story_player)
	# Runtime registers the host before this root-owned manager is added.
	# Catch ambience created during the rest of that host's _ready().
	for reference: WeakRef in _story_hosts.values():
		var host = reference.get_ref()
		if is_instance_valid(host):
			for player: AudioStreamPlayer in host.find_children("*", "AudioStreamPlayer", true, false):
				route_story_player(player)
	_sync_context()

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
	if _context_paused: return
	if DisplayServer.get_name()=="headless": return
	if not armed or players.is_empty():return
	# The chapter can exit after this manager's player children have detached.
	if not is_inside_tree() or not players[0].is_inside_tree(): return
	if id==group:return
	group=id
	var file:String={"bakery":"bakery.ogg","night":"night.mp3","lab":"lab-calm.mp3","hospital":"night.mp3"}.get(id,"bakery.ogg")
	var path:="res://modules/visual_novel/assets/audio/"+file
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
	if _context_paused or not armed or silent_actions or options.mute:return
	var path:="res://modules/visual_novel/assets/audio/"+file
	if not ResourceLoader.exists(path):return
	var player:=AudioStreamPlayer.new()
	route_story_player(player)
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
	_sync_context()
	if _context_paused: return
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

func pause_story(value: bool) -> void:
	for player in players: player.stream_paused=value or _context_paused
	if is_instance_valid(footsteps): footsteps.stream_paused=value or _context_paused
