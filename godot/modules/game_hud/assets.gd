extends RefCounted
## Original PNGs remain byte-for-byte intact; slices contain only source pixels.
const ROOT := "res://assets/UI/HUD/"
const ICONS := {"LuckyRabbitFoot":"幸运兔脚.png", "LuckyCoin":"钱币.png", "LuckyHorseshoe":"马蹄铁.png", "ChocolateCake":"蛋糕.png", "PinkCapsule":"粉色药丸.png", "cake":"蛋糕.png", "capsule":"粉色药丸.png"}
const ICON_SLICES := {"LuckyRabbitFoot":"rabbit","LuckyCoin":"coin","LuckyHorseshoe":"horseshoe","ChocolateCake":"cake","PinkCapsule":"capsule","cake":"cake","capsule":"capsule"}
static var cache: Dictionary = {}
static var _hand_font: Font
static func texture(file: String) -> Texture2D:
    if not cache.has(file): cache[file] = load(ROOT + file)
    return cache[file]
static func icon(id: String) -> Texture2D:
    return slice("icon_" + ICON_SLICES[id]) if ICON_SLICES.has(id) else null
static func slice(id: String) -> Texture2D:
    return texture("slices/" + id + ".png")
static func picture(parent: Node, tex: Texture2D, rect: Rect2) -> TextureRect:
    var image := TextureRect.new()
    image.texture = tex
    var paint:=ShaderMaterial.new()
    paint.shader=preload("res://modules/game_hud/sticker.gdshader")
    image.material=paint
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    image.position = rect.position
    image.size = rect.size
    parent.add_child(image)
    return image

static func hand_font() -> Font:
    if _hand_font==null:
        var font: FontFile=load(ROOT+"fonts/HUDHand.ttf")
        font.fallbacks=[load("res://assets/fonts/SourceHanSansSC-Regular.otf") as Font]
        _hand_font=font
    return _hand_font

# Align source artwork, including its transparent margin, to a common visual top.
static var _visible_tops: Dictionary = {}
static func align_visible_top(image: TextureRect, baseline: float = 0.0, strip: Vector2i = Vector2i.ZERO) -> void:
    var tex := image.texture
    if tex == null: return
    var key := str(tex.get_instance_id())+str(strip)
    if not _visible_tops.has(key):
        var pixels := tex.get_image()
        var top := 0
        var found := false
        var left := strip.x if strip.y>strip.x else 0
        var right := strip.y if strip.y>strip.x else pixels.get_width()
        for y in pixels.get_height():
            for x in range(left,right):
                if pixels.get_pixel(x,y).a > 0.125:
                    top=y
                    found=true
                    break
            if found: break
        _visible_tops[key]=top
    var factor := minf(image.size.x/tex.get_width(),image.size.y/tex.get_height())
    var padding := (image.size.y-tex.get_height()*factor)*0.5
    image.position.y=baseline-padding-float(_visible_tops[key])*factor
