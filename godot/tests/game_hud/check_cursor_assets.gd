extends "res://tests/game_hud/check_cursor_timer_dance.gd"
func run() -> void:
    asset_checks()
    print("CURSOR TIMER ASSETS checks=",report.size()," failures=",failures)
    quit(failures)
