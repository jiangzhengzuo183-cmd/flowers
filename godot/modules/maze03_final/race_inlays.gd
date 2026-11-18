extends Node3D
## Four short architectural insets, not a continuous route-to-exit navigation line.
var actor: CharacterBody3D
var paint: ShaderMaterial
var strip_count := 0
func install(generator: Node3D,player: CharacterBody3D) -> void:
	actor = player
	name = "ShortCorridorEnergyInsets"
	generator.architecture.add_child(self)
	paint = ShaderMaterial.new()
	paint.shader = preload("res://modules/maze03_final/race_inlay.gdshader")
	var used: Array[Node3D] = []
	var candidates: Array[Node3D] = []
	for group_name in ["VerticalWalls","HorizontalWalls"]:
		for wall: Node3D in generator.get_node(group_name).get_children():
			candidates.append(wall)
	for point: Vector3 in [Vector3(43,0,34),Vector3(30,0,3),Vector3(10,0,36),Vector3(35,0,15)]:
		var selected: Node3D
		var nearest := INF
		for wall in candidates:
			if wall in used:
				continue
			var distance := Vector2(wall.position.x-point.x,wall.position.z-point.z).length()
			if distance<nearest:
				selected = wall
				nearest = distance
		if selected==null:
			continue
		used.append(selected)
		var vertical := str(selected.get_parent().name)=="VerticalWalls"
		var mesh := MeshInstance3D.new()
		mesh.name = "WallFootInset"+str(strip_count)
		var plane := PlaneMesh.new()
		plane.size = Vector2(0.055,1.90)
		mesh.mesh = plane
		mesh.material_override = paint
		mesh.position = Vector3(selected.position.x,0.022,selected.position.z)
		mesh.position += Vector3(0.23,0,0) if vertical else Vector3(0,0,0.23)
		mesh.rotation.y = 0.0 if vertical else PI*0.5
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		strip_count += 1
func _process(_delta: float) -> void:
	paint.set_shader_parameter("acceleration",1.0 if actor.boost_remaining>0 else 0.0)

