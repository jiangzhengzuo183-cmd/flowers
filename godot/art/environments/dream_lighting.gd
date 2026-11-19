extends Resource
## Lighting preset is independent of all building material resources.
@export var environment: Environment
@export var sun_color := Color(1.0,0.982,0.96)
@export var sun_energy := 0.23
@export var sun_rotation := Vector3(-46,-32,0)
@export var shadow_opacity := 0.39

func apply(world: Node3D) -> void:
	world.get_node("WorldEnvironment").environment = environment.duplicate(true)
	var sun: DirectionalLight3D = world.get_node("Sun")
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.rotation_degrees = sun_rotation
	sun.shadow_opacity = shadow_opacity
	# One directional key light; diffuse environment supplies the gentle fill.
	world.get_node("SoftFill").visible = false
