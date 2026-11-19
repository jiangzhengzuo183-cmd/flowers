extends Control
signal back_requested
const FONT := preload("res://assets/fonts/SourceHanSansSC-Regular.otf")
var column: VBoxContainer
var scroll: ScrollContainer
var back: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 17)
	scroll.add_child(column)
	_add_text("制作名单", 40, 24)
	_add_text("灵感来源", 27, 0)
	_add_text("丹尼尔·凯斯《献给阿尔吉侬的花束》", 23, 0)
	_add_text("本作品以原著为灵感来源，通过互动叙事、空间探索与视觉设计，重新呈现查理的成长经历、认知变化、记忆与情感关系。", 22, 14)
	_add_text("制作人员", 27, 0)
	_add_text("蒋正佐　　李若轩　　肖斯予", 23, 15)
	_add_text("创作与开发工具", 27, 0)
	_add_text("创意构思、文本梳理与设计辅助：ChatGPT\n程序开发与技术实现辅助：Codex\n视觉素材生成与探索：Seedream\n游戏引擎与交互开发：Godot", 22, 14)
	back = Button.new()
	back.text = "返回主界面"
	back.add_theme_font_override("font", FONT)
	back.add_theme_font_size_override("font_size", 25)
	back.add_theme_color_override("font_color", Color("322c23"))
	back.add_theme_color_override("font_hover_color", Color("6a5013"))
	back.add_theme_color_override("font_focus_color", Color("322c23"))
	back.add_theme_color_override("font_pressed_color", Color("6a5013"))
	for style in ["normal", "hover", "pressed", "focus"]:
		back.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	back.custom_minimum_size.y = 54
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func(): back_requested.emit())
	column.add_child(back)
	visible = false

func _add_text(text: String, point_size: int, gap: float) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", Color("302920"))
	label.add_theme_constant_override("line_spacing", 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)
	if gap > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size.y = gap
		column.add_child(spacer)

func place(paper: Rect2) -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var unit := paper.size.x / 1920.0
	var width := minf(930.0 * unit, paper.size.x * 0.70)
	scroll.position = paper.position + Vector2((paper.size.x - width) * 0.5, 90.0 * unit)
	scroll.size = Vector2(width, paper.size.y - 170.0 * unit)
