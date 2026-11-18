extends RefCounted
const Details := preload("res://art/maze01/maze01_stone_details.gd")
const Layout := preload("res://scripts/levels/maze_01_layout.gd")
## Recalculate joins after pool/courtyard cuts. Old end trims must not leave gaps.
static func repair(generator: Node3D) -> void:
	var junctions: Dictionary = {}
	var originals: Dictionary = {}
	for vertical: bool in [false,true]:
		var group := generator.get_node("VerticalWalls" if vertical else "HorizontalWalls")
		var axis := Vector2i(0,1) if vertical else Vector2i(1,0)
		for body: Node3D in group.get_children():
			var mesh := body.get_child(0) as MeshInstance3D
			var source: BoxMesh = mesh.get_meta("art_source_mesh",null) as BoxMesh
			if source==null:
				continue
			originals[mesh] = source
			var tokens := str(body.name).split("_")
			var start := Vector2i(int(tokens[3]),int(tokens[2]))
			for end in 2:
				var point := start+axis*end
				var plane := Vector2(axis).dot(Vector2(point))*2.4
				var center := body.position.z if vertical else body.position.x
				if absf(plane-center)>(source.size.z if vertical else source.size.x)/2+0.001:
					continue
				if not junctions.has(point):
					junctions[point] = []
				# An old grid endpoint inside the newly lengthened divider is a T junction,
				# not its visible end; trim the adjoining wall, never clip this extension.
				var internal_end: bool = body.get_meta("extended_north_divider",false) and absf(plane-(center+(-1.0 if end==0 else 1.0)*(source.size.z if vertical else source.size.x)/2.0))>0.2
				junctions[point].append({"mesh":null if internal_end else mesh,"end":end,"axis":axis,"plane":plane-center,"half":(source.size.x if vertical else source.size.z)/2,"top":body.position.y+source.size.y/2})
	# Existing arch piers own their intersections just as in the mature source scene.
	for arch: Dictionary in Layout.config().arches:
		if not generator.architecture.has_node(arch.id):
			continue
		var portal: Node3D = generator.architecture.get_node(arch.id)
		var axis := Vector2i(0,1) if arch.edge[0][0]==arch.edge[1][0] else Vector2i(1,0)
		var center := Vector2(portal.position.x,portal.position.z)/2.4
		for direction: float in [-0.5,0.5]:
			var point := Vector2i((center+Vector2(axis)*direction).round())
			if not junctions.has(point):
				junctions[point] = []
			junctions[point].append({"mesh":null,"axis":axis,"half":0.20,"top":3.4})
	var ends: Dictionary = {}
	for neighbors: Array in junctions.values():
		if neighbors.size()<2:
			continue
		var owner: Dictionary = neighbors[0]
		for candidate: Dictionary in neighbors:
			if candidate.mesh==null or (owner.mesh!=null and candidate.top>owner.top+0.001):
				owner = candidate
		for entry: Dictionary in neighbors:
			if entry.mesh==null:
				continue
			var straight := false
			for other: Dictionary in neighbors:
				if other.mesh!=entry.mesh and other.axis==entry.axis:
					straight = true
			if entry.axis==owner.axis and not straight:
				continue
			if not ends.has(entry.mesh):
				ends[entry.mesh] = [null,null]
			ends[entry.mesh][entry.end] = entry.plane+(1 if entry.end==0 else -1)*(owner.half if entry.axis!=owner.axis else 0)
	var cache: Dictionary = {}
	for mesh: MeshInstance3D in originals:
		mesh.mesh = originals[mesh]
		Details.soften_edges(mesh,cache,ends.get(mesh,[]))

	# Match physical bounds to the final rendered stone, including all end trims.
	var matched := 0
	for mesh: MeshInstance3D in originals:
		var body := mesh.get_parent() as Node3D
		var bounds: AABB = mesh.transform*mesh.get_aabb()
		for shape: CollisionShape3D in body.find_children("*","CollisionShape3D",true,false):
			if not shape.shape is BoxShape3D:
				continue
			shape.shape = shape.shape.duplicate()
			shape.shape.size = bounds.size
			shape.position = bounds.get_center()
			matched += 1
	generator.set_meta("matched_wall_colliders",matched)
