extends Node3D

const Cloud := preload("res://art/environments/cloud_sea.gdshader")
const SkyMemories := preload("res://art/environments/sky_memories/sky_memories.gd")
const Geometry := preload("res://scripts/levels/greybox_geometry.gd")
const WallPlan := preload("res://scripts/levels/wall_plan.gd")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const Fireflies := preload("res://art/maze01/firefly_cluster.gd")
const Breeze := preload("res://art/maze01/path_breeze.gdshader")
const Chandelier := preload("res://modules/crystal_chandelier/crystal_chandelier.tscn")

func install(generator: Node3D, hall: Node3D, trim: Material) -> void:
	name = "DreamAtmosphere"
	generator.get_parent().add_child(self)
	_add_cloud(-19.0, 0.037, Vector2(0.005, 0.002), Color("e8d5f8"), 0.48, Vector2(19.0, -7.0))
	_add_cloud(-9.5, 0.053, Vector2(0.008, -0.003), Color("fff3f8"), 0.65, Vector2(0.0, 0.0))
	SkyMemories.new().install(generator.get_parent(),Vector3(22.8,0,22.8))
	_light_chapel(hall, trim)
	_light_the_path(generator.architecture)
	_add_maze_mist()
	_add_exterior_clouds()

func _add_maze_mist() -> void:
	_add_breeze("PlazaEntranceBreeze",Vector3(21.26,0.58,14.22),-0.17,0.35,0.58)
	_add_breeze("PlazaBreeze",Vector3(23.1,0.75,16.78),0.51,1.2,0.61,Vector2(7.1,1.92))
	_add_breeze("PlazaUpperBreeze",Vector3(23.68,1.37,15.01),-0.63,4.5,0.56)
	_add_breeze("PlazaBackBreeze",Vector3(20.88,1.43,18.12),0.26,2.82,0.50)
	_add_breeze("WestWalkBreeze",Vector3(13.2,0.58,18.0),-0.94,2.6,0.60,Vector2(6.8,1.64))
	_add_breeze("SouthBridgeBreeze",Vector3(15.4,1.83,43.8),0.72,3.7,0.61,Vector2(7.6,1.94))
	_add_breeze("EastWalkBreeze",Vector3(34.8,0.53,32.4),-0.67,0.5,0.61,Vector2(6.9,1.66))
	_add_breeze("NorthArchBreeze",Vector3(13.2,0.78,10.8),-0.46,2.2,0.58,Vector2(6.6,1.80))
	_add_breeze("EastBridgeBreeze",Vector3(39.6,3.05,17.9),0.64,5.1,0.63,Vector2(7.5,2.08))
	_add_breeze("EntryBreeze",Vector3(1.2,0.68,43.3),0.76,1.8,0.54,Vector2(6.4,1.72))
	_add_breeze("ChapelTerraceBreeze",Vector3(23.7,1.64,30.55),-0.27,3.5,0.56,Vector2(6.9,1.91))
	_add_breeze("ExitBreeze",Vector3(44.25,0.51,2.68),0.63,5.9,0.32,Vector2(6.4,1.42))

	_add_scene_haze("MazeFloorHaze",1.48,0.0,0.49)
	_add_scene_haze("MazeUpperHaze",2.92,3.65,0.28)
	var upper_drifts := [
		[Vector3(10.7,2.32,13.0),Vector2(19.0,3.15),0.36,1.3],
		[Vector3(24.9,2.81,12.6),Vector2(21.0,3.55),0.86,2.2],
		[Vector3(37.2,3.15,25.8),Vector2(20.0,3.8),1.07,3.7],
		[Vector3(9.6,2.47,31.4),Vector2(18.5,3.4),1.39,4.2],
		[Vector3(25.4,2.92,38.8),Vector2(24.0,3.7),-0.40,5.8],
	]
	for i in upper_drifts.size():
		var drift: Array = upper_drifts[i]
		var ribbon := _mist_ribbon(self,"HighMist%d"%i,drift[0],drift[1],drift[2],-0.19,drift[3],0.48,true)
		ribbon.material_override.set_shader_parameter("soft_contact",true)
	for trail: Array in [
		["Northwest", Vector2(6.0,3.6), -0.32],
		["North", Vector2(20.4,6.0), 0.76],
		["NorthCourt", Vector2(30.0,3.6), -0.31],
		["Northeast", Vector2(39.6,6.0), 1.18],
		["LowerNiches", Vector2(3.6,26.9), 1.32],
		["WestTurns", Vector2(8.4,22.8), -0.27],
		["Southwest", Vector2(8.4,32.4), 0.82],
		["SouthCourt", Vector2(22.8,39.6), -0.58],
		["SouthTurns", Vector2(32.4,39.6), 0.37],
		["Southeast", Vector2(42.0,42.0), -0.27],
		["EastTurns", Vector2(42.0,25.2), 0.63],
	]:
		var id: String = trail[0]
		var point: Vector2 = trail[1]
		var elevation := Layout.height_at(point)
		var phase := fmod(point.x * 0.41 + point.y * 0.23, TAU)
		var span := Vector2(8.4,1.88) if id != "LowerNiches" else Vector2(6.1,1.50)
		_add_breeze(id+"TrailBreeze",Vector3(point.x,elevation+0.64,point.y),trail[2],phase,0.53,span,0.43)
		_add_fireflies(id+"TrailFireflies",Vector3(point.x,elevation+1.01,point.y),phase,
			0.23,5,0.24,2.15)

