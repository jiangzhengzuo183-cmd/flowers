extends HBoxContainer

signal enter_maze
const BAKERY_SCENE := preload("res://scenes/bakery.tscn")
const CONTINUATION := preload("res://scripts/story/continuation_chapter.gd")
var bakery: Control
var completed_day01: RefCounted

func _ready() -> void:
	if "--preview-day02" in OS.get_cmdline_user_args() or "--preview-part3" in OS.get_cmdline_user_args() or "--preview-chapter4" in OS.get_cmdline_user_args(): show_continuation()
	else: show_bakery()

func advance() -> void:
	if is_instance_valid(bakery):
		bakery.advance()

func show_bakery() -> void:
	if is_instance_valid(bakery):
		return
	for child: Node in get_children():
		if child is Control:
			child.hide()
	bakery = BAKERY_SCENE.instantiate()
	add_child(bakery)
	bakery.enter_maze.connect(func() -> void: enter_maze.emit())
	bakery.return_to_story.connect(restart)
	bakery.continue_chapter.connect(show_continuation)

func show_continuation() -> void:
	if is_instance_valid(bakery):
		if bakery.get_script() == CONTINUATION: return
		if not bakery.flow.report_completed: return
		completed_day01 = bakery.flow
		remove_child(bakery)
		bakery.queue_free()
	for child: Node in get_children():
		if child is Control: child.hide()
	bakery = CONTINUATION.new()
	bakery.theme = preload("res://ui/chapter1_theme.tres")
	bakery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bakery.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(bakery)
	bakery.return_to_story.connect(restart)
	bakery.next_button.grab_focus()
	if OS.has_feature("web") and "--report-qa" in OS.get_cmdline_user_args():
		JavaScriptBridge.get_interface("window").flowerReportQA = JSON.stringify({"node":"day02","scene":bakery.narrative.scene().id,"report_completed":completed_day01 != null and completed_day01.report_completed,"history":completed_day01.history.size() if completed_day01 != null else 0})

func restart() -> void:
	completed_day01 = null
	if is_instance_valid(bakery):
		remove_child(bakery)
		bakery.queue_free()
		bakery = null
	show_bakery()
