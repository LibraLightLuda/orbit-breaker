"""Blender 5.2 offline art source. Run with blender --background --python this_file."""
import bpy, math, os
from mathutils import Vector
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.render.resolution_x = scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.world.color = (.18,.18,.18)
scene.view_settings.view_transform = 'AgX'
def mat(name, color, metal=.5, emission=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=.32
    p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emission
    return m
ceramic=mat('Ceramic',(.72,.78,.78),.55); dark=mat('Graphite',(.035,.065,.085),.8)
cyan=mat('Ion',(.04,.72,.85),.5,3); gold=mat('Thermal',(.95,.32,.04),.4,2)
alien=mat('Obsidian',(.12,.035,.09),.75); coral=mat('Threat',(.9,.045,.12),.4,3)
def plate(points,z,h,material):
    n=len(points); verts=[(x,y,z) for x,y in points]+[(x,y,z+h) for x,y in points]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new('Armor'); mesh.from_pydata(verts,[],faces); mesh.update()
    obj=bpy.data.objects.new('Armor',mesh); scene.collection.objects.link(obj); obj.data.materials.append(material)
    bevel=obj.modifiers.new('Machined edges','BEVEL'); bevel.width=.055; bevel.segments=3
    obj.modifiers.new('Normals','WEIGHTED_NORMAL'); return obj
def box(x,y,z,sx,sy,sz,m):
    return plate([(x-sx,y-sy),(x+sx,y-sy),(x+sx,y+sy),(x-sx,y+sy)],z,sz,m)
def disk(x,y,z,r,h,m,n=12):
    return plate([(x+math.cos(i*math.tau/n)*r,y+math.sin(i*math.tau/n)*r) for i in range(n)],z,h,m)
def clear():
    for o in list(scene.objects):
        if o.type=='MESH': bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.object.camera_add(location=(0,0,12)); camera=bpy.context.object; camera.data.type='ORTHO'; camera.data.ortho_scale=4.8
scene.camera=camera
for pos,power,size,col in [((-3,4,6),1000,5,(.7,.88,1)),((3,-2,4),650,4,(1,.55,.28))]:
    bpy.ops.object.light_add(type='AREA',location=pos); light=bpy.context.object; light.data.energy=power; light.data.shape='DISK'; light.data.size=size; light.data.color=col
    light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
def render(path,scale=4.8):
    camera.data.ortho_scale=scale; scene.render.filepath=os.path.join(ROOT,path); bpy.ops.render.render(write_still=True)
# Representative ship: actual beveled meshes, recessed reactor, mirrored cannons and layered hull.
plate([(-1.4,-.52),(.65,-.48),(1.65,0),(.65,.48),(-1.4,.52)],0,.24,dark)
plate([(-.9,-.3),(.6,-.26),(1.4,0),(.6,.26),(-.9,.3)],.24,.2,ceramic)
for side in [-1,1]:
    plate([(-1.25,side*.4),(-1.6,side*1.05),(-.55,side*.9),(.7,side*.42)],.12,.19,ceramic)
    box(-.15,side*.6,.12,.95,.105,.17,dark); box(.95,side*.6,.18,.2,.07,.09,ceramic)
    box(-1.28,side*.38,.12,.16,.12,.16,cyan)
    for x in [-.9,-.65,-.4]: box(x,side*.65,.35,.065,.13,.04,dark)
box(-.15,0,.47,.34,.14,.035,cyan)
render('art_source/comparison/striker_blender.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'art_source','precision_assets.blend'))
# Small equipment uses the same material/lighting grammar.
for kind in ['normal','blade','frost','missile','sentry','mine','axe','core','drive','shell','xp','heal','planet','meteor']:
    clear()
    if kind in ['planet','meteor']:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4 if kind=='planet' else 2,radius=1.4)
        o=bpy.context.object; o.data.materials.append(mat(kind,(.12,.3,.38) if kind=='planet' else (.17,.12,.1),.25))
        if kind=='planet':
            for i in range(22):
                a=i*2.399; x=math.cos(a)*1.2; y=math.sin(a)*1.2; disk(x,y,.7,.14,.08,ceramic,7)
    else:
        disk(0,0,0,.65,.24,dark,6); disk(0,0,.24,.24,.09,cyan if kind in ['frost','sentry','drive','xp'] else gold,8)
        if kind in ['blade','axe']:
            plate([(-.2,-.2),(.2,-.2),(1.3,-.65),(.85,0),(1.3,.65),(.2,.2),(-.2,.2)],.2,.12,ceramic)
        elif kind=='missile':
            plate([(-1,-.17),(.6,-.17),(1.2,0),(.6,.17),(-1,.17)],.25,.15,ceramic)
        elif kind in ['xp','heal']:
            plate([(-.7,0),(0,-1),(.7,0),(0,1)],.2,.3,cyan if kind=='xp' else ceramic)
        elif kind=='drive':
            for y in [-.55,.55]:
                box(0,y,.2,.85,.24,.22,ceramic)
                for x in [-.6,-.3,0,.3]: box(x,y,.44,.055,.26,.06,dark)
                box(-.9,y,.25,.08,.17,.14,cyan)
        elif kind=='shell':
            for side in [-1,1]:
                plate([(-1.1,side*.25),(-.7,side*1.05),(.55,side*.9),(1.15,side*.3)],.2,.3,ceramic)
                plate([(-.6,side*.35),(-.4,side*.75),(.4,side*.65),(.75,side*.32)],.51,.06,dark)
                box(.5,side*.7,.55,.2,.055,.06,gold)
        elif kind=='sentry':
            for i in range(3):
                a=i*math.tau/3
                disk(math.cos(a)*.95,math.sin(a)*.95,.1,.26,.2,ceramic,6)
            box(.35,0,.4,.75,.16,.25,ceramic)
            box(1.05,0,.48,.12,.08,.1,cyan)
            for y in [-.23,.23]: box(.25,y,.44,.45,.04,.1,dark)
        elif kind=='mine':
            disk(0,0,.3,.45,.2,ceramic,8)
            for i in range(8):
                a=i*math.tau/8
                p=plate([(.42,-.06),(1.1,-.12),(1.2,.12),(.42,.06)],.15,.12,dark); p.rotation_euler.z=a
                disk(math.cos(a),math.sin(a),.3,.09,.08,gold,6)
        else:
            arms=3 if kind in ['normal','frost','sentry','core'] else 4
            for i in range(arms):
                a=math.tau*i/arms
                p=plate([(.45,-.18),(1.15,-.28),(1.35,0),(1.15,.28),(.45,.18)],.15,.2,ceramic)
                p.rotation_euler.z=a
                disk(math.cos(a)*.8,math.sin(a)*.8,.37,.08,.04,cyan if kind=='frost' else gold,6)
        if kind not in ['xp','heal']:
            for x in [-.24,0,.24]:
                box(x,-.25,.55,.04,.08,.035,dark)
            disk(0,0,.4,.18,.05,cyan if kind in ['frost','drive','sentry'] else gold,12)
    render('assets/art/objects/'+kind+'.png',3.8)
