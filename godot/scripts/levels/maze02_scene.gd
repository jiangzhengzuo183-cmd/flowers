extends "res://scripts/levels/greybox_scene.gd"
## Maze02 owns its environment resources; gameplay remains in the shared scene script.

@export var maze02_lighting: Resource

func _ready() -> void:
	super()
	if loaded_ok and dream_art_enabled:
		maze02_lighting.apply(%Player.get_parent())
