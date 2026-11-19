extends MeshInstance3D
signal flight_finished
## A single distant world-space light ribbon; no particles, lights or camera overlay.
@export_range(3.0,12.0,0.25) var flight_seconds:=7.5
@export var interval_seconds:=Vector2(42,65)
var remaining:=22.0
var age:=-1.0
var direction:=Vector3.RIGHT
var origin:=Vector3.ZERO
var paint: ShaderMaterial
var random:=RandomNumberGenerator.new()
var flights:=0
func _ready() -> void:
 name="DistantSkyComet"
 random.randomize()
 var quad:=QuadMesh.new()
 quad.size=Vector2(148,11)
 mesh=quad
 paint=ShaderMaterial.new()
 paint.shader=preload("res://modules/maze03_final/sky_comet.gdshader")
 material_override=paint
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 layers=16
 remaining=random.randf_range(17,25)
 hide()
func play_comet(azimuth: float,elevation: float=0.28) -> void:
 var radial:=Vector3(sin(azimuth),0,cos(azimuth))
 var sideways:=Vector3(radial.z,0,-radial.x)
 direction=(sideways-Vector3.UP*0.35).normalized()
 origin=Vector3(24,5,22.8)+radial*350.0-sideways*55.0+Vector3.UP*(350.0*elevation)
 age=0.0
 flights+=1
 show()
 _position_ribbon()
func _position_ribbon() -> void:
 var head:=origin+direction*(age*23.0)
 global_position=head-direction*59.2
 var camera:=get_viewport().get_camera_3d()
 var toward:=Vector3.UP if camera==null else (camera.global_position-global_position).normalized()
 var up:=toward.cross(direction).normalized()
 global_basis=Basis(direction,up,direction.cross(up))
 var fade_in:=smoothstep(0.0,0.65,age)
 var fade_out:=1.0-smoothstep(flight_seconds-1.6,flight_seconds,age)
 paint.set_shader_parameter("strength",fade_in*fade_out)
 paint.set_shader_parameter("travel",age)
func _process(delta: float) -> void:
 if age>=0.0:
  age+=delta
  _position_ribbon()
  if age>=flight_seconds:
   hide()
   age=-1.0
   remaining=random.randf_range(interval_seconds.x,interval_seconds.y)
   flight_finished.emit()
 else:
  remaining-=delta
  if remaining<=0.0:
   var camera:=get_viewport().get_camera_3d()
   var bearing:=Vector3(0,0,-1) if camera==null else -camera.global_basis.z
   play_comet(atan2(bearing.x,bearing.z)+random.randf_range(-0.18,0.18),random.randf_range(0.24,0.32))

func reset_run() -> void:
 age=-1.0
 flights=0
 remaining=random.randf_range(17,25)
 hide()
