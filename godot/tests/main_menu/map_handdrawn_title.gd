extends SceneTree
func _initialize() -> void:
	var source := Image.load_from_file("res://modules/main_menu/assets/title_handdrawn_v2.png")
	var metadata: Dictionary = preload("res://modules/main_menu/assets/layout.gd").DATA.duplicate(true)
	var rows := [0,333,559,941]
	var cuts := [[0,299,482,703,979,1174,1372,1672],[0,732,935,1672],[0,250,436,647,831,1017,1214,1436,1672]]
	var words := ["FLOWERS","FOR","ALGERNON"]
	var letters: Array[Dictionary] = []
	var index := 0
	for row in 3:
		for column in words[row].length():
			var cell := Rect2i(cuts[row][column],rows[row],cuts[row][column+1]-cuts[row][column],rows[row+1]-rows[row])
			var used := source.get_region(cell).get_used_rect()
			used.position += cell.position
			letters.append({"index":index,"row":row,"letter":words[row][column],"file":"title_handdrawn_v2.png","atlas":true,"rect":[used.position.x,used.position.y,used.size.x,used.size.y]})
			index += 1
	var used := source.get_used_rect()
	metadata.letters = letters
	metadata.title_source_asset = "title_handdrawn_v2.png"
	metadata.title_ink_rect = [used.position.x,used.position.y,used.size.x,used.size.y]
	var file := FileAccess.open("res://modules/main_menu/assets/layout_handdrawn.gd",FileAccess.WRITE)
	file.store_string("extends RefCounted\n## Atlas regions only; generated PNG pixels stay untouched.\nconst DATA := " + JSON.stringify(metadata,"\t") + "\n")
	print("HANDDRAWN_TITLE ",source.get_size()," alpha=",source.detect_alpha()," used=",used," letters=",letters.size())
	quit()
