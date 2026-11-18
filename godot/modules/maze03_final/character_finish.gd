extends RefCounted
## Only the Maze03 model instance receives this finish; authored colors and mesh are preserved.
static func apply(actor: Node3D) -> void:
 var cache: Dictionary={}
 for mesh: MeshInstance3D in actor.visual.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   var original:=mesh.get_active_material(surface) as ShaderMaterial
   if original==null or original.get_shader_parameter("base_color")==null:
    continue
   if not cache.has(original):
    var paint:=original.duplicate() as ShaderMaterial
    paint.shader=preload("res://modules/maze03_final/charlie_clean_finish.gdshader")
    paint.set_shader_parameter("base_color",load("res://modules/maze03_final/charlie_surface_color.jpg"))
    cache[original]=paint
   mesh.set_surface_override_material(surface,cache[original])
