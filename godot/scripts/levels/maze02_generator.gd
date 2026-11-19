extends "res://scripts/levels/greybox_generator.gd"
## Local structural changes are in place before collision-aware systems initialize.

const Ruins := preload("res://art/maze02/ruins/maze02_ruins.gd")

func build(original: Dictionary) -> void:
	super(original)
	Ruins.apply(self)
