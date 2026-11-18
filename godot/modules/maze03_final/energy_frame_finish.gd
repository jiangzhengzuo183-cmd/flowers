extends RefCounted
const F := preload("res://modules/maze03_final/architecture_forms.gd")
const G := preload("res://scripts/levels/greybox_geometry.gd")
static func install(frame: Node3D) -> ShaderMaterial:
	# Bevel the existing visible stones; their original collision boxes remain intact.
	for body: Node3D in frame.get_children():
		if not body is StaticBody3D:
			continue
		var visual := body.get_child(0) as MeshInstance3D
		if visual==null or not visual.mesh is BoxMesh:
			continue
		var st := F.surface()
		F.solid(st,Vector3.ZERO,visual.mesh.size,0.018)
		visual.mesh = st.commit()
	var socket := StandardMaterial3D.new()
	socket.albedo_color = Color("9fbbc9")
	socket.roughness = 0.82
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://modules/maze03_final/energy_socket.gdshader")
	var seats := Node3D.new()
	seats.name = "RecessedEnergySeat"
	frame.add_child(seats)
	for side in [-1.0,1.0]:
		G.box(seats,"InnerStoneRebate",Vector3(0.028,2.48,0.38),Vector3(side*0.931,1.24,0),socket,false)
		G.box(seats,"BlueInsetLiner",Vector3(0.014,2.44,0.18),Vector3(side*0.914,1.22,0),glow,false)
	G.box(seats,"UpperRebate",Vector3(1.86,0.08,0.38),Vector3(0,2.48,0),socket,false)
	G.box(seats,"UpperBlueLiner",Vector3(1.84,0.020,0.18),Vector3(0,2.437,0),glow,false)
	G.box(seats,"FlushGroundSeat",Vector3(1.86,0.012,0.16),Vector3(0,0.014,0),glow,false)
	return glow


