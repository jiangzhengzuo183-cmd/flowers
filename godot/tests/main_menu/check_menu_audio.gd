extends SceneTree
var checks:=0
var failures:=0
var menu: Control
var capture:=AudioEffectCapture.new()
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func peak() -> float:
	var samples:=capture.get_buffer(capture.get_frames_available())
	var maximum:=0.0
	for pair in samples: maximum=maxf(maximum,maxf(absf(pair.x),absf(pair.y)))
	return maximum
func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720)
	var buses_before:=AudioServer.bus_count
	AudioServer.add_bus_effect(0,capture)
	menu=load("res://modules/main_menu/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	await create_timer(1.65).timeout
	var soundtrack: AudioStreamPlayer=menu.audio.music
	check(soundtrack.playing and soundtrack.stream.loop,"main menu has an active looping music player")
	check(soundtrack.stream!=menu.audio.THEME and not menu.audio.THEME.loop,"the menu's loop settings do not mutate the shared story recording")
	var music_peak:=peak()
	print("MENU_MUSIC_PEAK ",music_peak," gain_db=",soundtrack.volume_db)
	await create_timer(1.4).timeout
	music_peak=maxf(music_peak,peak())
	print("MENU_MUSIC_AFTER_INTRO ",music_peak," position=",soundtrack.get_playback_position()," length=",soundtrack.stream.get_length())
	if menu.audio.target_db>-75.0 and not AudioServer.is_bus_mute(0): check(music_peak>0.0001,"the audio mixer receives a nonzero main-menu music waveform")
	var c: Node2D=menu.companion
	menu.foley.mute_when_unfocused=false
	c.set_enabled(true)
	c.set_process_input(false)
	c.set_process(false)
	c.position=Vector2(630,700)
	c.mouse_position=c.position
	c.last_mouse_position=c.position
	c.velocity=Vector2.ZERO
	c.still_time=0.0
	c.gnaw_completed=false
	c._process(1.49)
	check(c.state!=c.State.GNAW,"a stopped mouse does not gnaw before 1.5 seconds")
	c._process(0.02)
	check(c.state==c.State.GNAW,"a stopped mouse begins gnawing immediately after 1.5 seconds")
	soundtrack.stop()
	menu.foley.voice.stop()
	await create_timer(0.10).timeout
	capture.clear_buffer()
	c._update_gnaw(0.85)
	await create_timer(0.24).timeout
	var bite_peak:=peak()
	print("MENU_BITE_PEAK ",bite_peak," bites=",menu.foley.bites_played)
	if menu.foley.effects_db>-75.0 and not AudioServer.is_bus_mute(0): check(bite_peak>0.0001,"an actual paper-bite waveform is present separately from the stopped music")
	for i in 3:
		c._update_gnaw(0.62)
		await create_timer(0.20).timeout
	check(menu.foley.bites_played==4 and menu.paper.holes.back().bites==4,"all four sound grains correspond to the four real paper bites")
	c._stop_gnaw()
	await create_timer(0.20).timeout
	check(not menu.foley.bite_voice.playing,"paper-bite sound ends when gnawing stops")
	soundtrack.play()
	menu.open_credits()
	await create_timer(0.40).timeout
	check(menu.audio.ducked and absf(soundtrack.volume_db-(menu.audio.target_db-5.0))<0.2,"credits gently lower the menu music without restarting it")
	menu.close_credits()
	await create_timer(0.75).timeout
	check(not menu.audio.ducked and absf(soundtrack.volume_db-menu.audio.target_db)<0.2,"closing credits restores normal menu music")
	menu.queue_free()
	await process_frame
	await process_frame
	check(AudioServer.bus_count==buses_before,"leaving the main menu releases its music and paper-sound bus")
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0,i)==capture:
			AudioServer.remove_bus_effect(0,i)
			break
	var cursor:=root.get_node_or_null("HandDrawnCursor")
	if cursor: cursor.queue_free()
	await process_frame
	print("MENU_AUDIO_RESULTS ",checks," checks; failures=",failures)
	quit(1 if failures else 0)
