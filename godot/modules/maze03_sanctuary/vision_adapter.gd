extends "res://modules/maze02_items/vision.gd"
## Use the original capsule compositor, shaders, route motes, fade and sound unchanged.
var character_cue: Node3D
var opponent_cue: Node3D
func add_character(actor: CharacterBody3D) -> void:
 character_cue=preload("res://modules/maze03_sanctuary/character_cue.gd").new()
 _cue_pass.add_child(character_cue)
 character_cue.install(actor,_silhouette)
func add_opponent(actor: CharacterBody3D) -> void:
 opponent_cue=preload("res://modules/maze03_sanctuary/character_cue.gd").new()
 _cue_pass.add_child(opponent_cue)
 opponent_cue.install(actor,_silhouette)
 opponent_cue.name="AlgernonVisionSilhouette"
func activate_for(seconds: float) -> void:
 super.activate()
 remaining=minf(seconds,6.0)
func advance(delta: float, time_left: float) -> void:
 # Sanctuary owns the deadline in physics time; the original fade still uses remaining seconds.
 remaining=minf(remaining,time_left+delta)
 super._process(delta)
func _process(_delta: float) -> void:
 if remaining>0.0:
  _sync_camera()
  if is_instance_valid(character_cue):character_cue.sync_pose()
  if is_instance_valid(opponent_cue):opponent_cue.sync_pose()
func dispose() -> void:
 clear()
 if is_instance_valid(_screen):
  _screen.hide()
  _screen.queue_free()
 queue_free()
