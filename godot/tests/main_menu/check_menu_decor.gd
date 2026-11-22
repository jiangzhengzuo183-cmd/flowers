extends SceneTree
var menu: Control
var checks:=0
var failures:=0
var output:=ProjectSettings.globalize_path("res://../.verification/main-menu/")
func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for i in count: await process_frame
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func shot(name: String) -> Image:
	await frames(1)
	RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image()
	image.save_png(output+name+".png")
	return image
func brown(image: Image,area: Rect2i) -> int:
	var count:=0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var c:=image.get_pixel(x,y)
			if c.r<0.57 and c.g<0.41 and c.b<0.31 and c.r>c.b+0.10: count+=1
	return count
func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.position=Vector2i.ZERO
	root.size=Vector2i(1920,1080)
	menu=load("res://modules/main_menu/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	await frames(250)
	menu.companion.set_enabled(false)
	menu.menu_cursor.set_process_input(false)
	menu.menu_cursor.pointer=Vector2(1710,180)
	var first:=await shot("menu-paper-clean")
	check(menu.get_node_or_null("PencilProp")==null and menu.find_children("*","Node3D",true,false).is_empty(),"the removed pencil and its model viewports are not instantiated")
	check(menu.get_node_or_null("PaperPortraits")==null,"the three retired head doodles are absent")
	var groups: Dictionary={}
	var inner_count:=0
	var p: Node2D=menu.paper
	var mask: Image=p.mask_viewport.get_texture().get_image()
	for hole: Dictionary in p.edge_holes:
		if hole.get("inner",false):
			inner_count+=1
			var at: Vector2=Vector2(hole.uv)*Vector2(1920,1080)
			var nearest:=10000.0
			for side in 4:
				var a: Vector2=p.front_quad[side]
				var b: Vector2=p.front_quad[(side+1)%4]
				nearest=minf(nearest,at.distance_to(Geometry2D.get_closest_point_to_segment(at,a,b)))
			check(nearest>float(hole.radius)*1.4 and mask.get_pixelv(Vector2i(at)).g>0.98,"the small tooth circle is a real enclosed cutout just inside the paper")
		else:
			if not groups.has(hole.cluster): groups[hole.cluster]=[]
			groups[hole.cluster].append(hole)
	check(groups.size()==5 and inner_count==2,"five edge trails and two small nearby internal circles retain ample unbitten edge")
	for group in groups.values():
		var joined:=true
		for i in range(group.size()-1):
			var at: Vector2=(Vector2(group[i].uv)+Vector2(group[i+1].uv))*0.5*Vector2(1920,1080)
			joined=joined and mask.get_pixelv(Vector2i(at)).g>0.95
		check(joined,"adjacent bite marks merge without an internal white seam")
	check(p.holes.is_empty(),"pre-existing edge marks do not consume the eight interactive gnaw sites")
	check(menu.flowers.blooms[4].size.x>250.0 and menu.flowers.blooms[4].get_global_rect().get_center().y>800.0,"one prominent blue flower fills the lower-left corner in place of the head doodles")
	menu.vignette.hide()
	var flat:=await shot("menu-no-vignette-reference")
	menu.vignette.show()
	var shaded:=await shot("menu-vignette-reference")
	var corner_a:=flat.get_pixel(160,160)
	var corner_b:=shaded.get_pixel(160,160)
	check(corner_a.get_luminance()-corner_b.get_luminance()>0.10 and absf(flat.get_pixel(1100,650).r-shaded.get_pixel(1100,650).r)<0.02,"neutral vignette visibly darkens the perimeter while preserving the clear central menu")
	check(absf(corner_b.r/corner_a.r-corner_b.b/corner_a.b)<0.02,"the vignette darkens equally across color channels without a warm tint")
	check(menu.vignette.mouse_filter==Control.MOUSE_FILTER_IGNORE and menu.vignette.get_index()<menu.credits.get_index(),"vignette does not block clicks or darken modal text")
	await check_paw_correction()
	p.holes.clear()
	p._refresh_mask()
	var c: Node2D=menu.companion
	c.set_enabled(true)
	c.set_process_input(false)
	c.set_process(false)
	c.position=Vector2(1230,770)
	c.body_angle=-0.45
	c.velocity=Vector2.ZERO
	c._update_art(0.0)
	await shot("menu-final")
	print("MENU_DECOR_RESULTS ",checks," checks; failures=",failures)
	menu.queue_free()
	await frames(4)
	var cursor:=root.get_node_or_null("HandDrawnCursor")
	if cursor: cursor.queue_free()
	await frames(3)
	quit(1 if failures else 0)
func check_paw_correction() -> void:
	var view:=SubViewport.new()
	view.size=Vector2i(1024,1536)
	view.disable_3d=true
	view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var art:=TextureRect.new()
	art.texture=preload("res://modules/main_menu/assets/mouse_cartoon.png")
	art.size=Vector2(1024,1536)
	art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	view.add_child(art)
	await frames(3)
	RenderingServer.force_draw(false)
	var original:=view.get_texture().get_image()
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
#include "res://modules/main_menu/mouse_pawless.gdshaderinc"
void fragment(){COLOR=mouse_without_paws(texture(TEXTURE,UV),UV);}
"""
	var ink:=ShaderMaterial.new()
	ink.shader=shader
	ink.set_shader_parameter("pawless_art",preload("res://modules/main_menu/assets/mouse_cartoon_pawless.png"))
	art.material=ink
	await frames(3)
	RenderingServer.force_draw(false)
	var corrected:=view.get_texture().get_image()
	corrected.save_png(output+"mouse-no-paws-preview.png")
	var patches: Array[Rect2i]=[Rect2i(292,514,53,59),Rect2i(679,514,54,59),Rect2i(290,908,61,55),Rect2i(676,908,60,55)]
	for rect in patches:
		var removed:=0
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				if original.get_pixel(x,y).a>0.85 and corrected.get_pixel(x,y).a<0.05: removed+=1
		check(removed>50,"one original protruding paw is genuinely removed, rather than painted over the paper")
	var unchanged:=true
	for y in range(0,1536,7):
		for x in range(0,1024,7):
			var edited:=false
			for rect in patches: edited=edited or rect.has_point(Vector2i(x,y))
			if not edited:
				var a:=original.get_pixel(x,y)
				var b:=corrected.get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)+absf(a.a-b.a)>0.02: unchanged=false
	check(unchanged,"face, ears, body grain, whiskers and tail remain unchanged outside the four small paw patches")
	view.queue_free()
	await frames(3)
