"""Run with Blender in background mode; source blend must already be loaded.

blender --background --disable-autoexec INPUT.blend --python tools/charlie/build_charlie.py
Only the Charlie character asset module is written. The input file is never saved.
"""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector, Matrix
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/characters/charlie'
GAME = ROOT / 'godot/assets/characters/charlie'
QA = ROOT / '.verification/charlie'
for folder in (ART, GAME, QA): folder.mkdir(parents=True, exist_ok=True)
SOURCE = bpy.data.filepath
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
scene = bpy.context.scene
meshes = [o for o in scene.objects if o.type == 'MESH']
assert len(meshes) == 1, 'This build is tailored to the supplied one-mesh Tripo Charlie.'
obj = meshes[0]
assert not any(o.type == 'ARMATURE' for o in scene.objects), 'Do not replace an existing rig.'
original_vertices = len(obj.data.vertices)
original_triangles = sum(len(p.vertices)-2 for p in obj.data.polygons)
world = obj.matrix_world.copy()
obj.parent = None
obj.matrix_world = Matrix.Identity(4)
# Tripo file: +X forward, Z up, height ~99.879. Blender: -Y forward, Z up.
coords = [world @ v.co for v in obj.data.vertices]
floor = min(p.z for p in coords)
scale = 1.6 / (max(p.z for p in coords) - floor)
for v, p in zip(obj.data.vertices, coords):
    v.co = (p.y * scale, -p.x * scale, (p.z-floor)*scale)
obj.name = 'CharlieMesh'
obj.data.name = 'CharlieMesh'
bm = bmesh.new(); bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.000015)
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.to_mesh(obj.data); bm.free(); obj.data.update()
welded_vertices = len(obj.data.vertices)
for other in list(scene.objects):
    if other != obj: bpy.data.objects.remove(other, do_unlink=True)
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
# Preserve the silhouette/UV atlas while reducing runtime geometry.
dec = obj.modifiers.new('Runtime geometry reduction', 'DECIMATE')
dec.ratio = .52
dec.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=dec.name)
obj.data.validate(verbose=True, clean_customdata=False)
for p in obj.data.polygons: p.use_smooth = True
mat = obj.data.materials[0]
mat.name = 'CharlieAlbedo'
bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bsdf.inputs['Metallic'].default_value = 0
bsdf.inputs['Roughness'].default_value = .85
bsdf.inputs['Specular IOR Level'].default_value = .25
mat.use_backface_culling = True
tex = next(n.image for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE')
tex.name = 'CharlieAlbedo_2048'
tex.scale(2048,2048)
tex.pack()

# Explicitly placed joints fit this stylized character, including its large head.
armdata = bpy.data.armatures.new('CharlieSkeleton')
rig = bpy.data.objects.new('CharlieRig', armdata)
scene.collection.objects.link(rig)
rig.show_in_front = True
armdata.display_type = 'OCTAHEDRAL'
obj.select_set(False); rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
def bone(name, head, tail, parent=None):
    b=armdata.edit_bones.new(name); b.head=head; b.tail=tail
    if parent: b.parent=armdata.edit_bones[parent]
    # Align local X consistently with the sagittal bending axis.
    b.align_roll(Vector((0,-1,0)))
    return b
bone('Root',(0,0,0),(0,0,.12))
bone('Hips',(0,0,.66),(0,0,.78),'Root')
bone('Spine',(0,0,.78),(0,0,.90),'Hips')
bone('Chest',(0,0,.90),(0,0,1.02),'Spine')
bone('Neck',(0,0,1.02),(0,0,1.10),'Chest')
bone('Head',(0,0,1.10),(0,0,1.46),'Neck')
for side,s in [('Left',1),('Right',-1)]:
    bone(side+'Shoulder',(s*.045,0,.99),(s*.16,0,.99),'Chest')
    bone(side+'UpperArm',(s*.16,0,.99),(s*.29,-.012,.82),side+'Shoulder')
    bone(side+'LowerArm',(s*.29,-.012,.82),(s*.395,-.026,.70),side+'UpperArm')
    bone(side+'Hand',(s*.395,-.026,.70),(s*.432,-.038,.658),side+'LowerArm')
    bone(side+'UpperLeg',(s*.133,0,.66),(s*.139,-.008,.335),'Hips')
    bone(side+'LowerLeg',(s*.139,-.008,.335),(s*.146,0,.105),side+'UpperLeg')
    bone(side+'Foot',(s*.146,0,.105),(s*.146,-.13,.05),side+'LowerLeg')
    bone(side+'Toes',(s*.146,-.13,.05),(s*.146,-.215,.04),side+'Foot')
bone('ApronFront',(0,-.115,.76),(0,-.14,.40),'Hips')
bone('ApronBack',(0,.13,.76),(0,.16,.40),'Hips')
bpy.ops.object.mode_set(mode='OBJECT')

# The fused Tripo mesh fails Blender's bone heat solve. Use explicit anatomical
# regions and smooth blend zones instead, so every vertex gets usable weights.
obj.select_set(True)
obj.parent=rig
for b in armdata.bones: obj.vertex_groups.new(name=b.name)
modifier=obj.modifiers.new('Charlie linear skin','ARMATURE')
modifier.object=rig
modifier.use_deform_preserve_volume = False  # Match glTF/Godot linear skinning.

# Sample the original UV atlas to keep blue apron cloth away from leg weights.
pixels=np.empty(tex.size[0]*tex.size[1]*4,dtype=np.float32)
tex.pixels.foreach_get(pixels)
pixels=pixels.reshape((tex.size[1],tex.size[0],4))
colors=np.zeros((len(obj.data.vertices),3)); counts=np.zeros(len(obj.data.vertices))
uvdata=obj.data.uv_layers.active.data
for loop in obj.data.loops:
    u,v=uvdata[loop.index].uv
    colors[loop.vertex_index]+=pixels[min(int(v*tex.size[1]),tex.size[1]-1)%tex.size[1],min(int(u*tex.size[0]),tex.size[0]-1)%tex.size[0],:3]
    counts[loop.vertex_index]+=1
colors/=np.maximum(counts[:,None],1)
def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a))); return t*t*(3-2*t)
def assign(vi,weights):
    total=sum(weights.values())
    for g in list(obj.data.vertices[vi].groups): obj.vertex_groups[g.group].remove([vi])
    for name,w in weights.items():
        if w>1e-5: obj.vertex_groups[name].add([vi],w/total,'REPLACE')

