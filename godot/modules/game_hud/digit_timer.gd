extends Control
## Fixed slots with one shared ink height and baseline. Gameplay owns the clock.
const Layout := preload("res://modules/game_hud/layout_metrics.gd")
const Art := preload("res://modules/game_hud/assets.gd")
@export var backing: Texture2D
static var glyphs: Array[Texture2D]=[]
static var glyph_height := 64.0
var slots: Array[TextureRect] = []
var seconds := -1
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _prepare_glyphs()
    if backing != null: Art.picture(self, backing, Rect2(Vector2.ZERO, size))
    for i in 5:
        var width := 32.0 if i == 2 else 52.0
        var x: float = [0.0, 52.0, 104.0, 136.0, 188.0][i]
        var image:=Art.picture(self,glyphs[10 if i==2 else 0],Rect2(x,0,width,glyph_height))
        image.material=null
        slots.append(image)
    set_time(0.0)
static func _prepare_glyphs() -> void:
    if not glyphs.is_empty():return
    var widest_ratio:=0.0
    for i in 11:
        var source: Texture2D=Art.texture("timer_bold/"+("colon" if i==10 else "digit_"+str(i))+".png")
        var pixels:=source.get_image()
        var left:=pixels.get_width()
        var top:=pixels.get_height()
        var right:=-1
        var bottom:=-1
        for y in pixels.get_height():
            for x in pixels.get_width():
                if pixels.get_pixel(x,y).a<=0.5:continue
                left=mini(left,x)
                top=mini(top,y)
                right=maxi(right,x)
                bottom=maxi(bottom,y)
        # Ignore the faint remnants of the removed outline; keep one pixel for antialiasing.
        var bounds:=Rect2i(maxi(0,left-1),maxi(0,top-1),right-left+3,bottom-top+3)
        bounds=bounds.intersection(Rect2i(Vector2i.ZERO,pixels.get_size()))
        var glyph:=AtlasTexture.new()
        glyph.atlas=source
        glyph.region=Rect2(bounds)
        glyph.filter_clip=true
        glyphs.append(glyph)
        var ratio:=float(bounds.size.x)/bounds.size.y
        widest_ratio=maxf(widest_ratio,ratio if i<10 else ratio*52.0/32.0)
    # Every glyph fits its fixed slot at exactly the same height, preserving its aspect.
    glyph_height=minf(Layout.TIMER_SIZE.y,floorf(52.0/widest_ratio))
func set_time(value: float) -> void:
    var next := maxi(0, floori(value))
    if next == seconds or slots.is_empty(): return
    seconds = next
    var stamp := "%02d%02d" % [mini(99, seconds / 60), seconds % 60]
    for i in 4:
        slots[[0,1,3,4][i]].texture=glyphs[int(stamp[i])]
