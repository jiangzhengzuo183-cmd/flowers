extends "res://scripts/levels/greybox_scene.gd"
## One space, per-instance run state. Does not modify Layout.config() or geometry.

signal run_completed(run_id: String, result: Dictionary)
signal run_reset(run_id: String)
signal gate_activated(run_id: String, gate_id: String)

const RunConfig := preload("res://scripts/maze_runs/maze_run_config.gd")
@export var run_config: RunConfig
var _settings: Dictionary = {}
var _configured := false
var _exit_area: Area3D

func _ready() -> void:
	if run_config == null:
		run_config = RunConfig.new()
	var errors := run_config.validation_errors()
	if not errors.is_empty():
		%Status.text = "运行配置错误："+"；".join(errors)
		push_error(%Status.text)
		set_process(false)
		set_process_unhandled_key_input(false)
		return
	_settings = run_config.snapshot()
	super()
	if not loaded_ok:
		return
	# Environment resources loaded from a PackedScene may be shared.
	var environment: Environment = _settings.environment
	%WorldEnvironment.environment = environment if environment else %WorldEnvironment.environment.duplicate(true)
	var world := %Player.get_parent()
	world.get_node("Sun").light_energy = _settings.sun_energy
	world.get_node("SoftFill").light_energy = _settings.fill_energy
	_exit_area = world.get_node("ExitTrigger")
	_configured = true
	get_node("Heading").text = _settings.display_name+" · Maze 01"
	%Summary.text = "共用最终灰模结构 / 当前为三次运行基础框架"
	inspection_picker.visible = _settings.show_debug_tools
	for button: Button in [%HideRoute,%RouteA,%RouteB]:
		button.visible = _settings.show_debug_tools
	_apply_initial_gates()
	_refresh_hud()

func _apply_initial_gates() -> void:
	for id: String in %GeneratedMaze.gates:
		var open := bool(_settings.initial_gate_states.get(id,false))
		%GeneratedMaze.gates[id].set_open_state(open)
		%GeneratedMaze.switches[id].set_used(open)

func try_activate_gate(id: String) -> bool:
	if not _configured or completed or not %GeneratedMaze.gates.has(id):
		return false
	if not bool(_settings.gate_interaction_enabled.get(id,true)):
		return false
	if %GeneratedMaze.gates[id].is_open:
		return false
	# This is a rule interface; proximity and line of sight stay in the E handler.
	if not super(id):
		return false
	gate_activated.emit(str(_settings.run_id),id)
	return true

func can_finish() -> bool:
	if not _configured:
		return false
	for id: String in _settings.required_exit_gates:
		if not %GeneratedMaze.gates[id].is_open:
			return false
	return true

func complete_level() -> void:
	if completed or not can_finish():
		return
	super()
	run_completed.emit(str(_settings.run_id),get_run_state())

func _process(delta: float) -> void:
	if not _configured:
		return
	super(delta)
	# Reevaluate if the last required gate opens while Charlie is in the exit.
	if not completed and can_finish() and _exit_area.overlaps_body(%Player):
		complete_level()

func reset_level() -> void:
	if not _configured:
		return
	_stop_run_audio()
	super()
	_apply_initial_gates()
	_refresh_hud()
	run_reset.emit(str(_settings.run_id))

func _exit_tree() -> void:
	_stop_run_audio()

func _stop_run_audio() -> void:
	# A detached run must not leave an opening chime playing into the next run.
	for sound: AudioStreamPlayer in find_children("*","AudioStreamPlayer",true,false):
		sound.stop()
		sound.queue_free()

func get_run_state() -> Dictionary:
	var gates: Dictionary = {}
	var switches: Dictionary = {}
	for id: String in %GeneratedMaze.gates:
		gates[id] = %GeneratedMaze.gates[id].is_open
		switches[id] = %GeneratedMaze.switches[id].used
	return {"run_id":str(_settings.get("run_id","")),"completed":completed,"gates":gates,"switches":switches}

func _refresh_hud() -> void:
	super()
	if not _configured:
		return
	var hint := "靠近同号开关按 E；机关状态仅属于本次运行。"
	if is_instance_valid(closest_switch):
		var id: String = closest_switch.gate_id
		hint = "按 E 打开 "+id if bool(_settings.gate_interaction_enabled.get(id,true)) else id+" 本次不可操作"
	if completed:
		hint = "本次迷宫已完成；可重试，或使用上方按钮进入下一次。"
	var parts: Array[String] = []
	for id: String in %GeneratedMaze.gates:
		parts.append(id+(" 已开" if %GeneratedMaze.gates[id].is_open else " 关闭"))
	%Status.text = " / ".join(parts)+" · "+hint