cloth_count=0
for v in obj.data.vertices:
    x,y,z=v.co; ax=abs(x); side='Left' if x>0 else 'Right'
    r,g,b=colors[v.index]
    blue = b>r*1.12 and b>g*1.03
    # Cloth is fused into the source surface. The waist towel is included by location/color.
    towel = .03<x<.20 and y<-.10 and .47<z<.765 and r>g*.95 and r>b*.95
    apron = (.355<z<.785 and blue) or towel
    if z>1.105:
        assign(v.index,{'Head':1})
    elif z>1.025 and ax<.15:
        h=smooth(1.03,1.105,z); assign(v.index,{'Neck':1-h,'Head':h})
    elif apron:
        k=1-smooth(.70,.79,z)
        assign(v.index,{'ApronFront' if y<.015 else 'ApronBack':k,'Hips':1-k})
        cloth_count+=1
    elif z<.15:
        # Shoes remain rigid; only the ankle region blends to the lower leg.
        k=smooth(.095,.16,z)
        assign(v.index,{side+'Foot':1-k,side+'LowerLeg':k})
    else:
        if z<.39:
            k=smooth(.28,.39,z)
            w={side+'LowerLeg':1-k,side+'UpperLeg':k}
        elif z<.71:
            k=smooth(.54,.71,z)
            w={side+'UpperLeg':1-k,'Hips':k}
        elif z<.86:
            k=smooth(.74,.86,z)
            w={'Hips':1-k,'Spine':k}
        elif z<1.025:
            k=smooth(.86,.99,z)
            w={'Spine':1-k,'Chest':k}
        else:
            w={'Neck':1}
        # The arm and torso touch at the armpit; blending follows its diagonal.
        threshold=.158+max(0,.96-max(z,.76))*.58
        am=smooth(threshold-.026,threshold+.026,ax) if .58<z<1.025 else 0
        if am:
            upper=smooth(.79,.855,z)
            hand=1-smooth(.695,.745,z)
            aw={side+'UpperArm':upper,side+'LowerArm':(1-upper)*(1-hand),side+'Hand':(1-upper)*hand}
            w={n:v*(1-am) for n,v in w.items()}
            for n,vv in aw.items(): w[n]=w.get(n,0)+vv*am
        assign(v.index,w)

