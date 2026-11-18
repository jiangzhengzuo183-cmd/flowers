extends Node3D

const Marks := preload("res://modules/maze02_items/placements.gd")
const Capsule := preload("res://modules/maze02_items/capsule.tscn")
const Television := preload("res://modules/maze02_items/tv_interference.gd")
const Vision := preload("res://modules/maze02_items/vision.gd")
const Chime := preload("res://modules/maze_items/rabbit_pickup.wav")
const CAPSULE := &"PinkCapsule"
const CapsuleIcon := preload("res://assets/UI/HUD/slices/icon_capsule.png")
const SLOW_DURATION := 4.0
const SLOW_FACTOR := 0.45

@export_range(0.0, 1.0) var vision_chance := 0.8
var capsules: Array[Area3D] = []
var televisions: Array[Television] = []
var slow_remaining := 0.0
var vision: Vision
var _actor: CharacterBody3D
var _items: Node
var _perks: Node
var _gates: Dictionary
var _exits: Array[Area3D]
var _sound: Callable
var _sound_enabled: Callable
var _rng := RandomNumberGenerator.new()

func install(actor: CharacterBody3D, items: Node, perks: Node, gates: Dictionary, exits: Array[Area3D],
		viewport: Control, occlusion: Node, play_pickup_sound: Callable, sound_enabled: Callable, audio_root: Node) -> void:
	process_physics_priority = -10
	_rng.randomize()
	_actor = actor
	_items = items
	_items.inventory.register_item(CAPSULE, "粉色药丸", CapsuleIcon)
	_items.inventory.use_requested.connect(_use_item)
	_perks = perks
	_gates = gates
	_exits = exits
	_sound = play_pickup_sound
	_sound_enabled = sound_enabled
	var noise := Television.electronic_static()
	for entry: Dictionary in Marks.TELEVISIONS:
		var tv := Television.new()
		tv.name = "InterferenceTV%d" % (televisions.size() + 1)
		tv.position = entry.point
		tv.facing = entry.yaw
		tv.broadcast = entry.broadcast
		tv.noise = noise
		add_child(tv)
		televisions.append(tv)
	vision = Vision.new()
	vision.name = "CapsuleVision"
	add_child(vision)
	vision.install(viewport, occlusion, _mark_targets, _items.vision_route, audio_root, sound_enabled)
	reset()

func reset() -> void:
	slow_remaining = 0.0
	_actor.capsule_speed_factor = 1.0
	_actor.tv_reversed = false
	vision.clear()
	for tv: Television in televisions:
		tv.update_interference(null, false, 0.0)
	for pickup: Area3D in capsules:
		if is_instance_valid(pickup):
			# Leaving the tree also drops any overlap queued before reset.
			remove_child(pickup)
			pickup.queue_free()
	capsules.clear()
	for point: Vector3 in Marks.CAPSULES:
		var pickup := Capsule.instantiate() as Area3D
		pickup.name = "RandomCapsule%d" % (capsules.size() + 1)
		pickup.actor = _actor
		pickup.can_collect = _items.inventory.can_accept_pickup
		pickup.ground_display = true
		pickup.position = point
		pickup.collected.connect(_capsule_collected)
		add_child(pickup)
		capsules.append(pickup)

func _capsule_collected() -> void:
	_items.inventory.grant(CAPSULE)
	_sound.call(Chime)

func _use_item(id: StringName) -> void:
	if id != CAPSULE or not _actor.controls_enabled or get_tree().paused: return
	if not _items.inventory.consume(CAPSULE): return
	if _rng.randf() < vision_chance:
		vision.activate()
		_items.inventory.show_notice("随机胶囊 · 全局透视，持续 %d 秒" % int(Vision.DURATION))
	else:
		_sound.call(Chime)
		slow_remaining = SLOW_DURATION
		_actor.capsule_speed_factor = SLOW_FACTOR
		_items.inventory.show_notice("随机胶囊 · 移动减速，持续 4 秒")

func _physics_process(delta: float) -> void:
	if slow_remaining > 0.0:
		slow_remaining = maxf(0.0, slow_remaining - delta)
		if slow_remaining == 0.0:
			_actor.capsule_speed_factor = 1.0
	var reversed := false
	var audible: bool = _sound_enabled.call()
	for tv: Television in televisions:
		tv.update_interference(_actor, audible, delta)
		reversed = reversed or tv.active
	if reversed and not _actor.tv_reversed:
		_items.inventory.show_notice("电视干扰 · 移动方向反转")
	_actor.tv_reversed = reversed

func _mark_targets() -> Dictionary:
	var pickups: Array[Node3D] = []
	for pickup in _items.key_pickups.values() + _perks.pickups + capsules + [_items._pickup]:
		if is_instance_valid(pickup) and not pickup.claimed:
			pickups.append(pickup)
	return {"gates": _gates.values(), "pickups": pickups, "exits": _exits}
