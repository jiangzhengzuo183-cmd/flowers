extends RefCounted
## Scene-local contact shading baked from the actual retained wall footprints.
const SIZE := 384
const MAP_ORIGIN := -0.7
const MAP_SPAN := 47.0
static func apply(generator: Node3D) -> void:
	var image := Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for group_name: String in ["VerticalWalls","HorizontalWalls"]:
		for body: Node3D in generator.get_node(group_name).get_children():
			var visuals := body.find_children("*","MeshInstance3D",true,false)
			if visuals.is_empty():
				continue
			var visual: MeshInstance3D = visuals[0]
			var bounds := visual.get_aabb()
			var a: Vector3 = visual.global_transform*bounds.position
			var b: Vector3 = visual.global_transform*bounds.end
			var rect := Rect2(Vector2(minf(a.x,b.x),minf(a.z,b.z)),Vector2(absf(a.x-b.x),absf(a.z-b.z)))
			_stamp(image,rect)
	_stamp_curved_bases(image,generator)
	var contact := ImageTexture.create_from_image(image)
	var base := ShaderMaterial.new()
	base.shader = preload("res://modules/maze03_final/floor_finish.gdshader")
	base.set_shader_parameter("floor_color",Color("b8bfc4"))
	base.set_shader_parameter("wall_contact",contact)
	base.set_shader_parameter("grain",load("res://art/maze01/materials/limestone/limestone_normal.png"))
	base.set_shader_parameter("stone_roughness",load("res://art/maze01/materials/limestone/limestone_roughness.png"))
	for visual: MeshInstance3D in generator.find_children("*","MeshInstance3D",true,false):
		var role := str(visual.get_meta("art_role",""))
		var part := str(visual.get_meta("greybox_part",""))
		var is_floor := role.contains("floor") or role.contains("bridge") or part=="FinishedStoneFloor" or visual.name=="UndulatingStoneTerraces"
		if not is_floor:
			continue
		var material := base.duplicate() as ShaderMaterial
		var original: Material = visual.material_override
		var legacy: bool = original is ShaderMaterial and original.get_shader_parameter("legacy_winding")==true
		material.set_shader_parameter("legacy_winding",legacy)
		visual.material_override = material

static func _stamp(image: Image, rect: Rect2) -> void:
	var area := rect.grow(0.48)
	var low := Vector2i((area.position-Vector2.ONE*MAP_ORIGIN)/MAP_SPAN*SIZE)
	var high := Vector2i((area.end-Vector2.ONE*MAP_ORIGIN)/MAP_SPAN*SIZE)
	for y in range(maxi(0,low.y),mini(SIZE,high.y+1)):
		for x in range(maxi(0,low.x),mini(SIZE,high.x+1)):
			var point := Vector2(x+0.5,y+0.5)/SIZE*MAP_SPAN+Vector2.ONE*MAP_ORIGIN
			var nearest := Vector2(clampf(point.x,rect.position.x,rect.end.x),clampf(point.y,rect.position.y,rect.end.y))
			var distance := point.distance_to(nearest)
			var shade := 1.0-0.11*exp(-distance*distance/0.038)
			var old := image.get_pixel(x,y).r
			image.set_pixel(x,y,Color(minf(old,shade),minf(old,shade),minf(old,shade),1))

static func _stamp_curved_bases(image: Image,generator: Node3D) -> void:
	var court: Node3D = generator.architecture.get_node("NorthwestCourtyard/LayeredRibbonCourt")
	var used: Dictionary = {}
	for body: Node3D in court.get_children():
		if not str(body.name).ends_with("Arc"):
			continue
		var visual := body.get_child(0) as MeshInstance3D
		var vertices: PackedVector3Array = visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for p in vertices:
			if p.y>0.05:
				continue
			var world := visual.to_global(p)
			var cell := Vector2i(roundi(world.x*12.0),roundi(world.z*12.0))
			if used.has(cell):
				continue
			used[cell] = true
			_stamp(image,Rect2(Vector2(world.x,world.z)-Vector2.ONE*0.06,Vector2.ONE*0.12))

