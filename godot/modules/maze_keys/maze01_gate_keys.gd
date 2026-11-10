extends RefCounted

const COIN := &"LuckyCoin"
const HORSESHOE := &"LuckyHorseshoe"
const ITEMS := {
	COIN: {"label": "幸运钱币", "icon": preload("res://modules/maze_keys/assets/coin.svg"),
		"model": preload("res://modules/maze_keys/assets/lucky_coin.glb"), "size": 0.60, "sparkles": 6},
	HORSESHOE: {"label": "幸运马蹄铁", "icon": preload("res://modules/maze_keys/assets/horseshoe.svg"),
		"model": preload("res://modules/maze_keys/assets/lucky_horseshoe.glb"), "size": 0.71, "tilt": PI * 0.5, "sparkles": 4},
}

# IDs match the map. Door 04 unlocks the optional D2 shortcut.
const GATES := {
	"D1": {"title": "Door 01", "item": COIN, "pickup": Vector3(1.2, 0.0, 42.0),
		"charge": 1.22, "descent": 1.04},
	"D3": {"title": "Door 02", "item": COIN, "pickup": Vector3(36.5, 2.6, 18.0),
		"charge": 1.22, "descent": 1.04},
	"D4": {"title": "Door 03", "item": HORSESHOE, "pickup": Vector3(45.0, 0.0, 22.8),
		"charge": 1.32, "descent": 1.15},
	"D2": {"title": "Door 04", "item": HORSESHOE, "pickup": Vector3(32.4, 0.0, 37.2),
		"charge": 1.22, "descent": 1.04},
}
