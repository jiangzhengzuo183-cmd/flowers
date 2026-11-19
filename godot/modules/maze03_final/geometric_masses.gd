extends RefCounted
## Closed, single-volume scenery: continuous curves and one large subtraction.
const F := preload("res://modules/maze03_final/architecture_forms.gd")

static func _quad(st: SurfaceTool, p: Array[Vector3], n: Array[Vector3], uv: Array[Vector2] = []) -> void:
	var order := [0,1,2,0,2,3]
	if (p[1]-p[0]).cross(p[2]-p[0]).dot(n[0]+n[1]+n[2])>0:
		order = [0,2,1,0,3,2]
	for index: int in order:
		if not uv.is_empty():
			st.set_uv(uv[index])
		st.set_normal(n[index])
		st.add_vertex(p[index])

static func curved_mass(outer: float, inner: float, height: float, sweep: float = 245.0) -> SurfaceTool:
	var st := F.surface()
	var begin := deg_to_rad((360.0-sweep)*0.5)
	var count := 88
	for i in count:
		var a := begin+deg_to_rad(sweep)*i/count
		var b := begin+deg_to_rad(sweep)*(i+1)/count
		var na := Vector3(sin(a),0,cos(a))
		var nb := Vector3(sin(b),0,cos(b))
		var oa := na*outer
		var ob := nb*outer
		var ia := na*inner
		var ib := nb*inner
		var up := Vector3.UP*height
		_quad(st,[oa,ob,ob+up,oa+up],[na,nb,nb,na])
		_quad(st,[ia,ib,ib+up,ia+up],[-na,-nb,-nb,-na])
		F.face(st,PackedVector3Array([oa+up,ob+up,ib+up,ia+up]),Vector3.UP)
		F.face(st,PackedVector3Array([oa,ob,ib,ia]),Vector3.DOWN)
		if i==0:
			F.face(st,PackedVector3Array([oa,ia,ia+up,oa+up]),Vector3(-cos(a),0,sin(a)))
		if i==count-1:
			F.face(st,PackedVector3Array([ob,ib,ib+up,ob+up]),Vector3(cos(b),0,-sin(b)))
	return st

static func pierced_mass(size: Vector3, opening_center: Vector2, opening_radius: Vector2) -> SurfaceTool:
	# A single rectangular body with one oval void, not a stack of structural parts.
	var st := F.surface()
	var angles: Array[float] = []
	for i in 80:
		angles.append(TAU*i/80.0)
	for x: float in [-size.x/2,size.x/2]:
		for y: float in [0,size.y]:
			var d := Vector2(x,y)-opening_center
			angles.append(fposmod(atan2(d.y,d.x),TAU))
	angles.sort()
	for i in angles.size():
		var a := angles[i]
		var b := angles[(i+1)%angles.size()]
		var da := Vector2(cos(a),sin(a))
		var db := Vector2(cos(b),sin(b))
		var ra := _rectangle_ray(size,opening_center,da)
		var rb := _rectangle_ray(size,opening_center,db)
		var ha := opening_center+da/sqrt(pow(da.x/opening_radius.x,2)+pow(da.y/opening_radius.y,2))
		var hb := opening_center+db/sqrt(pow(db.x/opening_radius.x,2)+pow(db.y/opening_radius.y,2))
		for side: float in [-1,1]:
			var z := side*size.z/2
			F.face(st,PackedVector3Array([Vector3(ra.x,ra.y,z),Vector3(rb.x,rb.y,z),Vector3(hb.x,hb.y,z),Vector3(ha.x,ha.y,z)]),Vector3(0,0,side))
		var outer_normal := Vector3((ra.y-rb.y),rb.x-ra.x,0).normalized()
		if outer_normal.dot(Vector3(ra.x,(ra.y+rb.y-size.y)/2,0))<0:
			outer_normal = -outer_normal
		F.face(st,PackedVector3Array([Vector3(ra.x,ra.y,-size.z/2),Vector3(rb.x,rb.y,-size.z/2),Vector3(rb.x,rb.y,size.z/2),Vector3(ra.x,ra.y,size.z/2)]),outer_normal)
		var na := -Vector3((ha.x-opening_center.x)/pow(opening_radius.x,2),(ha.y-opening_center.y)/pow(opening_radius.y,2),0).normalized()
		var nb := -Vector3((hb.x-opening_center.x)/pow(opening_radius.x,2),(hb.y-opening_center.y)/pow(opening_radius.y,2),0).normalized()
		_quad(st,[Vector3(ha.x,ha.y,-size.z/2),Vector3(hb.x,hb.y,-size.z/2),Vector3(hb.x,hb.y,size.z/2),Vector3(ha.x,ha.y,size.z/2)],[na,nb,nb,na])
	return st

