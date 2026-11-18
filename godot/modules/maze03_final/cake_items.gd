extends Node
## Maze03 only: the shared inventory and cake effects, with no rabbit/key spawns.
const Inventory := preload("res://modules/maze_items/maze_inventory.gd")
const CakeEffects := preload("res://modules/maze_pickups/maze01_perks.gd")
const PLACEMENTS := [
    {"route":"A", "point":Vector3(20.4,0.0,44.4)},
    {"route":"B", "point":Vector3(4.7,0.0,9.6)},
]
var inventory: Inventory
var effects: CakeEffects
func install(level: Control) -> void:
    name="Maze03CakeItems"
    inventory=Inventory.new()
    inventory.name="MazeInventory"
    level.add_child(inventory)
    inventory.hide()
    effects=CakeEffects.new()
    effects.name="Maze03CakeEffects"
    effects.enable_flour=false
    effects.cake_positions=PLACEMENTS.map(func(entry):return entry.point)
    level.add_child(effects)
    effects.install(level.get_node("%Player"),level.get_node("%ViewportContainer"),inventory,level.sound.play_item_pickup)
    _label_pickups()
func _label_pickups() -> void:
    for i in effects.pickups.size():
        var pickup=effects.pickups[i]
        pickup.name="Route"+PLACEMENTS[i].route+"ChocolateCake"
        pickup.set_meta("cake_route",PLACEMENTS[i].route)
func reset_items() -> void:
    inventory.clear_items()
    effects.reset()
    _label_pickups()
