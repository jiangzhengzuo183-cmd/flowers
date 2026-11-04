extends Node3D

signal opened
const Geometry := preload("res://scripts/levels/greybox_geometry.gd")
@export var gate_id := "D1"
var is_open := false
var leaf: StaticBody3D
var tween: Tween
var state_label: Label3D

func _ready() -> void:
	var stone := Geometry.material(Geometry.WALL_GREY)
	var iron := stone
	Geometry.box(self,"LeftPier",Vector3(0.3,2.8,0.38),Vector3(-1.05,1.4,0),stone)
	Geometry.box(self,"RightPier",Vector3(0.3,2.8,0.38),Vector3(1.05,1.4,0),stone)
	Geometry.box(self,"Lintel",Vector3(2.4,0.3,0.38),Vector3(0,2.65,0),stone)
	leaf = StaticBody3D.new()
	leaf.name = "MovingGate"
	add_child(leaf)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.82,2.35,0.2)
	var collision := CollisionShape3D.new()
	collision.name = "GateCollision"
	collision.shape = shape
	collision.position.y = 1.175
	leaf.add_child(collision)
	for i in 7:
		Geometry.box(leaf,"Bar%d"%i,Vector3(0.10,2.35,0.16),Vector3(-0.78+i*0.26,1.175,0),iron,false)
	for y in [0.18,1.2,2.2]:
		Geometry.box(leaf,"Crossbar",Vector3(1.82,0.12,0.18),Vector3(0,y,0),iron,false)
	state_label = Geometry.label(self,gate_id+" · 关闭",Vector3(0,3.05,0))

func open_gate() -> void:
	if is_open:
		return
	is_open = true
	state_label.text = gate_id+" · 开启"
	Geometry.chime(self)
	tween = create_tween()
	tween.tween_property(leaf,"position:y",2.85,0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): leaf.get_node("GateCollision").set_deferred("disabled",true))
	opened.emit()

func reset_gate() -> void:
	if is_instance_valid(tween):
		tween.kill()
	is_open = false
	leaf.position.y = 0
	leaf.get_node("GateCollision").set_deferred("disabled",false)
	state_label.text = gate_id+" · 关闭"
