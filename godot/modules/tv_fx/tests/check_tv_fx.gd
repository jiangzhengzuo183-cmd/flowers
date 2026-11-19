extends SceneTree

var failures := 0
var captures := false
var output_dir := ""

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func capture(label: String) -> void:
	if not captures:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output_dir.path_join(label + ".png")) == OK, "Save " + label)

func run_checks() -> void:
	captures = OS.get_cmdline_user_args().has("--capture")
	output_dir = ProjectSettings.globalize_path("res://../.verification/tv_fx")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1280, 900)
	check(FileAccess.get_sha256("res://modules/tv_fx/assets/retro_monitor.glb") == "0900aedd158e367243393e9215ecfbb85309ef33b47764481388a404d1517819", "Original GLB bytes unchanged")
	var scene = load("res://modules/tv_fx/tv_fx_preview.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var tv = scene.tv
	tv.animation_paused = true
	check(tv.source_mesh != null and tv.screen_overlay != null, "Source model and separate overlay exist")
	check(tv.source_mesh.material_override == null, "No source material override")
	check(tv.source_mesh.get_surface_override_material(0) == null, "No source surface override")
	check(tv.source_mesh.mesh.get_surface_count() == 1, "Source surface count preserved")
	check(tv.get_node("Model").transform == Transform3D.IDENTITY, "Source model transform preserved")
	check(tv.screen_overlay.mesh.surface_get_array_len(0) > 300, "Curved screen triangles extracted")
	print("OVERLAY TRIANGLES: ", tv.screen_overlay.mesh.surface_get_array_len(0) / 3)
	var overlay_arrays: Array = tv.screen_overlay.mesh.surface_get_arrays(0)
	var uv2: PackedVector2Array = overlay_arrays[Mesh.ARRAY_TEX_UV2]
	check(uv2.size() == overlay_arrays[Mesh.ARRAY_VERTEX].size(), "Continuous screen UV2 exists")
	check(tv.symbols.get_child_count() == 2, "Exactly two independent lightning symbols")
	for bolt in tv.symbols.get_children():
		check(bolt.texture.resource_path.ends_with("bolt.svg"), "Only lightning texture used")
		check(bolt.scale.x > 3.0, "Lightning enlarged and visible")
	check(tv.symbols.get_child(0).scale.x > tv.symbols.get_child(1).scale.x, "Left lightning larger than right")
	check(tv.symbols.get_child(0).position.y > tv.symbols.get_child(1).position.y + 10.0, "Lightning heights asymmetric")
	check(tv.symbols.get_child(0).rotation.z * tv.symbols.get_child(1).rotation.z < 0.0, "Lightning leans opposite directions")

	var twin = load("res://modules/tv_fx/tv_fx.tscn").instantiate()
	scene.add_child(twin)
	twin.visible = false
	check(twin.screen_material != tv.screen_material, "Materials isolated between TV instances")
	tv.set_intensity(2.0)
	check(tv.intensity == 1.0 and twin.intensity == 0.45, "Intensity clamped and instances independent")
	tv.set_intensity(0.45)
	tv.set_symbols_enabled(false)
	check(not tv.symbols.visible and tv.screen_overlay.visible, "Symbols toggle independently")
	tv.set_symbols_enabled(true)
	tv.set_effects_enabled(false)
	scene.effects_button.set_pressed_no_signal(false)
	scene.pause_button.set_pressed_no_signal(true)
	check(not tv.symbols.visible and not tv.screen_overlay.visible, "Original-only mode hides all added effects")
	scene._front_view()
	await capture("01_original")
	tv.set_effects_enabled(true)
	scene.effects_button.set_pressed_no_signal(true)
	tv.set_blue_glow_enabled(false)
	tv.set_intensity(0.0)
	check(not tv.screen_overlay.visible, "Zero intensity restores original screen")
	tv.set_intensity(0.45)
	tv.effect_time = 1.25
	tv._sync_effects()
	await capture("02_crt_front")
	var frozen_time: float = tv.effect_time
	tv._process(0.25)
	check(tv.effect_time == frozen_time, "Pause freezes shader and symbol clock")
	tv.trigger_burst(0.8)
	check(tv.burst_remaining > 0.0, "Burst starts")
	await capture("03_burst")
	tv.animation_paused = false
	tv._process(1.0)
	check(tv.burst_remaining == 0.0, "Burst returns to normal")
	tv.animation_paused = true
	tv.effect_time = 2.1
	tv._sync_effects()
	await capture("04_later_frame")
	if captures:
		_check_pixels()
	tv.set_blue_glow_enabled(true)
	tv._sync_effects()
	check(tv.halo.visible and tv.blue_light.visible, "Blue halo and local spill enabled")
	var first_glow: float = tv.screen_material.get_shader_parameter("blue_glow")
	tv.effect_time += 0.4
	tv._sync_effects()
	check(not is_equal_approx(first_glow, tv.screen_material.get_shader_parameter("blue_glow")), "Blue glow flickers with the screen clock")
	await capture("07_blue_glow")
	tv.trigger_burst()
	await capture("08_blue_burst")
	tv.burst_remaining = 0.0
	scene.yaw = 0.65
	scene.pitch = 0.18
	scene._update_camera()
	await capture("05_oblique")
	scene.yaw = PI
	scene.pitch = 0.0
	scene._update_camera()
	await capture("06_back")
	scene._front_view()
	tv.set_symbols_enabled(false)
	tv.snow_enabled = false
	tv.scanlines_enabled = false
	tv.flicker_enabled = false
	tv.content_motion_enabled = false
	tv.set_blue_glow_enabled(false)
	tv._sync_effects()
	check(not tv.screen_overlay.visible, "All screen channels off restores original screen")
	check(not tv.halo.visible and not tv.blue_light.visible, "Blue glow toggle removes halo and spill")
	tv.content_motion_enabled = true
	tv.effect_time = 1.0
	tv._sync_effects()
	await capture("09_content_a")
	tv.effect_time = 1.43
	tv._sync_effects()
	await capture("10_content_b")
	if captures:
		var first := Image.load_from_file(output_dir.path_join("09_content_a.png"))
		var second := Image.load_from_file(output_dir.path_join("10_content_b.png"))
		var changed := 0
		for y in range(260, 440, 2):
			for x in range(510, 770, 2):
				if first.get_pixel(x, y) != second.get_pixel(x, y):
					changed += 1
		check(changed > 200, "Warning artwork moves with content motion alone")
		print("CONTENT MOTION CHANGED PIXELS: ", changed)
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	scene._unhandled_input(wheel)
	check(scene.camera.size < 161.0, "Preview zoom responds")
	twin.queue_free()
	scene.queue_free()
	await process_frame
	print("TV FX CHECK: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)

func _check_pixels() -> void:
	var original := Image.load_from_file(output_dir.path_join("01_original.png"))
	var effect := Image.load_from_file(output_dir.path_join("02_crt_front.png"))
	var later := Image.load_from_file(output_dir.path_join("04_later_frame.png"))
	var housing_changes := 0
	var animated_pixels := 0
	# Front-view lower housing/knobs/feet must remain pixel-identical.
	for y in range(520, 685, 2):
		for x in range(360, 925, 2):
			if original.get_pixel(x, y) != effect.get_pixel(x, y):
				housing_changes += 1
	# Screen is expected to change with the animation clock.
	for y in range(250, 450, 2):
		for x in range(500, 780, 2):
			if effect.get_pixel(x, y) != later.get_pixel(x, y):
				animated_pixels += 1
	check(housing_changes == 0, "Lower housing, knobs and feet pixel-identical")
	check(animated_pixels > 3000, "Rendered screen animation actually changes")
	print("RENDER CHECK: housing changed pixels = ", housing_changes, "; animated screen pixels = ", animated_pixels)
