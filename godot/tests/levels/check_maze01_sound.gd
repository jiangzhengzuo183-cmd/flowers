extends "res://tests/art_samples/check_art_sample.gd"

const Level := preload("res://scenes/levels/maze_01_greybox.tscn")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")

func run() -> void:
	scene = Level.instantiate()
	# Exercise the optional doctor animation even while the Maze 01 instance is disabled.
	scene.finish_doctor_enabled = true
	root.add_child(scene)
	await ticks(12)
	var actor: CharacterBody3D = scene.get_node("%Player")
	var camera := Camera3D.new()
	actor.get_parent().add_child(camera)
	actor.movement_camera = camera
	var sound: Node = scene.sound
	var music: AudioStreamPlayer = sound.get_node("Music")
	var steps: AudioStreamPlayer = sound.get_node("Footsteps")
	var motion: AudioStreamPlayer = sound.get_node("JumpAndLanding")
	var gate: AudioStreamPlayer = sound.get_node("D1Slide")
	var ending: AudioStreamPlayer = sound.get_node("ExitCue")
	var trail: Node3D = scene.footprints
	check(music.playing and music.stream.get_length() > 50.0 and music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "The main level starts its looping score")
	check(steps.stream == null and motion.stream == null and gate.stream == null, "An idle player starts no transient sounds")

	actor.position.x = 1.83
	sound.sync_actor()
	key(KEY_D, true)
	await ticks(48)
	key(KEY_D, false)
	check(steps.stream == null, "Pushing into the entry wall does not make footsteps")
	scene.reset_walk()
	await ticks(4)
	key(KEY_W, true)
	await ticks(24)
	check(steps.stream == null, "Walking is silent")
	check(not trail.find_children("Shoeprint*", "MeshInstance3D", false, false).any(func(mark: MeshInstance3D): return mark.visible), "Walking leaves no prints")
	key(KEY_SHIFT, true)
	await ticks(24)
	check(steps.stream.resource_path.contains("/run_stone_"), "Running plays the dedicated recorded contacts")
	check(trail.find_children("RunningDust*", "CPUParticles3D", false, false).any(func(dust: CPUParticles3D): return dust.emitting), "Running creates light dust")
	key(KEY_SPACE, true)
	await ticks(3)
	key(KEY_SPACE, false)
	check(motion.stream.resource_path.ends_with("soft_jump_takeoff.wav"), "Actual moving takeoff plays the softer sound")
	await ticks(32)
	check(motion.stream.resource_path.ends_with("soft_jump_landing.wav"), "Actual dry jump landing plays the softer sound")
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	var previous_run_contact := steps.stream

	scene.inspect_location(8)
	await ticks(12)
	actor.movement_camera = camera
	key(KEY_A, true)
	await ticks(26)
	key(KEY_A, false)
	check(steps.stream == previous_run_contact, "Walking in the pool starts no new contact sound")
	scene.inspect_location(8)
	await ticks(7)
	actor.movement_camera = camera
	key(KEY_SHIFT, true)
	key(KEY_A, true)
	await ticks(24)
	key(KEY_A, false)
	key(KEY_SHIFT, false)
	check(steps.stream.resource_path.contains("/water_run_soft_") and steps.volume_db < -14.0,
		"Running through the pool plays the softer water steps")
	key(KEY_SPACE, true)
	await ticks(3)
	key(KEY_SPACE, false)
	check(motion.stream.resource_path.ends_with("water_jump_soft_takeoff.wav"), "Jumping out of shallow water has its own quiet push-off")
	await ticks(36)
	check(motion.stream.resource_path.ends_with("water_jump_soft_landing.wav"), "Landing in the pool plays a separate soft splash")

	var generated: Node3D = scene.get_node("%GeneratedMaze")
	generated.gates.D1.open_gate()
	check(not gate.playing, "The lowering sound waits for the charge sequence")
	await ticks(64)
	check(sound.get_node("D1Start").playing and not gate.playing, "Low mechanical sound accompanies release before the panel moves")
	await ticks(16)
	check(gate.playing and gate.stream.resource_path.ends_with("gate_lowering.wav"), "Existing friction sound starts on descent")
	scene.reset_level()
	await ticks(4)
	check(not gate.playing and music.playing, "Reset stops the gate sound while keeping the score")
	var doctor := actor.get_parent().get_node("FinishDoctor")
	var animation := doctor.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var skeleton := doctor.find_child("Skeleton3D",true,false) as Skeleton3D
	var hand := skeleton.find_bone("L_Hand")
	check(animation.current_animation == &"pose/Standing" and skeleton.get_bone_global_pose(hand).origin.y < 0.47,
		"The doctor waits in a relaxed standing pose")
	var foot_span := absf(skeleton.get_bone_global_pose(skeleton.find_bone("L_Foot")).origin.z
		- skeleton.get_bone_global_pose(skeleton.find_bone("R_Foot")).origin.z)
	var hand_span := absf(skeleton.get_bone_global_pose(hand).origin.z
		- skeleton.get_bone_global_pose(skeleton.find_bone("R_Hand")).origin.z)
	check(foot_span > 0.17 and hand_span > 0.21, "The doctor stands with relaxed, slightly separated limbs")
	actor.position = Layout.cell_point([0,18],0.04)
	await ticks(6)
	check(not scene.completed and animation.current_animation == &"pose/Standing",
		"Arriving before the required gates are open leaves the doctor standing")
	scene.reset_level()
	await ticks(6)
	for id: String in ["D1", "D3", "D4"]:
		generated.gates[id].open_gate()
	actor.position = Layout.cell_point([0,18],0.04)
	actor.velocity = Vector3.ZERO
	await ticks(6)
	check(scene.completed and ending.stream.resource_path.ends_with("exit_bloom.wav"), "Reaching the actual exit plays the completion cue")
	await ticks(28)
	check(animation.current_animation == &"clap_001" and skeleton.get_bone_global_pose(hand).origin.y > 0.52,
		"The original encouragement animation plays when Charlie completes the exit")
	await ticks(255)
	check(animation.current_animation == &"pose/Standing", "The doctor returns to standing after clapping")
	check(not generated.has_node("Entry") and not generated.has_node("Exit"), "Playable scene contains no entry or exit discs")
	sound.set_muted(true)
	check(not music.playing and not ending.playing, "The sound switch mutes score and cues")
	scene.reset_level()
	await ticks(6)
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	await ticks(24)
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	check(not steps.playing and trail.find_children("Shoeprint*", "MeshInstance3D", false, false).any(func(mark: MeshInstance3D): return mark.visible), "Mute does not turn off running footprints")
	await ticks(154)
	check(not trail.find_children("Shoeprint*", "MeshInstance3D", false, false).any(func(mark: MeshInstance3D): return mark.visible), "Footprints disappear naturally")
	sound.set_muted(false)
	check(music.playing, "Turning sound back on starts the score")
	scene.queue_free()
	await ticks()
	print("MAZE 01 SOUND: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(failures)