# Smooth only sharp atlas classification boundaries, keeping all other weights.
weights=np.zeros((len(obj.data.vertices),len(armdata.bones)),dtype=np.float64)
for v in obj.data.vertices:
    for gw in v.groups:
        weights[v.index,gw.group]=gw.weight
adj=[[] for _ in obj.data.vertices]
for e in obj.data.edges:
    a,b=e.vertices; adj[a].append(b); adj[b].append(a)
for _ in range(3):
    nw=weights.copy()
    for v in obj.data.vertices:
        if .36<v.co.z<1.11 and adj[v.index]:
            nw[v.index]=weights[v.index]*.70+np.mean(weights[adj[v.index]],axis=0)*.30
    weights=nw
names=[g.name for g in obj.vertex_groups]
for v in obj.data.vertices:
    w=weights[v.index]
    ids=np.argsort(w)[-4:]
    assign(v.index,{names[i]:float(w[i]) for i in ids if w[i]>.0001})

# Animation is baked separately from geometry and weights.
import sys
sys.dont_write_bytecode=True
sys.path.insert(0, str(Path(__file__).parent))
from animate_charlie import build_animations
actions=build_animations(rig,obj,scene)

# Remove unrelated orphan textures from the source file, pack the one used atlas.
for _ in range(3): bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=False,do_recursive=True)
bpy.context.view_layer.objects.active=rig
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); obj.select_set(True)
bpy.context.view_layer.update()

# Export the named actions; animation bones and all transforms are sampled.
# Blender -Y maps to glTF +Z. Rotate only the exported scene root 180 degrees
# so the delivered GLB faces Godot -Z, matching the project's moving player.
export_root=bpy.data.objects.new('Charlie',None)
scene.collection.objects.link(export_root)
export_root.rotation_euler.z=math.pi
rig.parent=export_root
export_root.select_set(True)
bpy.context.view_layer.update()
props=bpy.ops.export_scene.gltf.get_rna_type().properties
kwargs=dict(filepath=str(GAME/'charlie.glb'),export_format='GLB',use_selection=True,
            export_animations=True,export_skins=True,export_yup=True,
            export_force_sampling=True,export_animation_mode='ACTIONS',
            export_anim_slide_to_zero=True,export_image_format='JPEG',export_jpeg_quality=90,
            export_all_influences=False,export_def_bones=True)
kwargs={k:v for k,v in kwargs.items() if k in props}
for label,action in actions.items(): action.name=label+'-loop' if action['loop'] else label
bpy.ops.export_scene.gltf(**kwargs)
for label,action in actions.items(): action.name=label
rig.parent=None
bpy.data.objects.remove(export_root,do_unlink=True)
bpy.context.view_layer.update()

# Save an editor-friendly view of the finished rig, with no lights/cameras in GLB.
from mathutils import Euler
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.shading.type='MATERIAL'
            space.region_3d.view_distance=2.5
            space.region_3d.view_location=Vector((0,0,.8))
            space.region_3d.view_rotation=Euler((math.radians(80),0,0)).to_quaternion()
            space.overlay.show_floor=False
scene.world.color=(.22,.22,.22)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'charlie_rigged.blend'),compress=True)

report={'source':Path(SOURCE).name,'blender':bpy.app.version_string,'original_vertices':original_vertices,
        'original_triangles':original_triangles,'welded_vertices':welded_vertices,
        'game_vertices':len(obj.data.vertices),'game_triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),
        'bones':len(armdata.bones),'binding':'anatomical regions, atlas clothing mask, 3 smoothing passes, 4 influences max',
        'cloth_vertices_corrected':cloth_count,'texture':[2048,2048],
        'animations':{k:{'frames':list(v.frame_range),'seconds':(v.frame_range[1]-v.frame_range[0])/30,'loop':bool(v['loop'])} for k,v in actions.items()},
        'unweighted_vertices':sum(1 for v in obj.data.vertices if not v.groups),
        'max_influences':max(len(v.groups) for v in obj.data.vertices),
        'max_weight_sum_error':max(abs(sum(g.weight for g in v.groups)-1) for v in obj.data.vertices)}
(ART/'build_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('BUILD_REPORT',json.dumps(report),flush=True)