func _add_scene_haze(id: String, height: float, phase: float, density: float) -> void:
	var haze := _mist_ribbon(self,id,Vector3(22.8,height,22.8),
		Vector2(45.6,45.6),0.0,-PI*0.5,phase,density)
	haze.material_override.set_shader_parameter("maze_haze",true)
	haze.material_override.render_priority = -1

func _add_exterior_clouds() -> void:
	var banks := Node3D.new()
	banks.name = "ExteriorCloudBanks"
	add_child(banks)
	var center := Vector3(22.8, 0.0, 22.8)
	for i in 8:
		var angle := float(i)*TAU/8.0 + 0.18
		var radial := Vector3(sin(angle),0.0,cos(angle))
		var radius := 44.0 + float(i % 3)*7.0
		var point := center + radial*radius + Vector3.UP*(-5.9 + float(i % 3)*1.7)
		var span := Vector2(38.0 + float(i % 3)*5.0, 8.4 + float(i % 3)*1.1)
		_mist_ribbon(banks,"CloudBank%d"%i,point,span,angle+0.19,0.0,float(i)*1.79,0.56,true)

func _add_cloud(height: float, pattern_scale: float, drift: Vector2, tint: Color, opacity: float, offset: Vector2) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(440, 440)
	var material := ShaderMaterial.new()
	material.shader = Cloud
	material.set_shader_parameter("pattern_scale", pattern_scale)
	material.set_shader_parameter("drift", drift)
	material.set_shader_parameter("cloud_tint", tint)
	material.set_shader_parameter("opacity", opacity)
	material.set_shader_parameter("offset", offset)
	var cloud := _detail(self, "CloudSea", plane, material, Vector3(22.8, height, 22.8))
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _light_chapel(hall: Node3D, trim: Material) -> void:
	var building: Dictionary = Layout.config().building
	var center: Array = building.circle.center
	var eave := float(building.eave)
	var ceiling := CylinderMesh.new()
	ceiling.top_radius = float(building.circle.outerRadius) + 0.04
	ceiling.bottom_radius = ceiling.top_radius
	ceiling.height = 0.038
	ceiling.radial_segments = 72
	var roof := hall.get_node("Roof")
	_detail(roof, "CreamCeiling", ceiling, trim, Vector3(center[0], eave - 0.064, center[1]))
	_add_chapel_moulding(hall, building, trim)
	var lamp := Chandelier.instantiate()
	lamp.position = Vector3(center[0], eave - 0.83, center[1])
	lamp.scale = Vector3.ONE * 1.34
	lamp.brightness = 1.06
	lamp.halo_strength = 0.22
	lamp.illuminate_surroundings = false
	roof.add_child(lamp)
	for mesh: MeshInstance3D in lamp.find_children("*", "MeshInstance3D", true, false):
		mesh.set_meta("art_addition", true)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hanger := CylinderMesh.new()
	hanger.top_radius = 0.021
	hanger.bottom_radius = 0.021
	hanger.height = 0.80
	hanger.radial_segments = 10
	_detail(roof, "BronzeHanger", hanger, Geometry.material(Color("af8764")), lamp.position + Vector3.UP * 0.39)

	var floor_light := SpotLight3D.new()
	floor_light.name = "ChandelierFloorLight"
	floor_light.position = lamp.position + Vector3.DOWN * 1.17
	floor_light.rotation_degrees.x = -90
	floor_light.light_color = Color("ffdaad")
	floor_light.light_energy = 1.69
	floor_light.light_specular = 0.18
	floor_light.spot_range = 7.1
	floor_light.spot_angle = 38.0
	floor_light.spot_attenuation = 1.08
	floor_light.spot_angle_attenuation = 1.22
	roof.add_child(floor_light)
	var bounce := _warm_pool(roof, "FloorBounce", Vector3(center[0], 0.49, center[1]), 0.21, 3.75)
	bounce.light_color = Color("ffe2c3")
	bounce.light_specular = 0.02

	# Directional light can enter the physical apertures; this soft cool wash
	# keeps the main bay readable from indoors when the sun is on the far side.
	var skylight := SpotLight3D.new()
	skylight.name = "WestWindowSkylight"
	skylight.light_color = Color("c2d8ff")
	skylight.light_energy = 0.31
	skylight.spot_range = 4.4
	skylight.spot_angle = 29.0
	skylight.spot_angle_attenuation = 1.3
	hall.add_child(skylight)
	skylight.look_at_from_position(Vector3(21.06, 2.20, 23.60), Vector3(22.80, 0, 23.18))
	_warm_pool(hall, "SouthArchWarmPool", Vector3(25.2, 2.12, 25.94), 0.67, 3.2)

