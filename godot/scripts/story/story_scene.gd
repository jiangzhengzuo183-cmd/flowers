extends HBoxContainer

signal enter_maze
var lines: Array = []
var index := 0

func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/prologue.json"))
	if data is Dictionary and data.get("lines") is Array:
		lines = data.lines
	%NextButton.pressed.connect(advance)
	%RestartButton.pressed.connect(restart)
	_refresh()

func advance() -> void:
	if lines.is_empty():
		return
	if index < lines.size() - 1:
		index += 1
		_refresh()
	else:
		enter_maze.emit()

func restart() -> void:
	index = 0
	_refresh()

func _refresh() -> void:
	if lines.is_empty():
		%DialogueText.text = "剧情资料读取失败，请检查 data/prologue.json。"
		%NextButton.disabled = true
		return
	%Speaker.text = str(lines[index].get("speaker", "旁白"))
	%DialogueText.text = str(lines[index].get("text", ""))
	%Progress.text = "序章 · %d / %d" % [index + 1, lines.size()]
	%NextButton.text = "继续阅读 ↗" if index < lines.size() - 1 else "进入迷宫 ↗"
