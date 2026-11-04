extends "res://scripts/maze/follow_camera.gd"
## Outdoor near-total occlusion may fade walls; the church stays solid.
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
const Room := preload("res://scripts/levels/round_hall.gd")

var _occlusion_pullback := -1.0
var indoor_blend := 0.0
var inside_building := false
var manual_pitch := false

func handle_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
		yaw -= event.relative.x*0.007
		if absf(event.relative.y)>0.001:
			manual_pitch = true
		var profile: Dictionary = Layout.config().camera
		pitch = clampf(pitch+event.relative.y*0.007,deg_to_rad(float(profile.manual_pitch_min_degrees)),deg_to_rad(float(profile.manual_pitch_max_degrees)))
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance/1.18,2.5,150)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance*1.18,2.5,150)
	_update_pose()

func _inside_room() -> bool:
	return is_instance_valid(target) and Room.contains(Vector2(target.position.x,target.position.z),Layout.config().building)

func reset_view() -> void:
	manual_pitch = false
	_occlusion_pullback = -1.0
	inside_building = _inside_room()
	indoor_blend = 1.0 if inside_building else 0.0
	super()

func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(target):
		return
	inside_building = _inside_room()
	indoor_blend = lerpf(indoor_blend,1.0 if inside_building else 0.0,1-exp(-float(Layout.config().camera.transition_speed)*delta))
	var focus := target.position+Vector3(0,lerpf(1.1,0.95,indoor_blend),0)
	var wide := smoothstep(15.0,65.0,distance)*(1-indoor_blend)
	focus = focus.lerp(Vector3(target.map_size.x/2,0,target.map_size.y/2),wide)
	position = position.lerp(focus,1-exp(-12*delta))
	_update_pose()

func _update_pose() -> void:
	if not is_inside_tree() or not is_instance_valid(target):
		return
	var profile: Dictionary = Layout.config().camera
	var inside_distance := clampf(distance*float(profile.indoor_distance_scale),1.6,3.0)
	var view_distance := lerpf(distance,inside_distance,indoor_blend)
	var view_pitch := pitch if manual_pitch else lerpf(pitch,maxf(pitch,1.3),smoothstep(15.0,65.0,distance)*(1-indoor_blend))
	var aim_direction := Vector3(sin(yaw)*cos(view_pitch),sin(view_pitch),cos(yaw)*cos(view_pitch))
	var origin := target.global_position+Vector3(0,lerpf(1.1,0.95,indoor_blend),0) if inside_building else global_position
	var desired := global_position+aim_direction*view_distance-origin
	camera.near = 0.06
	var length := desired.length()
	if length<0.01:
		return
	var direction := desired/length
	var allowed := length
	var solid_hit := false
	# A small camera clearance cross keeps the near plane out of door jambs.
	for offset: Vector3 in [Vector3.ZERO,Vector3.UP*0.12,-Vector3.UP*0.12,camera.global_basis.x*0.12,-camera.global_basis.x*0.12]:
		var query := PhysicsRayQueryParameters3D.create(origin+offset,origin+desired+offset,4)
		query.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			solid_hit = true
			allowed = minf(allowed,maxf(0.12,(origin+offset).distance_to(hit.position)-0.16))
	var required_pullback := length-allowed
	if _occlusion_pullback<0:
		_occlusion_pullback = required_pullback
	else:
		_occlusion_pullback = move_toward(_occlusion_pullback,required_pullback,minf(get_process_delta_time(),0.05)*6.0)
	# Smooth only automatic obstruction correction, never delay manual zoom.
	var actual := maxf(0.12,length-_occlusion_pullback)
	# Never let a smoothing delay carry the camera through masonry or below ground.
	if solid_hit:
		actual = minf(actual,allowed)
	camera.global_position = origin+direction*actual
	camera.look_at(global_position,Vector3.UP)
	var tight := 1.0-smoothstep(0.75,1.5,actual)
	var indoor_fov := lerpf(float(profile.indoor_fov),float(profile.indoor_close_fov),tight)
	camera.fov = lerpf(camera.fov,lerpf(48.0,indoor_fov,indoor_blend),1-exp(-10*get_process_delta_time()))
