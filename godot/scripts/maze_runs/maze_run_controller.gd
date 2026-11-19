extends VBoxContainer

signal run_finished(run_id: String, result: Dictionary)
const BaseScene := preload("res://scenes/maze_runs/Maze01_Base.tscn")
const Profiles := [preload("res://data/maze_runs/run_01.tres"),preload("res://data/maze_runs/run_02.tres"),preload("res://data/maze_runs/run_03.tres")]
var active_run: Control
var active_index := -1
var results: Dictionary = {}

func _ready() -> void:
	for index in Profiles.size():
		var button := Button.new()
		button.text = Profiles[index].display_name
		button.pressed.connect(start_run.bind(index))
		%RunToolbar.add_child(button)
	%Retry.pressed.connect(retry_run)
	%Next.pressed.connect(next_run)
	start_run(0)

func start_run(index: int) -> bool:
	if index<0 or index>=Profiles.size():
		return false
	var errors: PackedStringArray = Profiles[index].validation_errors()
	if not errors.is_empty():
		%RunStatus.text = "无法开始："+"；".join(errors)
		return false
	# Detach immediately: only one scene can receive input/physics after switching.
	if is_instance_valid(active_run):
		%RunHost.remove_child(active_run)
		active_run.queue_free()
	active_index = index
	results.erase(Profiles[index].run_id)
	active_run = BaseScene.instantiate()
	active_run.run_config = Profiles[index]
	active_run.run_completed.connect(_on_run_completed)
	active_run.run_reset.connect(_on_run_reset)
	%RunHost.add_child(active_run)
	active_run.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	%Next.disabled = true
	%Next.text = "三次检查完成" if index==2 else "下一次"
	%RunStatus.text = Profiles[index].display_name+"：相同空间，独立运行状态。上方可自由切换检查；下一次按钮需通关。"
	get_window().title = "Maze 01 · 三次运行检查"
	return true

func retry_run() -> void:
	if active_index>=0:
		start_run(active_index)

func next_run() -> void:
	if is_instance_valid(active_run) and active_run.completed and active_index<2:
		start_run(active_index+1)

func _on_run_completed(id: String, result: Dictionary) -> void:
	results[id] = result.duplicate(true)
	%Next.disabled = active_index>=2
	%RunStatus.text = Profiles[active_index].display_name+"已完成。"+("可进入下一次。" if active_index<2 else "当前为框架试玩，三次具体机制待设计。")
	run_finished.emit(id,result.duplicate(true))

func _on_run_reset(id: String) -> void:
	results.erase(id)
	%Next.disabled = true
	%RunStatus.text = Profiles[active_index].display_name+"已恢复本轮初始状态。"
