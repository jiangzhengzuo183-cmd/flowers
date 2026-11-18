extends CharacterBody3D
## Behaviour wrapper only. The finished MemoryShade asset owns all visual effects.

signal player_approached(ghost: Node3D, player: CharacterBody3D)
signal guidance_requested(ghost: Node3D)
signal dialogue_requested(ghost: Node3D, player: CharacterBody3D)
signal guidance_started
signal guidance_finished(ghost: Node3D)
signal route_blocked
signal dissolved(ghost: Node3D)
signal state_changed(previous: int, current: int)

enum State { Idle, PlayerDetected, LookAtPlayer, StartGuidance, WalkingToAtlas, Arrived, Dissolving, Dissolved }
@export var guides_to_atlas := false
@export var auto_start_guidance := true
@export_range(0.5, 3.0) var approach_radius := 2.1
@export_range(0.5, 2.0) var look_seconds := 1.0
@export_range(0.3, 1.6) var walk_speed := 0.95

var state: State = State.Idle
var route := PackedVector3Array()
var travelled_distance := 0.0
var approach_count := 0
var arrival_count := 0
var _actor: CharacterBody3D
var _routes: RefCounted
var _destination := Vector3.ZERO
var _statue := Vector3.ZERO
var _spawn := Transform3D.IDENTITY
var _look_remaining := 0.0
var _route_index := 1
var _waiting_for_route := false
var _retry := 0.0
var _blocked_reported := false
var _installed := false
var _approach_latched := false
@onready var shade: Node3D = $Shade
@onready var approach: Area3D = $Approach

func _ready() -> void:
	(approach.get_node("CollisionShape3D").shape as SphereShape3D).radius = approach_radius
	approach.body_entered.connect(_body_entered)
	$WindDissolve.finished.connect(func():
		_change_state(State.Dissolved)
		dissolved.emit(self))
	# These are already instance-owned by MemoryShade; the original material is untouched.
	shade.opacity = 0.33
	shade.garment_opacity = 0.56
	shade.hair_opacity = 0.47
	shade.surface_material.set_shader_parameter("body_color", Color(0.13, 0.58, 1.0))
	shade.surface_material.set_shader_parameter("rim_color", Color(0.47, 0.86, 1.0))
	shade.surface_material.set_shader_parameter("rim_strength", 0.40)
	var halo: Material = shade.surface_material.next_pass
	while halo is ShaderMaterial:
		halo.set_shader_parameter("glow_color", Color(0.15, 0.62, 1.0))
		halo.set_shader_parameter("strength", float(halo.get_shader_parameter("strength")) * 1.35)
		halo = halo.next_pass
	shade.set_state(2) # Existing slow look_around loop, with its original motion FX.

func configure(actor: CharacterBody3D, routes: RefCounted, destination: Vector3, statue: Vector3) -> void:
	_actor = actor
	_routes = routes
	_destination = destination
	_statue = statue
	_spawn = transform
	_installed = true
	reset_event()

func reset_event() -> void:
	transform = _spawn
	velocity = Vector3.ZERO
	state = State.Idle
	route.clear()
	travelled_distance = 0.0
	approach_count = 0
	arrival_count = 0
	_look_remaining = 0.0
	_waiting_for_route = false
	_blocked_reported = false
	_retry = 0.0
	_approach_latched = false
	$WindDissolve.reset_effect()
	shade.show()
	shade.particles_enabled = true
	shade.set_state(2)
	if guides_to_atlas:
		$WindDissolve.prepare(shade)

func begin_wind_dissolve() -> void:
	if not guides_to_atlas or state != State.Arrived:
		return
	_change_state(State.Dissolving)
	$WindDissolve.play(shade)

func _body_entered(body: Node3D) -> void:
	if not _installed or body != _actor or not _actor.controls_enabled:
		return
	if not _can_see_player():
		return
	if not guides_to_atlas:
		if _approach_latched:
			return
		_approach_latched = true
		player_approached.emit(self, _actor)
		dialogue_requested.emit(self, _actor) # Reserved signal; no dialogue listener is installed.
		return
	if state != State.Idle:
		return
	approach_count += 1
	_change_state(State.PlayerDetected)
	player_approached.emit(self, _actor)
	_change_state(State.LookAtPlayer)
	_look_remaining = look_seconds

