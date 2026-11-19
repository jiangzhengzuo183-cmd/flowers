extends Resource
## Shared by the local air visuals and ambient sound. No player physics changes.
@export var direction := Vector3(1.0,0.0,-0.42).normalized()
@export_range(3.0,28.0,0.5) var local_speed := 23.0
@export_range(5.0,40.0,0.5) var high_speed := 34.0
@export_range(0.05,0.6,0.01) var visibility := 0.55
@export_range(-42.0,-12.0,0.5) var base_volume_db := -22.5
@export_range(0.0,8.0,0.5) var gust_volume_db := 4.0
func gust_at(time: float) -> float:
	return clampf(0.48+0.30*sin(time*0.63)+0.16*sin(time*1.31+0.8),0.0,1.0)
