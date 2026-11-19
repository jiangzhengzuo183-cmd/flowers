extends RefCounted
## Lighting only: all existing floor and fin materials remain untouched.
const F := preload("res://modules/maze03_final/architecture_forms.gd")
const CENTER := Vector3(24,0,22.8)
static func install(temple: Node3D,_sun: DirectionalLight3D) -> void:
	_shadow_shell(temple)
	var shaft: SpotLight3D = temple.get_node("OculusBlueShaftLight")
	shaft.light_color = Color("d8f4ff")
	shaft.light_energy = 1.25
	shaft.spot_angle = 12.0
	shaft.shadow_enabled = true
	shaft.shadow_opacity = 0.75
	shaft.shadow_bias = 0.035
	var indoor := preload("res://modules/maze03_final/interior_camera_light.gd").new()
	temple.add_child(indoor)
static func _shadow_shell(temple: Node3D) -> void:
	var st := F.surface()
	for side in 4:
		var poly := PackedVector2Array([Vector2(-3.5,0),Vector2(3.5,0),Vector2(0.77,10.3),Vector2(-0.77,10.3)])
		if side in [0,2]:
			poly = PackedVector2Array([Vector2(-3.5,0),Vector2(-0.98,0),Vector2(-0.98,2.65),Vector2(0.98,2.65),Vector2(0.98,0),Vector2(3.5,0),Vector2(0.77,10.3),Vector2(-0.77,10.3)])
		var triangles := Geometry2D.triangulate_polygon(poly)
		for i in range(0,triangles.size(),3):
			var points := PackedVector3Array()
			for j in 3:
				var p := poly[triangles[i+j]]
				points.append(CENTER+Vector3(p.x,p.y,-lerpf(3.5,0.77,p.y/10.3)).rotated(Vector3.UP,-side*PI/2.0))
			var normal := Vector3(0,0.25,-1).rotated(Vector3.UP,-side*PI/2.0).normalized()
			F.face(st,points,normal)
	var shadow := F.finish(temple,"InteriorShadowLiner",st,StandardMaterial3D.new())
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY



