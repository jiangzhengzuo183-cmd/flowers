extends RefCounted
## A collision-matched shallow barrel vault; upper and lower routes stay separate.
const Geometry := preload("res://scripts/levels/greybox_geometry.gd")

static func build(parent: Node3D,spec: Dictionary) -> void:
	var vault := Node3D.new()
	vault.name = "ArchedUnderpass"
	parent.add_child(vault)
	var stone := Geometry.material(Geometry.WALL_GREY)
	for z in [14.9,16.9]:
		Geometry.box(vault,"TunnelEnd",Vector3(2.4,2.4,0.18),Vector3(39.6,1.2,z),stone)
	var count := int(spec.segments)
	for step in count:
		var a := PI*step/count
		var b := PI*(step+1)/count
		var p := Vector2(float(spec.z_center)+cos(a)*float(spec.half_width),float(spec.spring)+sin(a)*(float(spec.crown)-float(spec.spring)))
		var q := Vector2(float(spec.z_center)+cos(b)*float(spec.half_width),float(spec.spring)+sin(b)*(float(spec.crown)-float(spec.spring)))
		# The crown touches the old soffit at a single vertex; clean the triangle there.
		var poly := PackedVector2Array([p,q])
		if q.y<float(spec.crown)-0.00001:
			poly.append(Vector2(q.x,spec.crown))
		if p.y<float(spec.crown)-0.00001:
			poly.append(Vector2(p.x,spec.crown))
		Geometry.extruded_section(vault,"VaultStone%d"%step,poly,spec.x[0],spec.x[1],stone)
		# Front and back arch faces sit outside the bridge slab, avoiding overlays.
		for x: float in [float(spec.x[0])-0.15,float(spec.x[1])]:
			var face := PackedVector2Array([p,q,Vector2(q.x,2.6),Vector2(p.x,2.6)])
			Geometry.extruded_section(vault,"ArchFace%d"%step,face,x,x+0.15,stone)
