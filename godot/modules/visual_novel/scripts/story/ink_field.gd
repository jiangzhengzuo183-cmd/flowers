extends RefCounted
## Port of the confirmed flow.js: same field, inertia, splat and 16-bit encoding.
const W := 128
const H := 112
var field := PackedVector2Array()
var momentum := PackedVector2Array()
var bytes := PackedByteArray()
var texture: ImageTexture
var pending: Array[Dictionary] = []
var last := Vector2(-10,-10)
var energy := 0.0
var params: Dictionary

func _init(settings: Dictionary) -> void:
	params = settings
	field.resize(W*H)
	momentum.resize(W*H)
	bytes.resize(W*H*4)
	encode()
	texture = ImageTexture.create_from_image(Image.create_from_data(W,H,false,Image.FORMAT_RGBA8,bytes))

func move(point: Vector2, dt: float) -> void:
	if last.x > -1:
		var change := point-last
		var length := Vector2(change.x,change.y/1.15).length()
		var speed := minf(3,length/maxf(0.008,dt))
		var count := clampi(ceili(length/0.012),1,32)
		for j in range(1,count+1): pending.append({"p":last+change*float(j)/count,"d":change/count,"speed":speed})
		if pending.size()>256: pending = pending.slice(-256)
	last = point

func step(dt: float) -> void:
	dt = clampf(dt,0.001,0.05)
	var decay := exp(-float(params.recovery)*dt)
	var inertia := exp(-dt/float(params.inertia))
	for i in range(field.size()):
		field[i] = field[i]*decay+momentum[i]*(1-inertia)
		momentum[i] *= inertia
	for sample: Dictionary in pending:
		var p: Vector2 = sample.p
		var delta: Vector2 = sample.d
		var radius: float = params.radius
		var gain: float = params.strength*(1+sample.speed*params.speedInfluence)
		for y in range(maxi(0,floori((p.y-radius*1.15)*H)),mini(H,ceili((p.y+radius*1.15)*H))):
			for x in range(maxi(0,floori((p.x-radius)*W)),mini(W,ceili((p.x+radius)*W))):
				var offset := Vector2((x+0.5)/W-p.x,((y+0.5)/H-p.y)/1.15)
				var distance := offset.length_squared()/(radius*radius)
				if distance>=1: continue
				var weight := pow(1-distance,3)*gain
				var bend := offset.x/radius*0.2
				var impulse := Vector2(delta.x-delta.y*bend,delta.y+delta.x*bend)*weight
				var i := y*W+x
				field[i] += impulse*0.8
				momentum[i] += impulse*0.2
	pending.clear()
	encode()
	texture.update(Image.create_from_data(W,H,false,Image.FORMAT_RGBA8,bytes))

func encode() -> void:
	energy = 0
	for i in range(field.size()):
		var d := field[i]
		var length := Vector2(d.x,d.y/1.15).length()
		var limit: float = params.maxDisplacement
		if length>0: d *= limit*tanh(length/limit)/length
		energy += d.length_squared()
		var a := clampi(roundi((d.x/0.08*0.5+0.5)*65535),0,65535)
		var b := clampi(roundi((d.y/0.08*0.5+0.5)*65535),0,65535)
		bytes[i*4]=a>>8
		bytes[i*4+1]=a&255
		bytes[i*4+2]=b>>8
		bytes[i*4+3]=b&255

func reset() -> void:
	field.fill(Vector2.ZERO)
	momentum.fill(Vector2.ZERO)
	pending.clear()
	last = Vector2(-10,-10)
	encode()
	texture.update(Image.create_from_data(W,H,false,Image.FORMAT_RGBA8,bytes))
