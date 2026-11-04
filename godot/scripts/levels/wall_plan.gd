extends RefCounted
## Convex plan clipping for watertight circle/porch junctions.

static func clip(poly: PackedVector2Array,normal: Vector2,bound: float,positive: bool) -> PackedVector2Array:
	var output := PackedVector2Array()
	if poly.is_empty():
		return output
	var previous := poly[-1]
	var previous_d := previous.dot(normal)-bound
	var previous_in := previous_d>=-0.000001 if positive else previous_d<=0.000001
	for current: Vector2 in poly:
		var current_d := current.dot(normal)-bound
		var current_in := current_d>=-0.000001 if positive else current_d<=0.000001
		if current_in!=previous_in:
			output.append(previous.lerp(current,previous_d/(previous_d-current_d)))
		if current_in:
			output.append(current)
		previous = current
		previous_d = current_d
		previous_in = current_in
	var clean := PackedVector2Array()
	for p: Vector2 in output:
		if clean.is_empty() or clean[-1].distance_to(p)>0.00001:
			clean.append(p)
	if clean.size()>1 and clean[0].distance_to(clean[-1])<0.00001:
		clean.remove_at(clean.size()-1)
	return clean

static func area(poly: PackedVector2Array) -> float:
	var result := 0.0
	for i in poly.size():
		result += poly[i].cross(poly[(i+1)%poly.size()])
	return absf(result)/2

static func subtract(poly: PackedVector2Array,mask: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var remaining := poly
	var clip_mask := mask.duplicate()
	var signed_area := 0.0
	for i in clip_mask.size():
		signed_area += clip_mask[i].cross(clip_mask[(i+1)%clip_mask.size()])
	if signed_area<0:
		clip_mask.reverse()
	# Reject disjoint masks before partitioning. Without this, distant curved
	# wall wedges still split a porch into thousands of unnecessary fragments.
	var intersection := poly
	for i in clip_mask.size():
		var a := clip_mask[i]
		var edge := clip_mask[(i+1)%clip_mask.size()]-a
		var normal := Vector2(-edge.y,edge.x).normalized()
		intersection = clip(intersection,normal,normal.dot(a),true)
		if intersection.size()<3 or area(intersection)<0.000001:
			return [poly]
	for i in clip_mask.size():
		if remaining.size()<3:
			break
		var a := clip_mask[i]
		var edge := clip_mask[(i+1)%clip_mask.size()]-a
		var normal := Vector2(-edge.y,edge.x).normalized()
		var outside := clip(remaining,normal,normal.dot(a),false)
		if outside.size()>=3 and area(outside)>0.00001:
			result.append(outside)
		remaining = clip(remaining,normal,normal.dot(a),true)
	return result

static func outside_porches(poly: PackedVector2Array,porches: Array) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [poly]
	for porch: Dictionary in porches:
		var r: Array = porch.rect
		var mask := PackedVector2Array([Vector2(r[0],r[2]),Vector2(r[1],r[2]),Vector2(r[1],r[3]),Vector2(r[0],r[3])])
		var next: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in pieces:
			next.append_array(subtract(piece,mask))
		pieces = next
	return pieces
