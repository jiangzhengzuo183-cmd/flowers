extends CharacterBody3D
## Instanced authored mesh/skin and copied animation tracks; the source GLB stays unchanged.
const MODEL := preload("res://modules/maze03_race/assets/algernon.glb")
const CLIPS := {&"scratch_001":&"Scratch",&"run_001":&"Run",&"turn_001":&"Turn",&"dance_02_001":&"Dance"}
var animation_player: AnimationPlayer
var model: Node3D
var pose: Node3D
var current_clip := &""
var nominal_gait_speed := 1.03
var visual: Node3D
var controls_enabled := true
var boost_remaining := 0.0
var speed_ribbons: Node3D
var paints: Array[ShaderMaterial] = []
var opacity := 1.0

func setup(height: float) -> void:
 collision_layer=0
 collision_mask=0
 pose = Node3D.new()
 pose.name = "Facing"
 add_child(pose)
 visual=pose
 model = MODEL.instantiate()
 model.name = "AuthoredMouse"
 model.rotation.y = PI*0.5
 model.scale = Vector3.ONE*height
 pose.add_child(model)
 animation_player = model.find_child("AnimationPlayer",true,false)
 var skeleton := model.find_child("Skeleton3D",true,false) as Skeleton3D
 var hip := skeleton.find_bone("Hip")
 var rest := skeleton.get_bone_rest(hip).origin
 var parent_basis := skeleton.get_bone_global_rest(skeleton.get_bone_parent(hip)).basis
 var library := AnimationLibrary.new()
 for source: StringName in CLIPS:
  if not animation_player.has_animation(source):
   push_error("老鼠缺少动画："+source)
   continue
  var clip: StringName = CLIPS[source]
  var animation := animation_player.get_animation(source).duplicate() as Animation
  for track in animation.get_track_count():
   if animation.track_get_type(track)!=Animation.TYPE_POSITION_3D or animation.track_get_path(track).get_concatenated_subnames()!=&"Hip":continue
   for key in animation.track_get_key_count(track):
    var original: Vector3 = animation.track_get_key_value(track,key)
    var vertical := (parent_basis*(original-rest)).y
    animation.track_set_key_value(track,key,rest+parent_basis.inverse()*Vector3.UP*vertical)
  animation.loop_mode = Animation.LOOP_LINEAR if clip in [&"Scratch",&"Run",&"Dance"] else Animation.LOOP_NONE
  library.add_animation(clip,animation)
 animation_player.remove_animation_library(&"")
 animation_player.add_animation_library(&"",library)
 for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   var original := mesh.get_active_material(surface) as BaseMaterial3D
   if original!=null and original.albedo_texture!=null:
    var material := ShaderMaterial.new()
    material.shader = preload("res://modules/maze03_race/mouse_finish.gdshader")
    material.set_shader_parameter("base_color",original.albedo_texture)
    mesh.material_override = material
    paints.append(material)
 play(&"Scratch")
 speed_ribbons=preload("res://modules/maze03_final/speed_trails.gd").new()
 speed_ribbons.maximum_ghosts=2
 speed_ribbons.snapshot_interval=0.16
 speed_ribbons.ghost_lifetime=0.28
 speed_ribbons.actor=self
 add_child(speed_ribbons)

func play(clip: StringName, speed: float = 1.0) -> void:
 animation_player.speed_scale = speed
 if current_clip!=clip:
  current_clip = clip
  animation_player.play(clip,0.12)

func face(direction: Vector3, delta: float, instant: bool = false) -> void:
 if Vector2(direction.x,direction.z).length_squared()<0.001:return
 var yaw := atan2(-direction.x,-direction.z)
 pose.rotation.y = yaw if instant else lerp_angle(pose.rotation.y,yaw,minf(1.0,delta*16.0))

func run(speed: float, time_scale: float = 1.0) -> void:
 play(&"Run",clampf(speed/nominal_gait_speed,0.5,3.8)*time_scale)

func hesitate(duration: float) -> void:
 play(&"Turn",animation_player.get_animation(&"Turn").length/duration)

func suspend_animation(value: bool) -> void:
 animation_player.active = not value

func set_opacity(value: float) -> void:
 opacity=clampf(value,0.0,1.0)
 for paint in paints:paint.set_shader_parameter("reveal",opacity)
 if opacity<=0.0:
  hide()
  controls_enabled=false
  speed_ribbons.clear()
 else:show()
