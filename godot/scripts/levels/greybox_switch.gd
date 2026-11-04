extends Node3D

const Geometry := preload("res://scripts/levels/greybox_geometry.gd")
@export var gate_id := "D1"
var used := false
var indicator: StandardMaterial3D
var state_label: Label3D

func _ready() -> void:
	indicator = Geometry.material(Color("c38a4f"))
	Geometry.box(self,"Housing",Vector3(0.28,0.32,0.28),Vector3.ZERO,Geometry.material(Geometry.WALL_GREY),false)
	Geometry.box(self,"Indicator",Vector3(0.18,0.12,0.32),Vector3(0,0.03,0),indicator,false)
	state_label = Geometry.label(self,gate_id.replace("D","S")+" → "+gate_id,Vector3(0,0.48,0),38)

func set_used(enabled: bool) -> void:
	used = enabled
	indicator.albedo_color = Color("50988b") if used else Color("c38a4f")
	state_label.text = gate_id.replace("D","S")+" · 已开启" if used else gate_id.replace("D","S")+" → "+gate_id
