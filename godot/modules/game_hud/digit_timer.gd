extends Control
## Fixed slots, original glyph proportions. No gameplay clock lives in this widget.
const Layout := preload("res://modules/game_hud/layout_metrics.gd")
const Art := preload("res://modules/game_hud/assets.gd")
@export var backing: Texture2D
var slots: Array[TextureRect] = []
var seconds := -1
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if backing != null: Art.picture(self, backing, Rect2(Vector2.ZERO, size))
    for i in 5:
        var width := 32.0 if i == 2 else 52.0
        var x: float = [0.0, 52.0, 104.0, 136.0, 188.0][i]
        slots.append(Art.picture(self, Art.texture("timer_bold/"+("colon" if i == 2 else "digit_0")+".png"), Rect2(x,0,width,Layout.TIMER_SIZE.y)))
    for image in slots:image.material=null
    set_time(0.0)
func set_time(value: float) -> void:
    var next := maxi(0, floori(value))
    if next == seconds or slots.is_empty(): return
    seconds = next
    var stamp := "%02d%02d" % [mini(99, seconds / 60), seconds % 60]
    for i in 4:
        slots[[0,1,3,4][i]].texture = Art.texture("timer_bold/digit_" + stamp[i]+".png")
    for image in slots: Art.align_visible_top(image)
