extends Control
signal finished(result: Dictionary)
signal cancelled
var paused := false
var context: Dictionary
func configure(value: Dictionary) -> void:
	context = value.duplicate(true)
