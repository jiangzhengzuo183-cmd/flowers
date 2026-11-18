extends RefCounted
## Finished Maze01 stone pipeline, independently recolored and instanced.
const Plaster:=preload("res://art/maze03/materials/plaster_cream.tres")
const Stone:=preload("res://art/maze03/materials/floor_limestone.tres")
const ShaderFinish:=preload("res://art/maze03/stone_finish.gdshader")
const ShaderFade:=preload("res://art/maze03/stone_fade.gdshader")
const StoneNormal:=preload("res://art/maze01/materials/limestone/limestone_normal.png")
const StoneRoughness:=preload("res://art/maze01/materials/limestone/limestone_roughness.png")
const CharlieFinish:=preload("res://art/maze01/charlie_storybook.gdshader")
static func stone(color: Color,legacy: bool=false,textured: bool=false) -> ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=ShaderFinish
	material.set_shader_parameter("finish_color",color)
	material.set_shader_parameter("finish_side_color",color.darkened(0.012))
	material.set_shader_parameter("legacy_winding",legacy)
	material.set_shader_parameter("finish_roughness",0.92)
	material.set_shader_parameter("grain",Plaster.normal_texture)
	material.set_shader_parameter("limestone",textured)
	if textured:
		material.set_shader_parameter("stone_normal",StoneNormal)
		material.set_shader_parameter("stone_roughness",StoneRoughness)
	return material
static func apply(generator: Node3D,occlusion: Node,actor: Node3D) -> void:
	var plaster:=Plaster.duplicate() as StandardMaterial3D
	plaster.albedo_color=Color("e9eae7")
	plaster.metallic_specular=0.16
	var floor:=stone(Color("f3f0e9"),false,true)
	var bridge:=stone(Color("eeede7"),true,true)
	var reverse:=stone(Color("e9eae7"),true)
	for mesh: MeshInstance3D in generator.find_children("*","MeshInstance3D",true,false):
		if mesh.get_meta("custom_maze03_finish",false) or mesh.get_parent() is Area3D:
			continue
		var part:=str(mesh.get_meta("greybox_part",""))
		var legacy:=part.begins_with("GuardRail") or part.begins_with("VaultStone") or part.begins_with("ArchStone") or part.begins_with("ArchFace") or part.begins_with("WallAboveArch")
		if part in ["GroundSlab","PlainSunkenSlab","Tread"]:
			mesh.material_override=floor
		elif part.begins_with("H1_") or part.begins_with("H2_") or part.begins_with("H3_"):
			mesh.material_override=bridge
		elif legacy:
			mesh.material_override=reverse
		else:
			mesh.material_override=plaster
		mesh.set_meta("maze03_legacy",legacy)
	# Keep the established local occlusion controls and final plaster fade.
	for group: Dictionary in occlusion.groups.values():
		for entry: Dictionary in group.entries:
			entry.original=entry.mesh.material_override
			entry.alpha.shader=ShaderFade
			entry.alpha.set_shader_parameter("grain",Plaster.normal_texture)
			entry.alpha.set_shader_parameter("stone_color",Color("e9eae7"))
			entry.alpha.set_shader_parameter("stone_roughness",0.92)
			entry.alpha.set_shader_parameter("legacy_winding",entry.mesh.get_meta("maze03_legacy",false))
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original:=mesh.get_surface_override_material(surface) as ShaderMaterial
			if original!=null and original.get_shader_parameter("base_color")!=null:
				var paint:=ShaderMaterial.new()
				paint.shader=CharlieFinish
				paint.set_shader_parameter("base_color",original.get_shader_parameter("base_color"))
				mesh.set_surface_override_material(surface,paint)
