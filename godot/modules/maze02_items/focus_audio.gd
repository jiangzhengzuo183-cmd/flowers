extends Node
## A scene-owned mix keeps the focus sounds clear while its environment recedes.

const Gather := preload("res://modules/maze02_items/assets/focus_gather.wav")
const Hold := preload("res://modules/maze02_items/assets/focus_hold.wav")
const DUCK_DB := -11.0
const SILENT_DB := -70.0

var _intro: AudioStreamPlayer
var _hold: AudioStreamPlayer
var _enabled: Callable
var _buses: Dictionary = {}
var _routes: Array[Dictionary] = []

func install(scene_root: Node, sound_enabled: Callable) -> void:
	_enabled = sound_enabled
	var players := scene_root.find_children("*", "AudioStreamPlayer", true, false) \
		+ scene_root.find_children("*", "AudioStreamPlayer3D", true, false)
	for player: Node in players:
		if player.name == &"PickupCue":
			continue
		var original: StringName = player.bus
		if not _buses.has(original):
			var id := AudioServer.bus_count
			var bus := StringName("Maze02Focus_%d_%d" % [get_instance_id(), id])
			AudioServer.add_bus()
			AudioServer.set_bus_name(id, bus)
			AudioServer.set_bus_send(id, original)
			_buses[original] = bus
		_routes.append({"player": player, "bus": original})
		player.bus = _buses[original]
	_intro = AudioStreamPlayer.new()
	_intro.name = "FocusGather"
	_intro.stream = Gather
	_intro.volume_db = -7.0
	add_child(_intro)
	_hold = AudioStreamPlayer.new()
	_hold.name = "FocusHold"
	var loop := Hold.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	_hold.stream = loop
	_hold.volume_db = SILENT_DB
	add_child(_hold)

func start() -> void:
	if _enabled.call():
		_intro.play()

func set_strength(strength: float) -> void:
	for bus: StringName in _buses.values():
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, DUCK_DB * strength)
	if not _enabled.call():
		_intro.stop()
		_hold.stop()
		return
	if strength <= 0.0:
		_hold.stop()
		return
	_hold.volume_db = maxf(SILENT_DB, -18.0 + linear_to_db(strength))
	if not _hold.playing:
		_hold.play()

func stop() -> void:
	set_strength(0.0)
	_intro.stop()
	_hold.stop()

func _exit_tree() -> void:
	for route: Dictionary in _routes:
		if is_instance_valid(route.player) and route.player.bus == _buses[route.bus]:
			route.player.bus = route.bus
	for bus: StringName in _buses.values():
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.remove_bus(index)
