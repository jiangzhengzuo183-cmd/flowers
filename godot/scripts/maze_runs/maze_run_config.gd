extends Resource
## Read-only authoring data. Geometry is deliberately not configurable per run.

@export var run_id := "maze_run_01"
@export var display_name := "第一次迷宫"
@export var initial_gate_states: Dictionary = {"D1":false,"D2":false,"D3":false,"D4":false}
@export var gate_interaction_enabled: Dictionary = {"D1":true,"D2":true,"D3":true,"D4":true}
@export var required_exit_gates: Array[String] = ["D1","D3","D4"]
@export var environment_override: Environment
@export_range(0.0, 4.0) var sun_energy := 0.65
@export_range(0.0, 4.0) var fill_energy := 0.45
@export var show_debug_tools := true
# Reserved for later mechanics. Nonempty values are rejected rather than ignored.
@export var item_rules: Dictionary = {}
@export var shadow_rules: Dictionary = {}
@export var countdown_rules: Dictionary = {}
@export var race_rules: Dictionary = {}

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := ["D1","D2","D3","D4"]
	if run_id.strip_edges().is_empty():
		errors.append("运行编号不能为空")
	for values: Dictionary in [initial_gate_states,gate_interaction_enabled]:
		for id: Variant in values:
			if not ids.has(id) or not values[id] is bool:
				errors.append("机关配置必须为 D1–D4 对应的布尔值")
	for id: String in required_exit_gates:
		if not ids.has(id):
			errors.append("出口条件包含未知机关："+id)
		elif not bool(initial_gate_states.get(id,false)) and not bool(gate_interaction_enabled.get(id,true)):
			errors.append("出口所需机关初始关闭且禁止操作："+id)
	for rules: Dictionary in [item_rules,shadow_rules,countdown_rules,race_rules]:
		if not rules.is_empty():
			errors.append("道具、幽影、倒计时和竞速尚未接入；预留配置须保持为空")
	if not is_finite(sun_energy) or not is_finite(fill_energy) or sun_energy<0 or fill_energy<0:
		errors.append("灯光强度必须为有限非负数")
	return errors

func snapshot() -> Dictionary:
	return {
		"run_id":run_id,"display_name":display_name,
		"initial_gate_states":initial_gate_states.duplicate(true),
		"gate_interaction_enabled":gate_interaction_enabled.duplicate(true),
		"required_exit_gates":required_exit_gates.duplicate(),
		"environment":environment_override.duplicate(true) if environment_override else null,
		"sun_energy":sun_energy,"fill_energy":fill_energy,
		"show_debug_tools":show_debug_tools,
	}
