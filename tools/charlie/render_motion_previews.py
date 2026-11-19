"""Render the fitted rig's revised run and one-shot jump for GIF assembly."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

root=Path(__file__).resolve().parents[2]
out=root/'.verification/charlie/motion_v2_frames'
out.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
rig=next(o for o in scene.objects if o.type=='ARMATURE')
for obj in list(scene.objects):
    if obj.type in {'CAMERA','LIGHT'}: bpy.data.objects.remove(obj,do_unlink=True)
cam=bpy.data.objects.new('PreviewCamera',bpy.data.cameras.new('PreviewCamera'))
scene.collection.objects.link(cam)
cam.data.type='ORTHO'; scene.camera=cam
for name,loc,power,size in [('Key',(-3,-4,5),550,4),('Fill',(3,-2,2),250,3),('Rim',(1,3,4),400,3)]:
    light=bpy.data.objects.new(name,bpy.data.lights.new(name,'AREA')); scene.collection.objects.link(light)
    light.location=loc; light.rotation_euler=(Vector((0,0,.8))-light.location).to_track_quat('-Z','Y').to_euler()
    light.data.energy=power; light.data.size=size
scene.world=bpy.data.worlds.new('PreviewWorld'); scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.45,.45,.45,1)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.005))
floor=bpy.context.object; floor.name='PreviewFloor'
mat=bpy.data.materials.new('PreviewFloor'); mat.use_nodes=True
shader=mat.node_tree.nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value=(.55,.57,.55,1)
shader.inputs['Roughness'].default_value=1
floor.data.materials.append(mat)
scene.render.engine='CYCLES'; scene.cycles.samples=16
scene.view_settings.view_transform='AgX'
scene.render.resolution_x=420; scene.render.resolution_y=520; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
for label in ['Run','Jump']:
    rig.animation_data.action=bpy.data.actions[label]
    length=20 if label=='Run' else 42
    cam.data.ortho_scale=2.05 if label=='Run' else 2.65
    target=Vector((0,0,.79 if label=='Run' else 1.04))
    for view,offset in [('front',(3.8,-5,1.9)),('side',(5,-.8,1.65))]:
        cam.location=offset
        cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
        for n in range(length+(1 if label=='Jump' else 0)):
            scene.frame_set(n+1)
            scene.render.filepath=str(out/f'{label.lower()}_{view}_{n:02d}.png')
            bpy.ops.render.render(write_still=True)
print('MOTION_PREVIEWS_COMPLETE')
