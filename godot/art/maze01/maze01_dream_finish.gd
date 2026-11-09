extends RefCounted
## Bind shared finishes to the existing generated meshes and retain wall fade registration.

const PlasterSample := preload("res://art/maze01/materials/plaster_cream.tres")
const Stone := preload("res://art/maze01/materials/floor_limestone.tres")
const Roof := preload("res://art/maze01/materials/roof_lake.tres")
const ChapelGlass := preload("res://art/maze01/chapel_glass.gdshader")
const Prism := preload("res://art/maze01/legacy_prism_finish.gdshader")
const Fade := preload("res://art/maze01/plaster_fade.gdshader")
const GateFinish := preload("res://art/maze01/dream_gate_finish.gd")
const Atmosphere := preload("res://art/maze01/maze01_atmosphere.gd")
const WaterRipples := preload("res://art/maze01/wading_ripples.gd")
const StoneDetails := preload("res://art/maze01/maze01_stone_details.gd")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const StoneNormal := preload("res://art/maze01/materials/limestone/limestone_normal.png")
const StoneRoughness := preload("res://art/maze01/materials/limestone/limestone_roughness.png")
const Goldfish := preload("res://art/maze01/pool_goldfish.gd")
const Garden := preload("res://art/maze01/maze01_garden_details.gd")
const CharlieFinish := preload("res://art/maze01/charlie_storybook.gdshader")
const PLASTER_COLOR := Color("e9dfd0")
const CHAPEL_STONE := Color("cdb79f")
const TEAL_WALL := Color("9bbfc0")
const CREAM_VIOLET := Color("c6afd7")
const ACCENT_PORTALS := {"G2":TEAL_WALL,"G3":CREAM_VIOLET,"G4":TEAL_WALL,"G5":CREAM_VIOLET}
const ACCENT_WALLS := {
	"WallSegment_V_6_11":TEAL_WALL,"WallSegment_V_7_11":TEAL_WALL,
	"WallSegment_V_6_8":CREAM_VIOLET,"WallSegment_H_7_7":CREAM_VIOLET,
	"WallSegment_H_10_12":CREAM_VIOLET,"WallSegment_H_10_13":CREAM_VIOLET,
	"WallSegment_V_11_8":CREAM_VIOLET,"WallSegment_V_12_8":CREAM_VIOLET,
	"WallSegment_H_11_0":CREAM_VIOLET,
	"WallSegment_V_14_12":TEAL_WALL,"WallSegment_V_15_12":TEAL_WALL,
}
const NICHE_FACING_WALLS := ["WallSegment_V_7_1","WallSegment_V_8_1","WallSegment_V_9_1","WallSegment_V_10_1"]
const POOL_TEAL_WALLS := ["RetainingWall","WindowPier","WindowSill","WindowHeader"]
const WEATHERED_WALLS := ["WallSegment_V_11_8","WallSegment_H_10_13","WallSegment_V_6_8"]

