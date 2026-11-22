extends SceneTree
func _initialize() -> void:
	var source := Image.load_from_file("res://modules/main_menu/assets/mouse_cartoon.png")
	var used := source.get_used_rect()
	var pivot := Vector2(used.size)*0.5
	var points := PackedVector2Array()
	for y in range(used.position.y,used.end.y,16):
		var left := used.end.x
		var right := -1
		for x in range(used.position.x,used.end.x):
			if source.get_pixel(x,y).a > 0.20:
				left = mini(left,x)
				right = maxi(right,x)
		if right >= left:
			points.append(Vector2(left,y)-Vector2(used.position)-pivot)
			points.append(Vector2(right,y)-Vector2(used.position)-pivot)
	var hull := Geometry2D.convex_hull(points)
	var outline: Array = []
	var radius := 0.0
	for point in hull:
		outline.append([point.x,point.y])
		radius = maxf(radius,point.length()*260.0/used.size.y)
	var nose := Vector2(512,166)-Vector2(used.position)
	var data := {"rect":[used.position.x,used.position.y,used.size.x,used.size.y],"pivot":[pivot.x,pivot.y],"nose":[nose.x,nose.y],"outline":outline,"height":260.0}
	var file := FileAccess.open("res://modules/main_menu/assets/mouse_cartoon_layout.gd",FileAccess.WRITE)
	file.store_string("extends RefCounted\n## Non-destructive atlas + outline analysis of user-approved mouse PNG.\nconst DATA := "+JSON.stringify(data,"\t")+"\n")
	print("CARTOON_MOUSE used=",used," displayed_height=260 silhouette_radius=",radius," hull_points=",hull.size())
	quit()
