extends SceneTree
## Bake only alpha silhouettes from the existing notebook art. Never paint over the art.
const FOLDER := "res://assets/report-book/"
const PAD := 60

func _initialize() -> void:
	var opened:=Image.load_from_file(FOLDER+"book-base.png")
	var closed:=Image.load_from_file(FOLDER+"closed-cover.png")
	for item: Array in [["open",opened],["closed",closed],["right",opened.get_region(Rect2i(534,0,546,670))]]:
		for kind: String in ["contact","ambient"]:
			bake(item[1],str(item[0])+"-"+kind,1.1 if kind=="contact" else 3.0)
	print("PASS native notebook alpha shadows baked")
	quit()

func bake(source: Image,name: String,sigma: float) -> void:
	var small:=source.duplicate() as Image
	small.resize(ceili(source.get_width()/5.0),ceili(source.get_height()/5.0),Image.INTERPOLATE_LANCZOS)
	var w:=small.get_width()+24;var h:=small.get_height()+24
	var values:=PackedFloat32Array();values.resize(w*h)
	for y in small.get_height():
		for x in small.get_width():values[(y+12)*w+x+12]=small.get_pixel(x,y).a
	var radius:=ceili(sigma*3);var weights:=PackedFloat32Array();var total:=0.0
	for i in range(-radius,radius+1):
		var weight:=exp(-float(i*i)/(2*sigma*sigma));weights.append(weight);total+=weight
	for i in weights.size():weights[i]/=total
	var horizontal:=PackedFloat32Array();horizontal.resize(w*h)
	var blurred:=PackedFloat32Array();blurred.resize(w*h)
	for y in h:
		for x in w:
			for k in range(-radius,radius+1):horizontal[y*w+x]+=values[y*w+clampi(x+k,0,w-1)]*weights[k+radius]
	for y in h:
		for x in w:
			for k in range(-radius,radius+1):blurred[y*w+x]+=horizontal[clampi(y+k,0,h-1)*w+x]*weights[k+radius]
	var result:=Image.create(w,h,false,Image.FORMAT_RGBA8)
	for y in h:
		for x in w:result.set_pixel(x,y,Color(0.20,0.125,0.065,blurred[y*w+x]))
	assert(result.save_png(FOLDER+"shadow-"+name+".png")==OK)
