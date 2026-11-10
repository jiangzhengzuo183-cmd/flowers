extends RefCounted

static func sprite(parent: Node3D, diameter: float, tint: Color, billboard: bool = true) -> MeshInstance3D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.53, 1.0])
	gradient.colors = PackedColorArray([tint, Color(tint, tint.a * 0.66), Color(tint, tint.a * 0.17), Color(tint, 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 48
	texture.height = 48
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	material.billboard_keep_scale = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * diameter
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
