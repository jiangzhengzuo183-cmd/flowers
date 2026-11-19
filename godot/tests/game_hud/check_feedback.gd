extends "res://tests/game_hud/check_hud.gd"
func run() -> void:
    root.mode = Window.MODE_WINDOWED
    root.size = Vector2i(1920,1080)
    main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    main.show_scene("maze")
    await ticks(12)
    bind()
    var items = level._items
    var pickup = items.key_pickups.D1
    actor.position = pickup.position+Vector3.UP*0.03
    actor.velocity = Vector3.ZERO
    await ticks(60)
    check(items.inventory.quantity(&"LuckyCoin")==1,"actual key collected for feedback")
    var gate: Node3D = level.get_node("%GeneratedMaze").gates.D1
    actor.position = gate.to_global(Vector3(0,0,1.1))
    actor.velocity = Vector3.ZERO
    await ticks(5)
    await tap(KEY_E)
    await ticks(6)
    check(gate.is_open and items.inventory.quantity(&"LuckyCoin")==0,"real unlock succeeds once")
    var notification := hud.get_node("HUDRoot/CenterBottomNotification")
    var notified: bool = notification.title.text == "机关已激活"
    for entry: Dictionary in notification.queue: notified = notified or entry.title == "机关已激活"
    check(notified,"door activation enters unified notification queue")
    main.show_scene("maze03")
    await ticks(12)
    bind()
    level.race.request_mode("Race")
    while level.race.state != "RACING": await ticks(1)
    actor.position = Vector3(24,0.04,23.6)
    actor.velocity = Vector3.ZERO
    await ticks(8)
    await tap(KEY_E)
    await ticks(65)
    check(level.race.sanctuary_active and hud.status_labels.has("sanctuary"),"real sanctuary status displayed")
    check(hud.status_labels.sanctuary.has_theme_stylebox_override("normal"),"status remains readable on dark vision screen")
    await shot("maze03_sanctuary_hud")
    var file := FileAccess.open(OUT+"feedback-results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"checks":report},"  "))
    file.close()
    print("HUD FEEDBACK failures=",failures)
    main.queue_free()
    await ticks(6)
    quit(failures)