static func _rectangle_ray(size: Vector3, origin: Vector2, direction: Vector2) -> Vector2:
	var distance := INF
	if absf(direction.x)>0.00001:
		distance = minf(distance,((size.x/2 if direction.x>0 else -size.x/2)-origin.x)/direction.x)
	if absf(direction.y)>0.00001:
		distance = minf(distance,((size.y if direction.y>0 else 0.0)-origin.y)/direction.y)
	return origin+direction*distance

static func dome(radius: Vector2, height: float) -> SurfaceTool:
	var st := F.surface()
	var sectors := 96
	var rings := 26
	for j in rings:
		for i in sectors:
			var p: Array[Vector3] = []
			var n: Array[Vector3] = []
			for uv: Vector2 in [Vector2(i,j),Vector2(i+1,j),Vector2(i+1,j+1),Vector2(i,j+1)]:
				var theta := TAU*uv.x/sectors
				var phi := PI*0.5*uv.y/rings
				var point := Vector3(radius.x*sin(phi)*sin(theta),height*cos(phi),radius.y*sin(phi)*cos(theta))
				p.append(point)
				n.append(Vector3(point.x/(radius.x*radius.x),point.y/(height*height),point.z/(radius.y*radius.y)).normalized())
			_quad(st,p,n)
	return st


static func lathe(profile: PackedVector2Array, omit_pair: int = -1) -> SurfaceTool:
	# One continuous rotational mass. An omitted profile band can receive glazing.
	var st := F.surface()
	var segments := 96
	for j in profile.size()-1:
		if j==omit_pair:
			continue
		var a := profile[j]
		var b := profile[j+1]
		var slope := b-a
		for i in segments:
			var u := float(i)/segments
			var v := float(i+1)/segments
			var na := Vector3(sin(TAU*u)*slope.y,-slope.x,cos(TAU*u)*slope.y).normalized()
			var nb := Vector3(sin(TAU*v)*slope.y,-slope.x,cos(TAU*v)*slope.y).normalized()
			var p: Array[Vector3] = [Vector3(sin(TAU*u)*a.x,a.y,cos(TAU*u)*a.x),Vector3(sin(TAU*v)*a.x,a.y,cos(TAU*v)*a.x),Vector3(sin(TAU*v)*b.x,b.y,cos(TAU*v)*b.x),Vector3(sin(TAU*u)*b.x,b.y,cos(TAU*u)*b.x)]
			_quad(st,p,[na,nb,nb,na],[Vector2(u,0),Vector2(v,0),Vector2(v,1),Vector2(u,1)])
	return st

static func oval_glazing(center: Vector2, radius: Vector2, z: float) -> SurfaceTool:
	var st := F.surface()
	for i in 72:
		for uv: Vector2 in [Vector2.ZERO,Vector2(cos(TAU*(i+1)/72.0),sin(TAU*(i+1)/72.0)),Vector2(cos(TAU*i/72.0),sin(TAU*i/72.0))]:
			st.set_normal(Vector3.FORWARD)
			st.set_uv(uv*0.5+Vector2.ONE*0.5)
			st.add_vertex(Vector3(center.x+uv.x*radius.x,center.y+uv.y*radius.y,z))
	return st
