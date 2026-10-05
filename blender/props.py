"""Generate Leaf Pile Dive's meshes and export each as FBX (all original geometry).
Run: "C:/Program Files/Blender Foundation/Blender 5.1/blender.exe" --background --factory-startup --python blender/props.py
Outputs blender/out/{MapleLeaf,LeafPile,OakTrunk,OakCanopy,Pumpkin,TreeCanopy}.fbx"""
import bpy, bmesh, math, os, random
from mathutils import Vector, noise

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export(bm, name, smooth=False):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = smooth
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(OUT, name + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, global_scale=1.0,
                             mesh_smooth_type="FACE", add_leaf_bones=False, bake_anim=False,
                             axis_forward="-Z", axis_up="Y")
    print("EXPORTED", name, len(mesh.polygons), "faces")


def maple_leaf():
    """Flat 5-lobed maple leaf, slightly curled, ~2 x 2 units, 0.06 thick."""
    clear()
    bm = bmesh.new()
    pts = []
    n = 72
    lobes = [(90, 1.0), (30, 0.82), (150, 0.82), (-20, 0.6), (200, 0.6)]
    for k in range(n):
        a = 2 * math.pi * k / n
        deg = math.degrees(a) % 360
        r = 0.38
        for lob, size in lobes:
            diff = abs(((deg - (lob % 360)) + 180) % 360 - 180)
            r = max(r, size * math.exp(-(diff / 13) ** 2) + 0.3 * math.exp(-(diff / 32) ** 2))
        if 262 < deg < 278:
            r = 0.14
        pts.append((r * math.cos(a), r * math.sin(a)))
    top = [bm.verts.new((x, y, 0.03 + 0.12 * (x * x + y * y))) for x, y in pts]
    bot = [bm.verts.new((x, y, -0.03 + 0.12 * (x * x + y * y))) for x, y in pts]
    ct = bm.verts.new((0, 0, 0.05))
    cb = bm.verts.new((0, 0, -0.01))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ct, top[i], top[j]))
        bm.faces.new((cb, bot[j], bot[i]))
        bm.faces.new((top[i], bot[i], bot[j], top[j]))
    # stem
    s = [bm.verts.new(v) for v in [(-0.04, -0.12, 0), (0.04, -0.12, 0), (0.04, -0.75, -0.02), (-0.04, -0.75, -0.02)]]
    bm.faces.new(s)
    export(bm, "MapleLeaf")


def blob_mound(name, seed, lumps, flatten, radius=1.0, sub=3):
    """Lumpy mound: an icosphere pushed out by noise + lumps, bottom cut flat."""
    clear()
    random.seed(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=radius)
    centres = [Vector((random.uniform(-0.7, 0.7), random.uniform(-0.7, 0.7), random.uniform(0.0, 0.8))).normalized() for _ in range(lumps)]
    off = Vector((seed * 1.3, seed * 0.7, 2.1))
    for v in bm.verts:
        d = v.co.normalized()
        bump = sum(max(0, d.dot(c)) ** 12 * 0.18 for c in centres)
        v.co *= 1 + 0.12 * noise.noise(v.co * 3 + off) + bump
        v.co.z *= flatten
        if v.co.z < 0:
            v.co.z = 0
    export(bm, name)


def oak_trunk():
    clear()
    bm = bmesh.new()
    random.seed(3)
    # tapered trunk with flared roots
    segs, rings = 10, 12
    verts = []
    for r in range(rings + 1):
        h = r / rings
        rad = 0.16 * (1 - 0.55 * h) + (0.12 * (1 - h) ** 6)
        ring = []
        for s in range(segs):
            a = 2 * math.pi * s / segs
            wob = 1 + 0.08 * math.sin(a * 3 + h * 5)
            ring.append(bm.verts.new((rad * wob * math.cos(a), rad * wob * math.sin(a), h)))
        verts.append(ring)
    for r in range(rings):
        for s in range(segs):
            t = (s + 1) % segs
            bm.faces.new((verts[r][s], verts[r][t], verts[r + 1][t], verts[r + 1][s]))
    # a few thick branches
    for k in range(5):
        a = k * 2 * math.pi / 5 + random.uniform(-0.3, 0.3)
        base = Vector((0, 0, 0.62 + 0.07 * k))
        tip = base + Vector((math.cos(a) * 0.38, math.sin(a) * 0.38, 0.28))
        res = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.05, radius2=0.025, depth=(tip - base).length)
        mid = (base + tip) / 2
        rot = Vector((0, 0, 1)).rotation_difference((tip - base).normalized()).to_matrix()
        bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0), matrix=rot)
        bmesh.ops.translate(bm, verts=res["verts"], vec=mid)
    export(bm, "OakTrunk")


def canopy(name, seed, blobs, spread):
    clear()
    random.seed(seed)
    bm = bmesh.new()
    for k in range(blobs):
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=2, radius=random.uniform(0.42, 0.62))
        c = Vector((random.uniform(-spread, spread), random.uniform(-spread, spread), random.uniform(-0.15, 0.35)))
        off = Vector((k * 3.3, seed, 0))
        for v in tmp.verts:
            v.co *= 1 + 0.1 * noise.noise(v.co * 4 + off)
            v.co.z *= 0.8
            v.co += c
        m = bpy.data.meshes.new("tmp")
        tmp.to_mesh(m)
        tmp.free()
        bm.from_mesh(m)
    export(bm, name)


def pumpkin():
    clear()
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=1.0)
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x)
        v.co.x *= 1 + 0.08 * math.cos(a * 8)
        v.co.y *= 1 + 0.08 * math.cos(a * 8)
        v.co.z *= 0.72
    export(bm, "Pumpkin", smooth=True)


maple_leaf()
blob_mound("LeafPile", 11, 14, 0.62)
oak_trunk()
canopy("OakCanopy", 21, 11, 0.75)
canopy("TreeCanopy", 5, 5, 0.45)
pumpkin()
