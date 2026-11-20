extends SceneTree

func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/report_book_pages.json"))
	var width := int(data.design.pageWidth)
	var height := int(data.design.pageHeight)
	for spread: String in data.sources:
		var source: Dictionary = data.sources[spread]
		var original := Image.load_from_file(source.foreground)
		original.convert(Image.FORMAT_RGBA8)
		var group: Array = data.entries.filter(func(e: Dictionary) -> bool: return e.spread == spread)
		var all := (1 << group.size())-1
		for key: String in data.variants[spread]:
			var mask := int(key)
			var foreground := original
			if mask != all:
				foreground = Image.create(original.get_width(),original.get_height(),false,Image.FORMAT_RGBA8)
				var selected: Dictionary = {}
				for i in group.size():
					if mask & (1 << i):
						for number: int in group[i].regions: selected[number] = true
				for number: int in selected:
					var region: Dictionary = data.artworkRegions[spread][number]
					foreground.blit_rect(original,Rect2i(int(region.x),int(region.y),int(region.w),int(region.h)),Vector2i(int(region.x),int(region.y)))
			for side: String in ["left","right"]:
				var paper := Image.load_from_file("res://assets/report-book/blank-"+side+".png")
				paper.convert(Image.FORMAT_RGBA8)
				var b: Dictionary = source.crops[side]
				var tr: Dictionary = source.transforms[side]
				var artwork := foreground.get_region(Rect2i(int(b.x),int(b.y),int(b.width),int(b.height)))
				artwork.resize(roundi(float(b.width)*tr.scale),roundi(float(b.height)*tr.scale),Image.INTERPOLATE_LANCZOS)
				paper.blend_rect(artwork,Rect2i(Vector2i.ZERO,artwork.get_size()),Vector2i(roundi(tr.x),roundi(tr.y)))
				for y in height:
					for x in range(width-2,width) if side == "left" else range(0,2): paper.set_pixel(x,y,Color.TRANSPARENT)
				assert(paper.save_png(data.variants[spread][key][side]) == OK)
	print("PASS native Godot artwork prepared, including March 29–April 28 and all partial unlocks")
	quit()
