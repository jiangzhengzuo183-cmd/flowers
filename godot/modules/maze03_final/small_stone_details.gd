extends RefCounted
const F := preload("res://modules/maze03_final/architecture_forms.gd")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
static func apply(generator: Node3D) -> void:
	var sanctuary: Node3D = generator.sanctuary
	# Reuse the existing step/coping solids, leaving all original collider extents intact.
	var solids: Array[Node3D] = []
	solids.append_array(sanctuary.pads)
	for body in sanctuary.get_children():
		if not body is Node3D:
			continue
		if str(body.name).begins_with("PoolCoping") or str(body.name)=="SanctuaryFoundation":
			solids.append(body)
	for body in solids:
		var mesh := body.get_child(0) as MeshInstance3D
		if mesh==null or not mesh.mesh is BoxMesh:
			continue
		var st := F.surface()
		F.solid(st,Vector3.ZERO,mesh.mesh.size,0.014)
		mesh.mesh = st.commit()
	var details := Node3D.new()
	details.name = "QuietStoneEdgeDetails"
	generator.architecture.add_child(details)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("e9e9e5")
	paint.roughness = 0.92
	var rng := RandomNumberGenerator.new()
	rng.seed = 31717
	for point: Vector2 in [Vector2(10.0,12.15),Vector2(40.0,33.90),Vector2(11.55,35.6)]:
		var st := F.surface()
		var floor := Layout.height_at(point)
		for i in 4:
			var p := Vector3(point.x+rng.randf_range(-0.22,0.22),floor+0.025,point.y+rng.randf_range(-0.13,0.13))
			F.solid(st,p,Vector3(rng.randf_range(0.05,0.13),0.045,rng.randf_range(0.04,0.10)),0.012,0.74)
		F.finish(details,"SmallStoneFragmentCluster",st,paint,false)

