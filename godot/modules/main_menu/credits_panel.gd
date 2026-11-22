extends "res://modules/main_menu/note_modal.gd"
signal back_requested
var column: VBoxContainer
var scroll: ScrollContainer
var back: Button
func _ready() -> void:
	dimensions = Vector2(980,850)
	super._ready()
	label("制作名单",42)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",11)
	scroll.add_child(column)
	_add_text("灵感来源",28)
	_add_text("丹尼尔·凯斯《献给阿尔吉侬的花束》",24)
	_add_text("本作品以原著为灵感来源，通过互动叙事、空间探索与视觉设计，重新呈现查理的成长经历、认知变化、记忆与情感关系。",23)
	_gap(10)
	_add_text("制作人员",28)
	_add_text("蒋正佐　　李若轩　　肖斯予",25)
	_gap(10)
	_add_text("创作与开发工具",28)
	_add_text("创意构思、文本梳理与设计辅助：ChatGPT\n程序开发与技术实现辅助：Codex\n视觉素材生成与探索：Seedream\n游戏引擎与交互开发：Godot",23)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)
	back = action(row,"返回主界面",func():back_requested.emit())
	cancel_button = back
func _add_text(text: String,font_size: int) -> void:
	var text_label := Label.new()
	text_label.text = text
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_constant_override("line_spacing",5)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Type.apply(text_label,font_size,float(column.get_child_count())+4.0)
	column.add_child(text_label)
func _gap(amount: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = amount
	column.add_child(spacer)
