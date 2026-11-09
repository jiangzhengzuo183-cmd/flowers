extends Node3D
## Three small swimmers, bounded to the open, flat parts of the shallow H5 basin.

const TRACKS := [
	[Vector2(1.22, 10.73), Vector2(0.63, 0.51), 0.28, 0.48],
	[Vector2(3.43, 10.89), Vector2(0.61, 0.48), 2.35, 0.41],
	[Vector2(3.59, 12.89), Vector2(0.55, 0.62), 4.67, 0.37],
]
const SCALES := [1.02, 0.88, 1.12]
const COLORS := [Color("f29a44"), Color("ef6339"), Color("f4e6d6")]
const FINS := [Color("f1b365"), Color("ed8860"), Color("e78868")]
var _actor: CharacterBody3D
var _surface: float
var _fish: Array[Node3D] = []
var _tails: Array[Node3D] = []
var _phases := PackedFloat32Array()
var _alarm := PackedFloat32Array([0.0, 0.0, 0.0])
var _near := [false, false, false]

func install(courtyard: Node3D, actor: CharacterBody3D, water_level: float) -> void:
	name = "PoolGoldfish"
	_actor = actor
	_surface = water_level
	courtyard.add_child(self)
	var body := SphereMesh.new()
	body.radius = 0.5
	body.height = 1.0
	body.radial_segments = 10
	body.rings = 4
	var fin := _fin_mesh()
	var eye := _paint(Color("4b3b39"))
	for i in TRACKS.size():
		var fish := Node3D.new()
		fish.name = "Goldfish%d" % (i + 1)
		add_child(fish)
		var main := _paint(COLORS[i])
		var fin_color := _paint(FINS[i])
		_piece(fish, body, main, Vector3.ZERO, Vector3(0.105, 0.114, 0.25))
		if i == 2:
			_piece(fish, body, fin_color, Vector3(0, 0.029, -0.067), Vector3(0.091, 0.066, 0.103))
		for side: float in [-1.0, 1.0]:
			_piece(fish, body, eye, Vector3(side * 0.037, 0.013, -0.080), Vector3.ONE * 0.018)
			var pectoral := _piece(fish, fin, fin_color, Vector3(side * 0.027, -0.022, 0.0), Vector3(0.49, 0.47, 0.51))
			pectoral.rotation.z = side * 1.07
		_piece(fish, fin, fin_color, Vector3(0, 0.046, -0.030), Vector3(0.5, 0.44, 0.75))
		var tail := Node3D.new()
		tail.position.z = 0.083
		fish.add_child(tail)
		_piece(tail, fin, fin_color, Vector3.ZERO, Vector3.ONE)
		fish.scale = Vector3.ONE * SCALES[i]
		_fish.append(fish)
		_tails.append(tail)
		_phases.append(TRACKS[i][2])
	_process(0.0)

func _process(delta: float) -> void:
	for i in _fish.size():
		var track: Array = TRACKS[i]
		var center: Vector2 = track[0]
		var orbit: Vector2 = track[1]
		var player_distance := _actor.position.distance_squared_to(_fish[i].position)
		var close := player_distance < 0.77 and _actor.position.y < _surface + 0.10
		if close and not _near[i]:
			_alarm[i] = 1.0
		_near[i] = close
		_alarm[i] = move_toward(_alarm[i], 0.0, delta * 0.39)
		_phases[i] = fposmod(_phases[i] + delta * float(track[3]) * (1.0 + 1.8 * _alarm[i]), TAU)
		var a := _phases[i]
		var point := center + orbit * Vector2(cos(a), sin(a))
		var forward := orbit * Vector2(-sin(a), cos(a))
		var y := _surface - 0.142 + sin(a * 3.0 + i) * 0.012
		_fish[i].position = Vector3(point.x, y, point.y)
		_fish[i].rotation.y = atan2(-forward.x, -forward.y)
		_fish[i].rotation.z = sin(a * 7.0) * 0.075
		_tails[i].rotation.y = sin(a * 11.0 + i) * (0.27 + 0.18 * _alarm[i])

func _paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.50
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.33
	return material

func _piece(parent: Node3D, mesh: Mesh, material: Material, offset: Vector3, size: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	instance.scale = size
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta("art_addition", true)
	parent.add_child(instance)
	return instance

func _fin_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.RIGHT)
	var tip := Vector3(0, 0, 0)
	var notch := Vector3(0, 0, 0.105)
	for point: Vector3 in [
		tip, Vector3(0, 0.070, 0.159), notch,
		tip, notch, Vector3(0, -0.055, 0.143),
	]:
		surface.add_vertex(point)
	return surface.commit()
