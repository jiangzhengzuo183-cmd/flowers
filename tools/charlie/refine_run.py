"""Refine only Run arm rotations; preserve the supplied original rig and GLB.

blender --background --disable-autoexec art/characters/charlie/charlie_rigged.blend
        --python tools/charlie/refine_run.py
"""
import bpy
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Quaternion

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).parent))
from animate_charlie import run_arm_angles

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/characters/charlie'
GAME = ROOT / 'godot/assets/characters/charlie'
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
scene = bpy.context.scene
assert len(rig.data.bones) == 24
assert mesh.name == 'CharlieMesh'

def mesh_signature():
    h = hashlib.sha256()
    for v in mesh.data.vertices:
        h.update(repr(tuple(v.co)).encode())
        h.update(repr([(g.group, g.weight) for g in v.groups]).encode())
    for p in mesh.data.polygons:
        h.update(repr(tuple(p.vertices)).encode())
    for uv in mesh.data.uv_layers.active.data:
        h.update(repr(tuple(uv.uv)).encode())
    return h.hexdigest()

def channels(action):
    return [fc for layer in action.layers for strip in layer.strips
            for bag in strip.channelbags for fc in bag.fcurves]

def action_signature(action, exclude=()):
    data = sorted((fc.data_path, fc.array_index,
                   [(tuple(k.co), k.interpolation) for k in fc.keyframe_points])
                  for fc in channels(action) if fc.data_path not in exclude)
    return hashlib.sha256(repr(data).encode()).hexdigest()

arm_names = [side + part for side in ('Left', 'Right')
             for part in ('UpperArm', 'LowerArm', 'Hand')]
arm_paths = [f'pose.bones["{name}"].rotation_quaternion' for name in arm_names]
original_mesh = mesh_signature()
actions = {name: bpy.data.actions[name] for name in ('Idle', 'Walk', 'Run', 'Jump')}
before = {name: action_signature(a, arm_paths if name == 'Run' else ())
          for name, a in actions.items()}
run = actions['Run']
rig.animation_data.action = run
for frame in range(1, 22):
    scene.frame_set(frame)
    phase = 2 * math.pi * (frame - 1) / 20
    for side, sign in [('Left', 1), ('Right', -1)]:
        t = phase + (0 if sign == 1 else math.pi)
        for part, angles in run_arm_angles(t, sign).items():
            pb = rig.pose.bones[side + part]
            x, y, z = map(math.radians, angles)
            q = Quaternion((1, 0, 0), x) @ Quaternion((0, 1, 0), y) @ Quaternion((0, 0, 1), z)
            basis = pb.bone.matrix_local.to_quaternion()
            pb.rotation_quaternion = basis.inverted() @ q @ basis
            pb.keyframe_insert('rotation_quaternion', frame=frame, group=pb.name)
for fc in channels(run):
    if fc.data_path in arm_paths:
        for key in fc.keyframe_points:
            key.interpolation = 'LINEAR'
assert original_mesh == mesh_signature(), 'Geometry, weights and UVs must not change'
assert before == {name: action_signature(a, arm_paths if name == 'Run' else ())
                  for name, a in actions.items()}, 'Only six Run arm channels may change'

# Use the same export convention as build_charlie.py, without rebuilding mesh,
# skin, texture, leg motion or any of the other actions.
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
mesh.select_set(True)
root = bpy.data.objects.new('Charlie', None)
scene.collection.objects.link(root)
root.rotation_euler.z = math.pi
rig.parent = root
root.select_set(True)
bpy.context.view_layer.update()
for label, action in actions.items():
    action.name = label + '-loop' if label != 'Jump' else label
props = bpy.ops.export_scene.gltf.get_rna_type().properties
args = dict(filepath=str(GAME / 'charlie_refined.glb'), export_format='GLB',
            use_selection=True, export_animations=True, export_skins=True,
            export_yup=True, export_force_sampling=True, export_animation_mode='ACTIONS',
            export_anim_slide_to_zero=True, export_image_format='JPEG',
            export_jpeg_quality=90, export_all_influences=False, export_def_bones=True)
bpy.ops.export_scene.gltf(**{k: v for k, v in args.items() if k in props})
for label, action in actions.items():
    action.name = label
rig.parent = None
bpy.data.objects.remove(root, do_unlink=True)
rig.animation_data.action = actions['Idle']
scene.frame_set(1)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ART / 'charlie_refined.blend'), compress=True)
report = {'source': 'charlie_rigged.blend', 'output': 'charlie_refined.glb',
          'mesh_uv_weights_unchanged': True, 'other_animation_channels_unchanged': True,
          'changed_bones': arm_names, 'changed_action': 'Run',
          'upper_arm_swing_degrees': 28, 'upper_arm_inward_rotation_degrees': 32,
          'elbow_flexion_degrees': [46, 64], 'mesh_signature': original_mesh}
(ART / 'run_refinement_report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('RUN_REFINEMENT:', json.dumps(report), flush=True)
