extends "res://tests/game_hud/check_stamina_ring.gd"
func run() -> void:
    root.mode=Window.MODE_WINDOWED
    root.size=Vector2i(1280,720)
    root.position=Vector2i(-2600,-1800)
    await pixel_checks()
    print("RING ART checks=",report.size()," failures=",failures)
    quit(failures)