func _add_chapel_moulding(hall: Node3D, building: Dictionary, material: Material) -> void:
	var center := Vector2(building.circle.center[0], building.circle.center[1])
	var radius := float(building.circle.usableRadius)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var eave := float(building.eave)
	for band: Vector3 in [Vector3(0.045, 0.18, 0.055), Vector3(eave-0.54, eave-0.41, 0.078)]:
		for segment in 144:
			var a := Vector2.from_angle(TAU*segment/144)
			var b := Vector2.from_angle(TAU*(segment+1)/144)
			var plan := PackedVector2Array([
				center+a*(radius-band.z),center+b*(radius-band.z),
				center+b*(radius+0.014),center+a*(radius+0.014),
			])
			for piece: PackedVector2Array in WallPlan.outside_porches(plan,building.porches):
				for i in range(1,piece.size()-1):
					_band_triangle(surface,piece[0],piece[i+1],piece[i],band.y,Vector3.UP)
					_band_triangle(surface,piece[0],piece[i],piece[i+1],band.x,Vector3.DOWN)
				for i in piece.size():
					var p := piece[i]
					var q := piece[(i+1)%piece.size()]
					var start := Vector3(p.x,band.x,p.y)
					var end := Vector3(q.x,band.x,q.y)
					var up := Vector3.UP * (band.y-band.x)
					var normal := (start-end).cross(up).normalized()
					surface.set_normal(normal)
					for vertex: Vector3 in [start,end,end+up,start,end+up,start+up]:
						surface.add_vertex(vertex)
	_detail(hall,"InteriorStoneCourses",surface.commit(),material,Vector3.ZERO)

func _band_triangle(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, y: float, normal: Vector3) -> void:
	surface.set_normal(normal)
	for point: Vector2 in [a,b,c]:
		surface.add_vertex(Vector3(point.x,y,point.y))

