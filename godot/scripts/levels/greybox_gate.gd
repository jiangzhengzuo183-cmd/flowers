extends Node3D

signal opened
signal descent_started
signal state_applied(is_open: bool)
const Geometry := preload("res://scripts/levels/greybox_geometry.gd")
const PANEL_HEIGHT := 2.49
const OPEN_Y := -2.53
const OPEN_DURATION := 0.65
@export var gate_id := "D1"
var opening_lead_time := 0.0
var descent_duration := OPEN_DURATION
var legacy_chime_enabled := true
var is_open := false
var leaf: StaticBody3D
var panel: MeshInstance3D
var _collision: CollisionShape3D
var tween: Tween
var state_label: Label3D

func _ready() -> void:
	var stone := Geometry.material(Geometry.WALL_GREY)
	Geometry.box(self,"LeftPier",Vector3(0.3,2.8,0.38),Vector3(-1.05,1.4,0),stone)
	Geometry.box(self,"RightPier",Vector3(0.3,2.8,0.38),Vector3(1.05,1.4,0),stone)
	Geometry.box(self,"Lintel",Vector3(2.4,0.3,0.38),Vector3(0,2.65,0),stone)
	leaf = StaticBody3D.new()
	leaf.name = "MovingGate"
	add_child(leaf)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.82,2.35,0.2)
	_collision = CollisionShape3D.new()
	_collision.name = "GateCollision"
	_collision.shape = shape
	_collision.position.y = 1.175
	leaf.add_child(_collision)
	var slab := Geometry.box(leaf,"GatePanel",Vector3(1.80,PANEL_HEIGHT,0.16),Vector3(0,PANEL_HEIGHT*0.5,0),stone,false)
	panel = slab.get_child(0)
	state_label = Geometry.label(self,gate_id+" · 关闭",Vector3(0,3.05,0))

func open_gate() -> void:
	if is_open:
		return
	is_open = true
	state_label.text = gate_id+" · 开启"
	if legacy_chime_enabled:
		Geometry.chime(self)
	tween = create_tween()
	if opening_lead_time > 0.0:
		tween.tween_interval(opening_lead_time)
	tween.tween_callback(descent_started.emit)
	tween.tween_method(_position_leaf,0.0,OPEN_Y,descent_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_collision.set_deferred.bind("disabled",true))
	opened.emit()

func reset_gate() -> void:
	set_open_state(false)

## Apply initial/reset state immediately, with no animation, sound or opened event.
func set_open_state(open: bool) -> void:
	if is_instance_valid(tween):
		tween.kill()
	is_open = open
	_position_leaf(OPEN_Y if open else 0.0)
	_collision.set_deferred("disabled",open)
	state_label.text = gate_id+(" · 开启" if open else " · 关闭")
	state_applied.emit(open)

func _position_leaf(offset: float) -> void:
	leaf.position.y = offset
	# Preserve the blocking volume until the whole panel clears the threshold.
	_collision.position.y = 1.175 - offset
	var above_floor := maxf(0.0, PANEL_HEIGHT + offset)
	panel.visible = above_floor > 0.001
	panel.position.y = -offset * 0.5
	panel.scale.y = maxf(0.001, above_floor / PANEL_HEIGHT)
