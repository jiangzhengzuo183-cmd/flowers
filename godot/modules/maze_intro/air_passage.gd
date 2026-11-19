extends Node3D
## Temporary world-anchored air pockets along the camera route, never a screen overlay.
const WindSettings := preload("res://modules/maze03_final/wind_settings.tres")
var materials: Array[ShaderMaterial]=[]
var wind_materials: Array[ShaderMaterial]=[]
var zones: Array[Vector3]=[]
var particles: Array[CPUParticles3D]=[]
var rng:=RandomNumberGenerator.new()
var maze_number:=1
var gain:=0.0
func install(intro: Node, number: int) -> void:
    name="EntranceAirPassage"
    maze_number=number
    rng.seed=number*103+731
    var sun: DirectionalLight3D=intro.runtime.actor.get_parent().get_node("Sun")
    var tint:=Color("f4e9ef") if number==1 else (Color("dac59c") if number==2 else Color("e8f0f3"))
    tint=tint.lerp(sun.light_color,0.22)
    for u: float in [0.35,0.60,0.82]:
        var pose: Transform3D=intro.pose_at(u)
        zones.append(pose.origin)
        _mist_bank(pose,tint,5 if number==1 else 3,0.52 if number==1 else (0.22 if number==2 else 0.12))
        if number==2:_sand(pose.origin)
    if number==3:_wind()
    update_gain(0.0)
func _mist_bank(pose: Transform3D,tint: Color,count: int,density: float) -> void:
    for i in count:
        var mesh:=MeshInstance3D.new()
        mesh.name="MistWisp"+str(get_child_count())
        var quad:=QuadMesh.new()
        quad.size=Vector2(rng.randf_range(7.0,11.0),rng.randf_range(3.4,5.6))
        mesh.mesh=quad
        var offset:=Vector3(rng.randf_range(-3.8,3.8),rng.randf_range(-1.8,1.8),rng.randf_range(-3.0,3.0))
        if i==0:offset=Vector3(0.6,0.15,-1.4)
        elif i==1:offset=Vector3(-1.1,-0.5,-2.7)
        mesh.transform=Transform3D(pose.basis*Basis(Vector3.FORWARD,rng.randf_range(-0.35,0.35)),pose*offset)
        mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var paint:=ShaderMaterial.new()
        paint.shader=preload("res://modules/maze_intro/air_mist.gdshader")
        paint.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
        paint.set_shader_parameter("density",density*rng.randf_range(0.8,1.1))
        paint.set_shader_parameter("phase",rng.randf()*8.0)
        paint.set_shader_parameter("drift",Vector2(0.06,0.013) if maze_number==2 else Vector2(0.032,-0.009))
        mesh.material_override=paint
        add_child(mesh)
        materials.append(paint)
func _sand(point: Vector3) -> void:
    var dust:=CPUParticles3D.new()
    dust.name="PassingSand"+str(particles.size())
    dust.position=point
    dust.amount=95
    dust.lifetime=3.8
    dust.preprocess=3.8
    dust.local_coords=false
    dust.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
    dust.emission_box_extents=Vector3(5.3,4.0,4.8)
    dust.direction=Vector3(1,0.06,-0.12)
    dust.spread=18.0
    dust.gravity=Vector3(0,-0.03,0)
    dust.initial_velocity_min=1.8
    dust.initial_velocity_max=3.8
    dust.scale_amount_min=0.45
    dust.scale_amount_max=1.4
    var quad:=QuadMesh.new()
    quad.size=Vector2(0.065,0.045)
    var paint:=ShaderMaterial.new()
    paint.shader=preload("res://modules/maze_intro/air_grain.gdshader")
    quad.material=paint
    dust.mesh=quad
    var ramp:=Gradient.new()
    ramp.set_color(0,Color(0.56,0.43,0.27,0.0))
    ramp.set_color(1,Color(0.82,0.69,0.48,0.0))
    ramp.add_point(0.18,Color(0.64,0.50,0.31,0.65))
    ramp.add_point(0.75,Color(0.88,0.77,0.57,0.58))
    dust.color_ramp=ramp
    dust.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(dust)
    particles.append(dust)
    materials.append(paint)
func _wind() -> void:
    var surface:=SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for point: Vector3 in zones:
        for i in 8:
            var centre:=point+Vector3(rng.randf_range(-5,5),rng.randf_range(-3,3),rng.randf_range(-4,4))
            var phase:=rng.randf()
            var velocity:=rng.randf_range(0.9,1.1)
            for uv: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
                surface.set_uv(uv)
                surface.set_uv2(Vector2(phase,velocity))
                surface.add_vertex(centre)
    var mesh:=MeshInstance3D.new()
    mesh.name="PassingAirStreaks"
    mesh.mesh=surface.commit()
    mesh.custom_aabb=AABB(Vector3(-40,-5,-20),Vector3(110,90,110))
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var paint:=ShaderMaterial.new()
    paint.shader=preload("res://modules/maze03_final/wind_flow.gdshader")
    paint.set_shader_parameter("wind_direction",WindSettings.direction)
    paint.set_shader_parameter("speed",WindSettings.high_speed)
    paint.set_shader_parameter("path_length",24.0)
    paint.set_shader_parameter("streak_length",3.4)
    paint.set_shader_parameter("streak_width",0.026)
    paint.set_shader_parameter("visibility",0.24)
    paint.set_shader_parameter("wind_color",Vector3(0.92,0.97,1.0))
    mesh.material_override=paint
    add_child(mesh)
    wind_materials.append(paint)
func update_gain(u: float) -> void:
    gain=smoothstep(0.03,0.18,u)*(1.0-smoothstep(0.90,0.99,u))
    for paint: ShaderMaterial in materials:paint.set_shader_parameter("gain",gain)
    for paint: ShaderMaterial in wind_materials:paint.set_shader_parameter("flow_gain",gain)