func _light_the_path(architecture: Node3D) -> void:
	var first_arch := architecture.get_node("G1") as Node3D
	_warm_pool(first_arch, "EntryArchWarmPool", Vector3(0.0, 1.55, 0.04), 0.56, 2.95)
	_warm_pool(self, "UnderpassWarmPool", Vector3(38.01, 1.28, 15.60), 0.56, 2.48)
	_warm_pool(self, "TerraceTurnWarmPool", Vector3(25.78, 2.11, 30.52), 0.44, 2.56)
	var courtyard: Dictionary = Layout.config().northwest
	var water := float(courtyard.waterSurface)
	var bottom := float(courtyard.minimum)
	var bottom_light := _warm_pool(self, "PoolBottomLight", Vector3(2.66, lerpf(bottom, water, 0.67), 11.10), 0.16, 1.25)
	bottom_light.light_specular = 0.025
	_add_fireflies("PoolFirefliesWest", Vector3(1.16, water + 0.63, 10.84), 0.0)
	_add_fireflies("PoolFirefliesSouth", Vector3(3.66, water + 0.73, 13.34), 2.8)
	_add_fireflies("EastTerraceFireflies", Vector3(37.72, 1.23, 30.44), 4.7)
	_add_fireflies("SouthWalkFireflies", Vector3(14.40, 1.86, 44.40), 1.4, 0.23, 5, 0.23, 2.28)
	_add_fireflies("NorthBridgeFireflies", Vector3(39.60, 0.96, 10.80), 3.3, 0.22, 5, 0.22, 2.19)
	_add_fireflies("ExitFireflies", Vector3(44.40, 0.68, 1.20), 5.2, 0.21, 5, 0.23, 2.10)
	_add_fireflies("WestGardenTurnFireflies", Vector3(6.0, 0.81, 16.80), 1.1, 0.20, 5, 0.22, 2.12)
	_add_fireflies("ChapelTerraceFireflies", Vector3(22.76, 1.92, 30.65), 3.8, 0.22, 5, 0.23, 2.14)
	_add_fireflies("SouthGateFireflies", Vector3(6.0,0.72,37.2), 1.7, 0.15, 4, 0.22)
	_add_fireflies("NorthwestWalkFireflies", Vector3(13.2,0.93,11.48), 5.7, 0.21, 5, 0.23, 2.13)
	_add_fireflies("WesternArchFireflies", Vector3(18.0,0.74,20.4), 2.1, 0.0, 3)
	_add_fireflies("EasternArchFireflies", Vector3(30.0,0.75,20.4), 4.1, 0.08, 4)
	_add_fireflies("SouthEastWalkFireflies", Vector3(34.8,0.81,32.4), 0.8, 0.24, 5, 0.24, 2.16)
	_add_fireflies("PlazaWestFireflies",Vector3(21.22,0.92,16.07),2.87,0.54,6,0.28,2.58)
	_add_fireflies("PlazaEastFireflies",Vector3(24.36,1.04,14.85),5.16,0.58,6,0.28,2.58)
	_add_fireflies("WestMistFireflies",Vector3(13.2,0.95,17.8),3.8,0.24,5,0.24,2.16)
	_add_fireflies("RaisedEastMistFireflies",Vector3(39.6,3.62,17.4),4.3,0.23,5,0.24,2.22)
	_add_fireflies("EntryMistFireflies",Vector3(1.2,1.02,43.25),1.34,0.24,5,0.23,2.13)

func _warm_pool(parent: Node3D, id: String, point: Vector3, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = id
	light.position = point
	light.light_color = Color("ffd58b")
	light.light_energy = energy
	light.light_specular = 0.16
	light.omni_range = radius
	light.omni_attenuation = 1.0
	parent.add_child(light)
	return light

func _add_fireflies(id: String, point: Vector3, phase: float, bounce_energy: float = 0.19,
		dot_count: int = 5, spark_size: float = 0.18, bounce_range: float = 1.85) -> void:
	var cluster := Fireflies.new()
	cluster.name = id
	cluster.position = point
	cluster.phase = phase
	cluster.bounce_energy = bounce_energy
	cluster.dot_count = dot_count
	cluster.spark_size = spark_size
	cluster.bounce_range = bounce_range
	add_child(cluster)

func _add_breeze(id: String, point: Vector3, yaw: float, phase: float, density: float,
		span: Vector2 = Vector2(5.4,1.70), warmth: float = 0.36) -> void:
	var drift := Node3D.new()
	drift.name = id
	drift.position = point
	add_child(drift)
	var lower := _mist_ribbon(drift,"MistRibbon1",Vector3.ZERO,span,yaw,-0.36,phase,density)
	var upper := _mist_ribbon(drift,"MistRibbon2",Vector3(0.25,0.39,-0.30),span*0.83,yaw+1.39,0.49,phase+2.83,density*0.81)
	lower.material_override.set_shader_parameter("warmth",warmth)
	upper.material_override.set_shader_parameter("warmth",warmth*0.76)
	if span.x >= 6.0:
		var canopy := _mist_ribbon(drift,"MistCanopy",Vector3(0.12,0.43,-0.18),
			Vector2(span.x*0.91,span.x*0.64),yaw,-PI*0.5,phase+1.9,density*0.47)
		canopy.material_override.set_shader_parameter("ground_sheet",true)

func _mist_ribbon(parent: Node3D, id: String, point: Vector3, span: Vector2, yaw: float,
		pitch: float, phase: float, density: float, distant: bool = false) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = span
	var paint := ShaderMaterial.new()
	paint.shader = Breeze
	paint.set_shader_parameter("phase",phase)
	paint.set_shader_parameter("density",density)
	paint.set_shader_parameter("distant",distant)
	var layer := _detail(parent,id,mesh,paint,point)
	layer.rotation = Vector3(pitch,yaw,0.0)
	layer.extra_cull_margin = 2.0 if distant else 0.75
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return layer

func _detail(parent: Node3D, id: String, mesh: Mesh, material: Material, point: Vector3) -> MeshInstance3D:
	var detail := MeshInstance3D.new()
	detail.name = id
	detail.mesh = mesh
	detail.material_override = material
	detail.position = point
	detail.set_meta("art_addition", true)
	parent.add_child(detail)
	return detail
