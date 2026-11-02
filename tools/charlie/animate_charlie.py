"""Baked locomotion and jump poses for the fitted Charlie skeleton."""
import math
import bpy
from mathutils import Vector, Quaternion


def cyclic_pose(values, phase):
    """Periodic Catmull-Rom: continuous velocity through contact/recovery poses."""
    pos = (phase % 1.0) * len(values)
    idx = int(pos)
    t = pos - idx
    a, b, c, d = (values[(idx + k) % len(values)] for k in (-1, 0, 1, 2))
    return tuple(.5 * (2*y + (-x+z)*t + (2*x-5*y+4*z-w)*t*t + (-x+3*y-3*z+w)*t*t*t)
                 for x, y, z, w in zip(a, b, c, d))


def eased_keys(keys, time):
    if time <= keys[0][0]: return keys[0][1]
    for (ta, a), (tb, b) in zip(keys, keys[1:]):
        if time <= tb:
            u = (time-ta)/(tb-ta)
            u = u*u*(3-2*u)
            return a + (b-a)*u
    return keys[-1][1]


def run_arm_angles(phase, side):
    """Compact reciprocal swing; avoid raised elbows and hands crossing chest."""
    swing = math.cos(phase - 0.12 * math.pi)
    return {
        # The supplied mesh rests in an A pose; inward rotation brings its
        # upper arms toward the torso rather than leaving elbows winged out.
        'UpperArm': (28 * swing, side * 32, -side * 2),
        'LowerArm': (-55 + 9 * math.cos(phase + 0.7), 0, 0),
        'Hand': (-2, 0, side * 1),
    }


