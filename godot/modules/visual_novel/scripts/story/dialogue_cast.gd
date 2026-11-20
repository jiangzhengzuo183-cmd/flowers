extends RefCounted
const Layout := preload("res://modules/visual_novel/scripts/story/ui_layout.gd")
## 固定双人构图。台词切换只改变亮度，只有参与者变化才出入场。
var host: Control
var layer: Control
var portraits: Dictionary = {}
var fades: Dictionary = {}
var lights: Dictionary = {}
var targets: Dictionary = {}
var current: Array[String] = []
var leaving := false
var generation := 0
var all_dialogues := true
var speaker_names := {"gimpy":"吉姆皮","gimpy_left":"吉姆皮","donner":"唐纳店长","karp":"卡普尔","alice":"爱丽丝"}

func _init(owner: Control) -> void:
	host = owner

func build() -> void:
	layer = Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.cast_layer.add_child(layer)
	var profiles := {
		"charlie_left": [preload("res://modules/visual_novel/assets/bakery/charlie-facing-right.png"), 390.0, 100.0],
		"charlie_right": [preload("res://modules/visual_novel/assets/bakery/charlie-reference.webp"), 1180.0, 100.0],
		"gimpy": [preload("res://modules/visual_novel/assets/bakery/gimpy-reference.webp"), 1160.0, 100.0],
		"gimpy_left": [preload("res://modules/visual_novel/assets/bakery/gimpy-reference.webp"), 390.0, 100.0],
		"donner": [preload("res://modules/visual_novel/assets/bakery/donner-reference.webp"), 390.0, 100.0],
		"karp": [preload("res://modules/visual_novel/assets/bakery/karp-cutout.png"), 390.0, 100.0],
		"alice": [preload("res://modules/visual_novel/assets/bakery/alice-new.png"), 1160.0, 100.0]
	}
	for id: String in profiles:
		var profile: Array = profiles[id]
		var image := TextureRect.new()
		image.texture = profile[0]
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 续剧情中保留查理右侧原位；只镜像无文字、无手持道具的吉姆皮图片。
		image.flip_h = id == "gimpy_left"
		layer.add_child(image)
		var height := 1320.0
		var width := height * image.texture.get_width() / image.texture.get_height()
		image.position = Vector2(profile[1]-width/2.0,profile[2])
		image.size = Vector2(width,height)
		image.hide()
		portraits[id] = image
	layer.hide()

func _participants() -> Array[String]:
	var state: RefCounted = host.flow
	# The exploration artwork already contains Charlie; do not draw a second copy.
	if state.phase=="people":return []
	if state.current_line().speaker.begins_with("查理") and (state.phase!="reading" or state.section in ["classroom","home"]):return ["charlie_left"]
	if state.phase != "reading": return []
	if state.section == "closing": return ["charlie_left","gimpy"]
	if not all_dialogues: return []
	match state.active_person:
		"gimpy": return ["charlie_left","gimpy"]
		"donner": return ["donner","charlie_right"]
		"karp":
			if state.current_line().speaker == "旁白": return ["charlie_right"]
			return ["karp","charlie_right"]
		"alice": return ["charlie_left","alice"]
	if state.active_object == "notebook" and state.return_phase == "objects":
		if state.index >= 13: return ["charlie_right"]
		if state.index >= 8: return ["gimpy_left","charlie_right"]
		return ["karp","charlie_right"]
	if state.current_line().speaker.begins_with("查理"):return ["charlie_left"]
	return []

func _hide_legacy() -> void:
	host.charlie.hide()
	host.people_row.hide()
	host.day01_view.alice_portrait.hide()

func refresh() -> void:
	var passed: bool = host.flow.active_person == "alice" and host.flow.index >= 7
	portraits.charlie_left.texture = preload("res://modules/visual_novel/assets/experience/charlie-empty.png") if passed else preload("res://modules/visual_novel/assets/bakery/charlie-facing-right.png")
	portraits.alice.texture = preload("res://modules/visual_novel/assets/experience/alice-book.png") if passed else preload("res://modules/visual_novel/assets/bakery/alice-new.png")
	refresh_for(_participants(),host.flow.current_line().speaker)

func refresh_for(desired: Array[String], speaker: String) -> void:
	# A single Charlie is a monologue: center on the 1600px design canvas.
	# Restore the original pair positions before the next conversation.
	for id: String in desired:
		var actor: TextureRect = portraits[id]
		var center := Layout.CENTER_ACTOR if desired.size() == 1 else (Layout.LEFT_ACTOR if desired.find(id) == 0 else Layout.RIGHT_ACTOR)
		actor.size = Vector2(1200.0*actor.texture.get_width()/actor.texture.get_height(),1200)
		actor.position.x = center - actor.size.x / 2.0
		actor.position.y = 140
	# Hard cap includes outgoing portraits: a cross-fade must not briefly show 3–4 people.
	if desired.size()>2:desired=desired.slice(0,2)
	for id:String in portraits:
		if id not in desired:
			if fades.has(id):fades[id].kill()
			portraits[id].hide()
	if desired != current:
		generation += 1
		var revision := generation
		current.assign(desired)
		leaving = desired.is_empty()
		for id: String in portraits:
			var actor: TextureRect = portraits[id]
			if id in desired:
				if fades.has(id): fades[id].kill()
				if not actor.visible:
					actor.modulate.a = 0.0
					actor.show()
				fades[id] = host.create_tween()
				fades[id].tween_property(actor,"modulate:a",1.0,0.24)
			elif actor.visible:
				if fades.has(id): fades[id].kill()
				fades[id] = host.create_tween()
				fades[id].tween_property(actor,"modulate:a",0.0,0.22)
				fades[id].tween_callback(actor.hide)
		if leaving:
			host.get_tree().create_timer(0.24).timeout.connect(func() -> void:
				if not is_instance_valid(host) or revision != generation: return
				leaving = false
				layer.hide()
				host._refresh())
	if desired.is_empty():
		if leaving: _hide_legacy()
		return
	layer.show()
	_hide_legacy()
	for id: String in desired:
		var speaking: bool = speaker.begins_with("查理") if id.begins_with("charlie") else speaker == speaker_names.get(id,"")
		var tint := Color.WHITE if speaking or speaker == "旁白" else Color(0.80,0.82,0.81,1)
		if targets.get(id) != tint:
			targets[id] = tint
			if lights.has(id): lights[id].kill()
			lights[id] = host.create_tween()
			lights[id].tween_property(portraits[id],"self_modulate",tint,0.18)
