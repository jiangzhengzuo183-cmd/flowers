extends Node
signal changed
signal restored(amount: float, source: StringName)
signal exhausted
signal session_reset
var settings: Resource = preload("res://modules/stamina/default_stamina.tres")
var current: float = 100.0
var is_sprinting := false
var is_recovering := false
var is_exhausted := false
var since_sprint := 0.0
var sprint_seconds := 0.0
var exhaustion_count := 0
var restore_counts: Dictionary = {}
var visited_zones: Array[StringName] = []
var zones: Dictionary = {}
var last_restore_source: StringName = &""
var last_restore_amount := 0.0
var restore_feedback_seconds := 0.0

func reset_session() -> void:
	current = maxf(1.0, settings.maximum)
	is_sprinting = false
	is_recovering = false
	is_exhausted = false
	since_sprint = 0.0
	sprint_seconds = 0.0
	exhaustion_count = 0
	restore_counts.clear()
	visited_zones.clear()
	zones.clear()
	last_restore_source = &""
	last_restore_amount = 0.0
	restore_feedback_seconds = 0.0
	session_reset.emit()
	changed.emit()

func can_sprint() -> bool:
	return current > 0.0 and not is_exhausted

func percentage() -> float:
	return clampf(current / maxf(1.0, settings.maximum), 0.0, 1.0)

func restore(amount: float, source: StringName = &"external") -> float:
	var previous := current
	current = clampf(current + maxf(0.0, amount), 0.0, maxf(1.0, settings.maximum))
	if current >= minf(settings.exhausted_restart, settings.maximum):
		is_exhausted = false
	last_restore_source = source
	last_restore_amount = current - previous
	restore_feedback_seconds = 3.0
	restore_counts[source] = int(restore_counts.get(source, 0)) + 1
	restored.emit(last_restore_amount, source)
	changed.emit()
	return last_restore_amount

func enter_zone(id: int, label: StringName) -> void:
	zones[id] = label
	if label not in visited_zones:
		visited_zones.append(label)
	changed.emit()

func leave_zone(id: int) -> void:
	zones.erase(id)
	changed.emit()

func step(delta: float, sprint_requested: bool, moved: bool, active: bool) -> void:
	is_sprinting = false
	is_recovering = false
	if not active:
		return
	restore_feedback_seconds = maxf(0.0, restore_feedback_seconds - delta)
	if sprint_requested and moved and can_sprint():
		is_sprinting = true
		sprint_seconds += delta
		since_sprint = 0.0
		current = maxf(0.0, current - maxf(0.0, settings.sprint_cost_per_second) * delta)
		if current <= 0.0:
			is_exhausted = true
			exhaustion_count += 1
			exhausted.emit()
	else:
		var delay: float = settings.zone_recovery_delay if not zones.is_empty() else settings.recovery_delay
		var rate: float = settings.zone_recovery_per_second if not zones.is_empty() else settings.recovery_per_second
		var previous_delay := since_sprint
		since_sprint += delta
		var recovery_delta := maxf(0.0, since_sprint - maxf(previous_delay, delay))
		if current < settings.maximum and recovery_delta > 0.0:
			current = minf(settings.maximum, current + maxf(0.0, rate) * recovery_delta)
			is_recovering = rate > 0.0
		if current >= minf(settings.exhausted_restart, settings.maximum):
			is_exhausted = false
	changed.emit()

func debug_state() -> Dictionary:
	return {"current":current, "maximum":settings.maximum, "percent":percentage(),
		"sprinting":is_sprinting, "recovering":is_recovering, "exhausted":is_exhausted,
		"zones":zones.values(), "last_restore":last_restore_source, "last_amount":last_restore_amount,
		"sprint_seconds":sprint_seconds, "exhaustion_count":exhaustion_count,
		"restore_counts":restore_counts.duplicate(), "visited_zones":visited_zones.duplicate()}
