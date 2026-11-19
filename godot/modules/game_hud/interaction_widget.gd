extends PanelContainer
## Format the level's existing interaction message; no activation or inventory rules live here.
var text := ""
var keycap: PanelContainer
var title: Label
var detail: Label
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var paper:=StyleBoxFlat.new()
    paper.bg_color=Color("fff8e9f2")
    paper.set_corner_radius_all(14)
    paper.content_margin_left=10
    paper.content_margin_right=10
    paper.content_margin_top=6
    paper.content_margin_bottom=6
    add_theme_stylebox_override("panel",paper)
    var row:=HBoxContainer.new()
    row.alignment=BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation",10)
    row.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(row)
    keycap=PanelContainer.new()
    keycap.mouse_filter=Control.MOUSE_FILTER_IGNORE
    keycap.custom_minimum_size=Vector2(30,30)
    var yellow:=StyleBoxFlat.new()
    yellow.bg_color=Color("f5ce63")
    yellow.set_corner_radius_all(10)
    keycap.add_theme_stylebox_override("panel",yellow)
    row.add_child(keycap)
    var letter:=Label.new()
    letter.text="E"
    letter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    letter.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    letter.add_theme_font_size_override("font_size",22)
    letter.mouse_filter=Control.MOUSE_FILTER_IGNORE
    keycap.add_child(letter)
    title=Label.new()
    title.add_theme_font_size_override("font_size",20)
    title.mouse_filter=Control.MOUSE_FILTER_IGNORE
    row.add_child(title)
    detail=Label.new()
    detail.add_theme_font_size_override("font_size",19)
    detail.add_theme_color_override("font_color",Color("806d53"))
    detail.mouse_filter=Control.MOUSE_FILTER_IGNORE
    row.add_child(detail)
    set_prompt("")
func set_prompt(value: String) -> void:
    text=value
    visible=not value.is_empty()
    if not visible:return
    keycap.visible=value.begins_with("E")
    detail.text=""
    if value.begins_with("E"):
        title.text="开启" if "解锁" in value else "激活"
    else:
        title.text=value.replace("一枚", "").replace("一件", "")
    detail.hide()
    reset_size()
    size=get_combined_minimum_size()