func _can_see_player() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0,
		_actor.global_position + Vector3.UP * 1.0, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Future VN integration: set auto_start_guidance=false, connect guidance_requested
## to the dialogue, then call this method from its completion event.
func start_guidance() -> void:
	if not guides_to_atlas or state != State.LookAtPlayer or _look_remaining > 0.0:
		return
	_change_state(State.StartGuidance)
	_waiting_for_route = true
	_try_route()

func _try_route() -> void:
	if not _routes.ready:
		return
	var candidate: PackedVector3Array = _routes.path_to_nearest(global_position,
		PackedVector3Array([_destination]))
	if candidate.size() < 2:
		_report_blocked()
		return
	# Remove redundant grid corners only when the existing capsule sweep allows it.
	route = PackedVector3Array([candidate[0]])
	var anchor := 0
	while anchor < candidate.size() - 1:
		var next := anchor + 1
		for i in range(anchor + 2, candidate.size()):
			if _routes.can_step(candidate[anchor], candidate[i]):
				next = i
			else:
				break
		route.append(candidate[next])
		anchor = next
	_route_index = 1
	_waiting_for_route = false
	_blocked_reported = false
	_change_state(State.WalkingToAtlas)
	shade.set_state(1)
	# Source walk travels 1.210926 asset units in its 2.375s cycle.
	var clip: Animation = shade.player.get_animation(shade.player.current_animation)
	shade.player.speed_scale = walk_speed / (1.210926 * shade.scale.x / clip.length)
	guidance_started.emit()

func _physics_process(delta: float) -> void:
	if not _installed:
		return
	if not guides_to_atlas:
		var nearby: bool = _actor.controls_enabled and approach.overlaps_body(_actor) and _can_see_player()
		if nearby and not _approach_latched:
			_body_entered(_actor)
		elif not nearby:
			_approach_latched = false
	if state == State.Idle and guides_to_atlas and _actor.controls_enabled and approach.overlaps_body(_actor):
		_body_entered(_actor)
	if state == State.LookAtPlayer:
		_face(_actor.global_position, delta)
		if _look_remaining > 0.0:
			_look_remaining = maxf(0.0, _look_remaining - delta)
			if _look_remaining == 0.0:
				guidance_requested.emit(self)
				if auto_start_guidance:
					start_guidance()
	if state == State.StartGuidance and _waiting_for_route:
		_retry -= delta
		if _retry <= 0.0:
			_retry = 0.5
			_try_route()
	velocity.x = 0.0
	velocity.z = 0.0
	if state == State.WalkingToAtlas:
		_walk(delta)
	elif state == State.Arrived:
		_face(_statue, delta)
	velocity.y = -2.0 if is_on_floor() else maxf(velocity.y - 18.0 * delta, -10.0)
	var previous := global_position
	move_and_slide()
	if state == State.WalkingToAtlas:
		travelled_distance += Vector2(global_position.x - previous.x, global_position.z - previous.z).length()
		var moved := Vector2(global_position.x - previous.x, global_position.z - previous.z).length()
		shade.player.speed_scale = move_toward(shade.player.speed_scale,
			(moved / delta) / (1.210926 * shade.scale.x / 2.375), delta * 5.0)

func _walk(delta: float) -> void:
	var next := route[_route_index]
	var direction := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	if direction.length() < 0.055:
		_route_index += 1
		if _route_index >= route.size():
			_change_state(State.Arrived)
			shade.set_state(2)
			arrival_count += 1
			guidance_finished.emit(self)
			return
		next = route[_route_index]
		direction = Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	# Live collision is checked by move_and_slide; never teleport through obstacles.
	var speed := minf(walk_speed, direction.length() / delta)
	var horizontal := direction.normalized() * speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_face(next, delta)
	if get_slide_collision_count() > 0 and not is_on_floor():
		_report_blocked()

func _face(point: Vector3, delta: float) -> void:
	var offset := point - global_position
	if Vector2(offset.x, offset.z).length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(offset.x, offset.z), 1.0 - exp(-delta * 5.0))

func _report_blocked() -> void:
	if not _blocked_reported:
		_blocked_reported = true
		route_blocked.emit()
		push_warning("Maze02 church ghost has no safe route to Atlas; it will wait and retry without changing geometry.")

func _change_state(next: State) -> void:
	var previous := state
	state = next
	state_changed.emit(previous, next)
