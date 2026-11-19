extends Node3D
## Independent geometry around the screen; never painted into the TV texture.

const BOLT := preload("assets/bolt.svg")
const ANCHORS := [Vector2(-62, 89), Vector2(59, 63)]
var sprites: Array[Sprite3D] = []
var is_enabled := true
var strength := 1.0

func _ready() -> void:
	for i in ANCHORS.size():
		var sprite := Sprite3D.new()
		sprite.name = "NoiseSymbol%d" % (i + 1)
		sprite.texture = BOLT
		sprite.pixel_size = 0.115
		sprite.shaded = false
		sprite.double_sided = false
		sprite.no_depth_test = false
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sprite)
		sprites.append(sprite)
	update_animation(0.0, 0.0, 0.45)

func update_animation(time: float, burst: float, intensity: float) -> void:
	visible = is_enabled
	for i in sprites.size():
		var sprite := sprites[i]
		var phase := fmod(time * (0.65 + i * 0.04) + i * 0.23, 1.0)
		var envelope := 0.5 + 0.5 * smoothstep(0.0, 0.1, phase) * (1.0 - smoothstep(0.75, 0.95, phase))
		var amount := maxf(envelope, burst * 0.9)
		var anchor: Vector2 = ANCHORS[i]
		var push := burst * 8.0
		var tick := floorf(time * 15.0)
		var shake := sin(tick * 9.17 + i * 31.0) * (0.3 + burst * 1.1)
		sprite.position = Vector3(48.0, anchor.y + sin(time * 2.4 + i) * 1.3 + shake, -anchor.x - signf(anchor.x) * push)
		sprite.rotation = Vector3(0, PI / 2.0, 0)
		sprite.rotate_object_local(Vector3.FORWARD, sin(tick * 1.3 + i) * 0.07 + (-0.85 if i == 0 else 0.48))
		var side_scale := 1.03 if i == 0 else 0.78
		sprite.scale = Vector3.ONE * (3.4 + amount + burst * 0.35) * side_scale * lerpf(0.7, 1.0, strength)
		sprite.modulate.a = (0.72 + amount * (0.18 + intensity * 0.1)) * strength
		sprite.visible = amount > 0.01
