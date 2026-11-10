extends RefCounted

const Book := preload("res://art/maze01/landmarks/chapel_book.glb")
const Plaster := preload("res://art/maze01/materials/plaster_cream.tres")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const HEIGHT := 1.24
const RADIAL_STEPS := 96

static func install(world: Node3D) -> void:
	var center: Array = Layout.config().building.circle.center
	var stand := StaticBody3D.new()
	stand.name = "ChapelBookStand"
	stand.position = Vector3(center[0], 0.025, center[1])
	world.add_child(stand)
	var limestone := Plaster.duplicate() as StandardMaterial3D
	limestone.albedo_color = Color("d8cbb8")
	limestone.normal_scale = 0.10
	var moulding := limestone.duplicate() as StandardMaterial3D
	moulding.albedo_color = Color("e9dbc5")
	var recess := limestone.duplicate() as StandardMaterial3D
	recess.albedo_color = Color("bcaa8d")

	# Bottom and top radii, then the start and end heights of each stone course.
	_course(stand, "Foundation", Vector4(0.41, 0.41, 0.0, 0.055), limestone)
	_course(stand, "FootBevel", Vector4(0.41, 0.38, 0.055, 0.079), moulding)
	_course(stand, "SteppedFoot", Vector4(0.38, 0.265, 0.079, 0.132), limestone)
	_course(stand, "BaseReveal", Vector4(0.265, 0.234, 0.132, 0.148), recess)
	_course(stand, "FootCollar", Vector4(0.234, 0.248, 0.148, 0.180), moulding)
	_course(stand, "FootShoulder", Vector4(0.248, 0.197, 0.180, 0.228), limestone)
	_fluted_shaft(stand, limestone)
	_course(stand, "NeckReveal", Vector4(0.160, 0.165, 0.980, 1.005), recess)
	_course(stand, "NeckCollar", Vector4(0.165, 0.205, 1.005, 1.039), moulding)
	_course(stand, "CapitalCove", Vector4(0.205, 0.230, 1.039, 1.090), limestone)
	_course(stand, "CapitalFlare", Vector4(0.230, 0.325, 1.090, 1.156), moulding)
	_course(stand, "RimReveal", Vector4(0.325, 0.326, 1.156, 1.173), recess)
	_course(stand, "ReadingRim", Vector4(0.326, 0.371, 1.173, 1.210), moulding)
	_course(stand, "ReadingSurface", Vector4(0.371, 0.365, 1.210, HEIGHT), limestone)

	var blocker := CollisionShape3D.new()
	blocker.name = "StandCollision"
	var shape := CylinderShape3D.new()
	shape.radius = 0.41
	shape.height = HEIGHT
	blocker.shape = shape
	blocker.position.y = shape.height * 0.5
	stand.add_child(blocker)
	var book := Book.instantiate() as Node3D
	book.name = "ChapelBook"
	book.position.y = HEIGHT + 0.001
	book.scale = Vector3.ONE * 0.0082
	stand.add_child(book)

static func _course(stand: Node3D, id: String, profile: Vector4, material: Material) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = profile.x
	cylinder.top_radius = profile.y
	cylinder.height = profile.w - profile.z
	cylinder.radial_segments = RADIAL_STEPS
	cylinder.rings = 0
	cylinder.cap_bottom = false
	cylinder.cap_top = id == "ReadingSurface"
	var piece := MeshInstance3D.new()
	piece.name = id
	piece.mesh = cylinder
	piece.material_override = material
	piece.position.y = (profile.z + profile.w) * 0.5
	stand.add_child(piece)

static func _fluted_shaft(stand: Node3D, material: Material) -> void:
	const RINGS := 24
	const FLUTES := 12
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(RINGS + 1):
		var along := float(ring) / RINGS
		var profile := lerpf(0.197, 0.160, along) + sin(along * PI) * 0.012
		var carved := smoothstep(0.0, 0.10, along) * (1.0 - smoothstep(0.90, 1.0, along))
		for step in RADIAL_STEPS:
			var fraction := float(step) / RADIAL_STEPS
			var angle := TAU * fraction
			var groove := 0.009 * (1.0 - cos(angle * FLUTES)) * carved
			var radius := profile - groove
			surface.add_vertex(Vector3(cos(angle) * radius, lerpf(0.228, 0.980, along), sin(angle) * radius))
	for ring in RINGS:
		for step in RADIAL_STEPS:
			var a := ring * RADIAL_STEPS + step
			var b := ring * RADIAL_STEPS + (step + 1) % RADIAL_STEPS
			for index: int in [a, b, b + RADIAL_STEPS, a, b + RADIAL_STEPS, a + RADIAL_STEPS]:
				surface.add_index(index)
	surface.generate_normals()
	var shaft := MeshInstance3D.new()
	shaft.name = "FlutedShaft"
	shaft.mesh = surface.commit()
	shaft.material_override = material
	stand.add_child(shaft)
