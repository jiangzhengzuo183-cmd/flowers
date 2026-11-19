extends Node3D
## A live skinned silhouette in the capsule's existing cue world, at Charlie's actual pose.
var sources: Array[MeshInstance3D] = []
var copies: Array[MeshInstance3D] = []
var skeletons: Dictionary = {}
func install(actor: CharacterBody3D, paint: Material) -> void:
 name="CharlieVisionSilhouette"
 for source: MeshInstance3D in actor.visual.find_children("*","MeshInstance3D",true,false):
  if source.mesh==null:continue
  var original := source.get_node_or_null(source.skeleton) as Skeleton3D
  if original!=null and not skeletons.has(original):
   var skeleton := Skeleton3D.new()
   add_child(skeleton)
   for bone in original.get_bone_count():
    skeleton.add_bone(original.get_bone_name(bone))
    skeleton.set_bone_parent(bone,original.get_bone_parent(bone))
    skeleton.set_bone_rest(bone,original.get_bone_rest(bone))
   skeletons[original]=skeleton
  var copy := MeshInstance3D.new()
  copy.mesh=source.mesh
  copy.material_override=paint
  copy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(copy)
  if original!=null:
   copy.skeleton=copy.get_path_to(skeletons[original])
   copy.skin=source.skin
  sources.append(source)
  copies.append(copy)
 sync_pose()
func sync_pose() -> void:
 for original: Skeleton3D in skeletons:
  if not is_instance_valid(original):continue
  var copy: Skeleton3D = skeletons[original]
  copy.global_transform=original.global_transform
  for bone in original.get_bone_count():
   copy.set_bone_pose_position(bone,original.get_bone_pose_position(bone))
   copy.set_bone_pose_rotation(bone,original.get_bone_pose_rotation(bone))
   copy.set_bone_pose_scale(bone,original.get_bone_pose_scale(bone))
 for i in sources.size():
  if not is_instance_valid(sources[i]):continue
  copies[i].global_transform=sources[i].global_transform
  copies[i].visible=sources[i].visible
