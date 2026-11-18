extends Node3D
## Maze02-only composition. Does not own the player, navigation graph or original art.

const CHURCH_OFFSET := Vector3(1.40, -0.025, 0.65)
const BRIDGE_POSITION := Vector3(39.75, 0.0, 15.65)
const ATLAS_STOP_OFFSET := Vector3(0.80, 0.0, 1.15)

@onready var church: CharacterBody3D = $Ghost_Church
@onready var bridge: CharacterBody3D = $Ghost_BridgeUnderpass
var _installed := false
var _arrival_wait := -1.0

func install(actor: CharacterBody3D, generator: Node3D, routes: RefCounted) -> void:
	if _installed:
		return
	_installed = true
	var statue: Node3D = generator.get_node("EarthBearer")
	var book: Node3D = actor.get_parent().get_node("ChapelBookStand")
	church.global_position = book.global_position + CHURCH_OFFSET
	church.rotation.y = -2.5
	bridge.global_position = BRIDGE_POSITION
	bridge.rotation.y = -PI / 2.0
	var destination := statue.global_position + ATLAS_STOP_OFFSET
	church.configure(actor, routes, destination, statue.global_position)
	bridge.configure(actor, routes, Vector3.ZERO, Vector3.ZERO)
	church.guidance_finished.connect(_arrived)
	process_mode = Node.PROCESS_MODE_INHERIT
	show()

func _arrived(_ghost: Node3D) -> void:
	_arrival_wait = 1.0

func _process(delta: float) -> void:
	if _arrival_wait < 0.0:
		return
	_arrival_wait = maxf(0.0, _arrival_wait - delta)
	if _arrival_wait == 0.0:
		_arrival_wait = -1.0
		church.begin_wind_dissolve()

func reset_event() -> void:
	if not _installed:
		return
	church.reset_event()
	bridge.reset_event()
	_arrival_wait = -1.0
