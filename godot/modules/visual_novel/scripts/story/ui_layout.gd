extends RefCounted
## UI V1.0: 1920x1080 spec mapped to the existing 1600x900 game canvas.
const SCALE := 1.2
const SAFE := 64.0 / SCALE
const DIALOGUE := Rect2(64.0/SCALE,802.0/SCALE,1792.0/SCALE,214.0/SCALE)
const BODY_WIDTH := 1100.0 / SCALE
const BODY_SIZE := 24
const LEFT_ACTOR := 498.0 / SCALE
const RIGHT_ACTOR := 1422.0 / SCALE
const CENTER_ACTOR := 800.0

static func asset_icon(texture: Texture2D, half := -1) -> AtlasTexture:
	var image := texture.get_image()
	var area := Rect2i(Vector2i.ZERO,image.get_size())
	if half >= 0:
		area.size.x /= 2
		area.position.x = area.size.x * half
	var visible := image.get_region(area).get_used_rect()
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(visible.position+area.position,visible.size)
	return atlas
