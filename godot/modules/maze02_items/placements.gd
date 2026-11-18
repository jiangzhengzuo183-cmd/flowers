extends RefCounted
## Ground points projected from the supplied Maze02 top-down markup.

const KEYS := {
	"D1": Vector3(1.20, 0.0, 39.60),
	"D2": Vector3(27.60, 0.0, 37.20),
	"D3": Vector3(34.80, 0.0, 13.20),
	"D4": Vector3(32.40, 0.0, 20.40),
}
const CAKES := [Vector3(8.40, 0.90, 13.20), Vector3(44.40, 0.0, 25.20)]
const RABBIT := Vector3(22.80, 0.0, 8.40)
const CAPSULES := [Vector3(13.98, 0.0, 35.05), Vector3(37.48, 0.0, 25.42)]
const TELEVISIONS := [
	{"point": Vector3(8.07, 0.0, 22.50), "yaw": -PI / 4.0,
		"broadcast": preload("res://modules/maze02_items/assets/tv_science_news.mp3")},
	{"point": Vector3(36.92, 0.0, 23.08), "yaw": PI / 4.0,
		"broadcast": preload("res://modules/maze02_items/assets/tv_explorations_hubble.mp3")},
]