static func apply(generator: Node3D, occlusion: Node, checkpoints: Array, actor: CharacterBody3D) -> void:
	var plaster: StandardMaterial3D = PlasterSample.duplicate()
	plaster.albedo_color = PLASTER_COLOR
	plaster.metallic_specular = 0.22
	var moulding: StandardMaterial3D = plaster.duplicate()
	moulding.albedo_color = PLASTER_COLOR.lerp(Color("ab9f92"), 0.17)
	moulding.roughness = 0.75
	moulding.normal_scale = 0.09
	var plinth: StandardMaterial3D = moulding.duplicate()
	plinth.albedo_color = PLASTER_COLOR.lerp(Stone.albedo_color, 0.42).darkened(0.025)
	var chapel_plaster: StandardMaterial3D = plaster.duplicate()
	chapel_plaster.cull_mode = BaseMaterial3D.CULL_BACK
	var floor := _prism_finish(Stone.albedo_color, Stone.albedo_color.darkened(0.045), false, true)
	var building: Dictionary = Layout.config().building
	var circle: Dictionary = building.circle
	var glass := ShaderMaterial.new()
	glass.shader = ChapelGlass
	glass.set_shader_parameter("clear_glass", Roof.albedo_color)
	glass.set_shader_parameter("chandelier_position", Vector3(circle.center[0], float(building.eave) - 1.96, circle.center[1]))
	var main_glass := glass.duplicate() as ShaderMaterial
	main_glass.set_shader_parameter("flower", true)
	var prism_plaster := _prism_finish(PLASTER_COLOR, PLASTER_COLOR, true)
	var bridge := _prism_finish(Stone.albedo_color, PLASTER_COLOR, true, true)
	var chapel_floor := _prism_finish(CHAPEL_STONE, CHAPEL_STONE, false, true)
	chapel_floor.set_shader_parameter("finish_roughness", 0.82)
	chapel_floor.set_shader_parameter("room_floor", Vector3(circle.center[0], circle.center[1], circle.usableRadius))
	var pool_floor := _prism_finish(Stone.albedo_color, Stone.albedo_color, false, true)
	var water_level := float(Layout.config().northwest.waterSurface)
	pool_floor.set_shader_parameter("waterline", water_level)
	pool_floor.set_shader_parameter("pool_entry_stone", true)
	var pool_risers := _prism_finish(plinth.albedo_color,plinth.albedo_color,false,true)
	pool_risers.set_shader_parameter("pool_entry_stone",true)
	pool_risers.set_shader_parameter("waterline",water_level)
	var pool_rail := Roof.duplicate() as StandardMaterial3D
	pool_rail.albedo_color = Roof.albedo_color.lerp(PLASTER_COLOR,0.10)
	pool_rail.roughness = 0.64
	pool_rail.metallic_specular = 0.22
	var wall_courses: Dictionary = {}
	var accent_materials: Dictionary = {}
	var dressed_boxes: Dictionary = {}
	var joined_walls := StoneDetails.wall_ends(generator, 2.4)
	var roof: Node3D = generator.round_hall.get_node("Roof")
	var courtyard: Node3D = generator.architecture.get_node("NorthwestCourtyard")
	var corridor: Node3D = generator.architecture.get_node("SunkenCorridor")
	var meshes: Array[Node] = generator.architecture.find_children("*","MeshInstance3D",true,false)
	for group: String in ["VerticalWalls", "HorizontalWalls"]:
		meshes.append_array(generator.get_node(group).find_children("*","MeshInstance3D",true,false))
	for mesh: MeshInstance3D in meshes:
		var part := str(mesh.get_meta("greybox_part",""))
		var role := "plaster"
		var material: Material = plaster
		if part in ["Indicator","WadingPoolSurface"]:
			continue
		if part == "PorchRoof":
			role = "porch_roof"
		elif roof.is_ancestor_of(mesh):
			role = "roof"
			material = Roof
			if part == "RoofRib":
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif part.begins_with("CurvedWall") or part == "PorchWall":
			role = "chapel_wall"
			material = chapel_plaster
		elif part == "WindowPane":
			role = "glass"
			material = main_glass if mesh.get_parent().get_meta("main_window", false) else glass
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif part == "HallFloor":
			role = "chapel_floor"
			material = chapel_floor
		elif part.is_empty() and mesh.get_parent() == courtyard:
			role = "floor_detail"
			material = pool_floor
		elif courtyard.is_ancestor_of(mesh) and (part.begins_with("GalleryBal") or part == "WindowBar"):
			role = "pool_rail"
			material = pool_rail
		elif part == "CourtyardRisers":
			role = "plinth"
			material = pool_risers
		elif _is_bridge_surface(part):
			role = "bridge"
			material = bridge
		elif part in ["GroundSlab","Tread"] or mesh.get_parent() == corridor and part.is_empty():
			role = "floor"
			material = floor
		elif part in ["Plinth", "Base", "CourtyardRisers", "WallSegment_H6_NicheBase"]:
			role = "plinth"
			material = plinth
		elif part in ["Cornice","Pilaster","Capital","Sill","ArchFrame","WindowJamb","Mullion","Transom","WallSegment_H6_NicheJamb"]:
			role = "moulding"
			material = moulding
		elif mesh.mesh is BoxMesh and (part.begins_with("WallSegment_V_") or part.begins_with("WallSegment_H_") or part.begins_with("WallSegment_H6_Panel")):
			role = "wall_banded"
			var half_height := (mesh.mesh as BoxMesh).size.y * 0.5
			if not wall_courses.has(half_height):
				var course := _prism_finish(PLASTER_COLOR, PLASTER_COLOR, false)
				course.set_shader_parameter("wall_half_height", half_height)
				wall_courses[half_height] = course
			material = wall_courses[half_height]
		elif _has_legacy_winding(part, mesh):
			role = "prism_plaster"
			material = prism_plaster
		var portal := str(mesh.get_parent().get_parent().name)
		var accent: Color = ACCENT_WALLS.get(part,ACCENT_PORTALS.get(portal,Color.TRANSPARENT))
		if part in NICHE_FACING_WALLS:
			accent = CREAM_VIOLET
		if part in POOL_TEAL_WALLS and courtyard.is_ancestor_of(mesh):
			accent = TEAL_WALL
		if accent.a > 0.0:
			var key := Vector2i(material.get_instance_id(), accent.to_rgba32())
			if not accent_materials.has(key):
				var finish := material.duplicate() as Material
				if finish is ShaderMaterial:
					finish.set_shader_parameter("finish_color",accent)
					finish.set_shader_parameter("finish_side_color",accent.darkened(0.025))
				else:
					finish.albedo_color = accent
				accent_materials[key] = finish
			material = accent_materials[key]
			mesh.set_meta("accent_tint",accent)
		if role == "wall_banded" and part in WEATHERED_WALLS:
			var worn := material.duplicate() as ShaderMaterial
			worn.set_shader_parameter("weathering_axis",2 if part.begins_with("WallSegment_V_") else 1)
			material = worn
		mesh.material_override = material
		mesh.set_meta("art_role", role)
		if mesh.mesh is BoxMesh and (role == "wall_banded" or part in ["Sill", "Capital", "Tread"]):
			StoneDetails.soften_edges(mesh, dressed_boxes, joined_walls.get(mesh, []))
		if part.ends_with("_Reserved"):
			mesh.hide()
	for gate: Node3D in generator.gates.values():
		GateFinish.new().install(gate, plaster, moulding)
	for point: Dictionary in checkpoints:
		generator.get_node(str(point.id)).hide()
	for label: Label3D in generator.architecture.find_children("*","Label3D",true,false):
		if label.get_parent() not in generator.switches.values():
			label.hide()
	_update_fade_materials(occlusion, plaster, moulding, plinth)
	Atmosphere.new().install(generator, generator.round_hall, moulding)
	WaterRipples.new().install(courtyard.get_node("WadingPoolSurface"), actor, water_level)
	Goldfish.new().install(courtyard, actor, water_level)
	Garden.new().install_pool(courtyard,water_level)
	Garden.install_plaza(generator.get_node("EarthBearer"))
	_finish_charlie(actor)

