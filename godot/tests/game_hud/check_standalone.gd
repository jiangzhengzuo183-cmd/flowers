extends "res://tests/game_hud/check_hud.gd"
func run() -> void:
    var paths := ["res://scenes/levels/maze_01_greybox.tscn","res://scenes/levels/Maze02.tscn","res://scenes/levels/Maze03.tscn"]
    for path: String in paths:
        var first: Control = load(path).instantiate()
        root.add_child(first)
        current_scene = first
        await ticks(8)
        check(first.game_hud != null,"standalone installs shared HUD "+path)
        var old := first.get_instance_id()
        first.game_hud.hud.restart_requested.emit()
        await ticks(20)
        var next: Control = current_scene
        check(next.get_instance_id()!=old and next.scene_file_path==path,"standalone restart "+path)
        check(next.game_hud.clock.elapsed<0.5,"standalone clock reset "+path)
        next.game_hud.hud.exit_confirmed.emit()
        await ticks(8)
        check(current_scene.scene_file_path=="res://scenes/levels/MazeSelect.tscn","standalone exit to actual selection "+path)
        var selector := current_scene
        selector.open_maze(2)
        await ticks(8)
        check(selector.active_level.game_hud!=null,"F6 selector hosts HUD")
        selector.active_level.game_hud.hud.exit_confirmed.emit()
        await ticks(8)
        check(selector.active_level==null and selector.get_node("Picker").visible,"F6 selector exit restores picker")
        selector.queue_free()
        await ticks(5)
    var file := FileAccess.open(OUT+"standalone-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"checks":report},"  "))
    file.close()
    print("STANDALONE HUD failures=",failures," checks=",report.size())
    quit(failures)