def build_animations(rig, obj, scene):
    scene.render.fps = 30
    for pb in rig.pose.bones: pb.rotation_mode = 'QUATERNION'

    def rot(name, x=0, y=0, z=0):
        pb = rig.pose.bones[name]
        q = Quaternion((1,0,0),math.radians(x)) @ Quaternion((0,1,0),math.radians(y)) @ Quaternion((0,0,1),math.radians(z))
        basis = pb.bone.matrix_local.to_quaternion()
        pb.rotation_quaternion = basis.inverted() @ q @ basis

    def loc(name, xyz):
        pb = rig.pose.bones[name]
        pb.location = pb.bone.matrix_local.to_3x3().inverted() @ Vector(xyz)

    def reset():
        for pb in rig.pose.bones:
            pb.location = (0,0,0)
            pb.rotation_quaternion = (1,0,0,0)
            pb.scale = (1,1,1)

    def idle(phase):
        loc('Hips',(0,0,.003*(1-math.cos(phase))))
        rot('Chest',x=1.1*math.sin(phase))
        rot('Head',x=-.5*math.sin(phase),z=.7*math.sin(phase))
        for side,s in [('Left',1),('Right',-1)]:
            rot(side+'UpperArm',y=s*23,x=1.5*math.sin(phase+s*.3))
            rot(side+'LowerArm',x=-5)
        rot('ApronFront',x=1+math.sin(phase))

    def walk(phase):
        loc('Hips',(0,0,.012*(1-math.cos(phase*2))))
        rot('Hips',z=2.2*math.sin(phase))
        rot('Chest',z=-3*math.sin(phase))
        rot('Head',z=math.sin(phase))
        for side,s in [('Left',1),('Right',-1)]:
            t=phase+(0 if s==1 else math.pi)
            hip=19*math.sin(t)
            knee=5+26*max(0,-math.cos(t))**1.5
            rot(side+'UpperLeg',x=-hip,y=s)
            rot(side+'LowerLeg',x=knee)
            rot(side+'Foot',x=hip-knee*.7)
            rot(side+'UpperArm',x=17*math.sin(t),y=s*23)
            rot(side+'LowerArm',x=-12)
        rot('ApronFront',x=-8-3*math.sin(phase*2-.7))
        rot('ApronBack',x=5+3*math.sin(phase*2-.7))

    # Contact -> load -> toe-off -> heel recovery -> passing -> knee drive -> reach.
    run_leg = [(-32,22,1),(-12,42,-38),(18,22,-8),(30,100,-95),
               (-2,112,-90),(-45,88,-47),(-48,54,-20),(-42,28,5)]

    def run(phase):
        p=phase/(2*math.pi)
        rot('Hips',x=8,z=3*math.sin(phase))
        rot('Spine',x=5)
        rot('Chest',x=3,z=-6*math.sin(phase))
        rot('Head',x=-7,z=2*math.sin(phase))
        loc('Hips',(.012*math.sin(phase),-.018,0))
        for side,s in [('Left',1),('Right',-1)]:
            t=p+(0 if s==1 else .5)
            hip,knee,ankle=cyclic_pose(run_leg,t)
            rot(side+'UpperLeg',x=hip,y=s*1.4)
            rot(side+'LowerLeg',x=knee)
            rot(side+'Foot',x=ankle)
            # Arm moves opposite its leg, elbow opening on the backward swing.
            for part,angles in run_arm_angles(2*math.pi*t,s).items():
                rot(side+part,x=angles[0],y=angles[1],z=angles[2])
        # Keep the long fused apron clear of the high driving knee.
        rot('ApronFront',x=-37-5*math.sin(phase*2-.5))
        rot('ApronBack',x=20+6*math.sin(phase*2-.8))

    def world_rotation(name, desired):
        pb=rig.pose.bones[name]
        if pb.parent:
            relative=pb.parent.bone.matrix_local.to_quaternion().inverted() @ pb.bone.matrix_local.to_quaternion()
            base=pb.parent.matrix.to_quaternion() @ relative
        else:
            base=pb.bone.matrix_local.to_quaternion()
        pb.rotation_quaternion=base.inverted() @ desired
        bpy.context.view_layer.update()

    def ground_leg(side):
        """Solve a planted two-bone leg, then bake its FK rotations."""
        bpy.context.view_layer.update()
        upper=rig.pose.bones[side+'UpperLeg']
        lower=rig.pose.bones[side+'LowerLeg']
        foot=rig.pose.bones[side+'Foot']
        hip=upper.head.copy()
        target=foot.bone.head_local.copy()
        vec=target-hip
        distance=min(vec.length,upper.bone.length+lower.bone.length-.00001)
        direction=vec.normalized()
        along=(upper.bone.length**2-lower.bone.length**2+distance**2)/(2*distance)
        height=math.sqrt(max(0,upper.bone.length**2-along**2))
        pole=Vector((0,-1,0))
        pole=(pole-direction*pole.dot(direction)).normalized()
        knee=hip+direction*along+pole*height
        for pb,aim in [(upper,knee-hip),(lower,target-knee)]:
            rest=(pb.bone.tail_local-pb.bone.head_local).normalized()
            desired=rest.rotation_difference(aim.normalized()) @ pb.bone.matrix_local.to_quaternion()
            world_rotation(pb.name,desired)
        world_rotation(foot.name,foot.bone.matrix_local.to_quaternion())

    def jump(time):
        # 0.30–0.90 s flight: 43 cm ballistic rise, zero horizontal root motion.
        airborne=.30 < time < .90
        u=max(0,min(1,(time-.30)/.60))
        root_height=4*.43*u*(1-u) if airborne else 0
        loc('Root',(0,0,root_height))
        crouch=eased_keys([(0,0),(.10,.035),(.21,.12),(.30,0),(.90,0),(1.02,.12),(1.17,.035),(1.4,0)],time)
        lean=6 if airborne else 6*crouch/.12
        rot('Hips',x=lean)
        rot('Spine',x=6 if airborne else 7*crouch/.12)
        rot('Chest',x=2 if airborne else 4*crouch/.12)
        rot('Head',x=-8 if airborne else -7*crouch/.12)
        loc('Hips',(0,0 if airborne else .02*crouch/.12,-crouch))
        arm=eased_keys([(0,0),(.21,35),(.32,-85),(.50,-92),(.66,-65),(.90,-18),(1.02,-42),(1.4,0)],time)
        elbow=eased_keys([(0,-5),(.21,-28),(.32,-25),(.58,-50),(.90,-32),(1.02,-50),(1.4,-5)],time)
        for side,s in [('Left',1),('Right',-1)]:
            rot(side+'UpperArm',x=arm,y=s*(23+5*math.sin(math.pi*min(1,time/1.4))))
            rot(side+'LowerArm',x=elbow)
            if airborne:
                hip=eased_keys([(.30,-4),(.48,-25),(.65,-30),(.82,-14),(.90,-8)],time)
                knee=eased_keys([(.30,12),(.48,57),(.65,65),(.82,28),(.90,12)],time)
                rot(side+'UpperLeg',x=hip-lean,y=s)
                rot(side+'LowerLeg',x=knee)
                rot(side+'Foot',x=-hip-knee+7*math.sin(math.pi*u))
            else:
                ground_leg(side)
        rot('ApronFront',x=-5-16*(math.sin(math.pi*u) if airborne else crouch/.12))
        rot('ApronBack',x=3+10*(math.sin(math.pi*u) if airborne else crouch/.12))

    actions={}
    for label,nframes in [('Idle',90),('Walk',30),('Run',20),('Jump',42)]:
        rig.animation_data_create()
        action=bpy.data.actions.new(label)
        rig.animation_data.action=action
        action.use_fake_user=True
        action['loop']=label!='Jump'
        actions[label]=action
        for i in range(nframes+1):
            reset()
            phase=2*math.pi*i/nframes
            if label=='Idle': idle(phase)
            elif label=='Walk': walk(phase)
            elif label=='Run': run(phase)
            elif i in (0,nframes): idle(0)
            else: jump(i/30)
            for pb in rig.pose.bones:
                pb.keyframe_insert('location',frame=i+1,group=pb.name)
                pb.keyframe_insert('rotation_quaternion',frame=i+1,group=pb.name)
        action.use_frame_range=True
        action.frame_start=1
        action.frame_end=nframes+1
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for kp in fc.keyframe_points: kp.interpolation='LINEAR'

    # Correct contact only after skinning: flight clearance remains explicitly authored.
    shoe_ids=[v.index for v in obj.data.vertices if v.co.z<.05]
    for label,action in actions.items():
        rig.animation_data.action=action
        end=int(action.frame_range[1])
        for frame in range(1,end+1):
            scene.frame_set(frame)
            ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
            floor_z=min(ev.data.vertices[j].co.z for j in shoe_ids)
            desired=0
            if label=='Run':
                half=((frame-1)/(end-1)*2) % 1
                desired=.07*max(0,math.sin(math.pi*(half-.45)/.55)) if half>.45 else 0
            correction=(desired-floor_z) if label!='Jump' or not (.30<(frame-1)/30<.90) else max(0,-floor_z)
            pb=rig.pose.bones['Hips']
            offset=pb.bone.matrix_local.to_3x3() @ pb.location
            offset.z+=correction
            loc('Hips',offset)
            pb.keyframe_insert('location',frame=frame,group='Hips')
    rig.animation_data.action=actions['Idle']
    scene.frame_start=1; scene.frame_end=91; scene.frame_set(1)
    rig['animation_notes']='30 fps. Idle/Walk/Run loop in place. Jump is a 1.4 s one-shot with vertical Root arc; no horizontal root motion.'
    rig['suggested_walk_speed']=1.2
    rig['suggested_run_speed']=2.7
    rig['jump_takeoff_seconds']=.30
    rig['jump_landing_seconds']=.90
    return actions