static func _finish_charlie(actor: Node3D) -> void:
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_surface_override_material(surface) as ShaderMaterial
			if original == null or original.get_shader_parameter("base_color") == null:
				continue
			var paint := ShaderMaterial.new()
			paint.shader = CharlieFinish
			paint.set_shader_parameter("base_color", original.get_shader_parameter("base_color"))
			mesh.set_surface_override_material(surface, paint)

static func _is_bridge_surface(part: String) -> bool:
	return part.begins_with("H1_") or part.begins_with("H2_") or part.begins_with("H3_") or part.begins_with("H4_")

static func _has_legacy_winding(part: String, mesh: MeshInstance3D) -> bool:
	if part.begins_with("ArchStone") or part.begins_with("WallAboveArch"):
		return str(mesh.get_parent().get_parent().name) not in ["G6","G7","G8"]
	return part.begins_with("GuardRail") or part.begins_with("VaultStone") or part.begins_with("ArchFace") \
		or part in ["WallSegment_H6_NicheArch","WallSegment_H6_NicheAbove"]

static func _prism_finish(color: Color, side_color: Color, reverse_winding: bool, textured: bool = false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Prism
	material.set_shader_parameter("finish_color", color)
	material.set_shader_parameter("finish_side_color", side_color)
	material.set_shader_parameter("legacy_winding", reverse_winding)
	material.set_shader_parameter("finish_roughness", PlasterSample.roughness if color == PLASTER_COLOR else Stone.roughness)
	material.set_shader_parameter("grain", PlasterSample.normal_texture)
	material.set_shader_parameter("limestone", textured)
	if textured:
		material.set_shader_parameter("stone_normal", StoneNormal)
		material.set_shader_parameter("stone_roughness", StoneRoughness)
	return material

static func _update_fade_materials(occlusion: Node, plaster: StandardMaterial3D, moulding: StandardMaterial3D, plinth: StandardMaterial3D) -> void:
	for group: Dictionary in occlusion.groups.values():
		for entry: Dictionary in group.entries:
			var role: String = entry.mesh.get_meta("art_role", "")
			if role.is_empty():
				continue
			entry.original = entry.mesh.material_override
			var base: StandardMaterial3D = moulding if role == "moulding" else plaster
			if role == "plinth":
				base = plinth
			if role == "gate_glaze":
				base = entry.original
			else:
				entry.alpha.shader = Fade
				entry.alpha.set_shader_parameter("grain", PlasterSample.normal_texture)
				entry.alpha.set_shader_parameter("legacy_winding", role == "prism_plaster")
				if role == "wall_banded":
					entry.alpha.set_shader_parameter("wall_half_height", entry.original.get_shader_parameter("wall_half_height"))
			entry.alpha.set_shader_parameter("stone_color", entry.mesh.get_meta("accent_tint",base.albedo_color))
			entry.alpha.set_shader_parameter("stone_roughness", base.roughness)
			entry.alpha.set_shader_parameter("opacity", 1.0)
