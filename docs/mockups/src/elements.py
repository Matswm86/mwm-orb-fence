"""Element sheet (3D part). Run:
blender -b -P elements.py -- <raw.png> [<save.blend>]
Ortho camera, 1 m = 250 px, sheet 1600 x 1360. label_sheet.py adds the UI row and labels.
"""

import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
import zb_parts as zp  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = argv[0] if argv else "/tmp/elements_raw.png"
BLEND = argv[1] if len(argv) > 1 else None
PIC = str(Path(__file__).resolve().parents[3] / "assets/textures/pictures/w1_l3_ringplanet.png")

sc = zp.reset_scene()
sc.render.resolution_x, sc.render.resolution_y = 1600, 1360
cd = bpy.data.cameras.new("cam")
cd.type = "ORTHO"
cd.ortho_scale = 6.4
cam = zp.link(bpy.data.objects.new("cam", cd))
cam.location = (0, 0, 20)
sc.camera = cam

w = bpy.data.worlds.new("bg")
sc.world = w
w.use_nodes = True
bgn = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bgn.inputs["Color"].default_value = zp.col("#0A1430")
bgn.inputs["Strength"].default_value = 1.0

for name, energy, d, colr in (
    ("key", 3.2, (0.55, -0.55, -0.62), (1, 0.96, 0.9)),
    ("fill", 0.6, (-0.6, 0.4, -0.7), (0.55, 0.75, 1.0)),
    ("rim", 1.6, (-0.8, 0.5, -0.35), (0.75, 0.9, 1.0)),
):
    L = bpy.data.lights.new(name, "SUN")
    L.energy = energy
    L.color = colr
    o = zp.link(bpy.data.objects.new(name, L))
    o.rotation_euler = Vector(d).normalized().to_track_quat("-Z", "Y").to_euler()

COLX = [-2.56 + i * 1.28 for i in range(5)]
ROWY = [2.04, 0.68, -0.68, -2.04]


def at(c, r, dx=0.0, dy=0.0, z=0.0):
    return (COLX[c] + dx, ROWY[r] + dy, z)


# backing plates so each slot reads as a field patch
plate_m = zp.principled("plate", "field_glass", rough=0.3)
grid_m = zp.emissive("grid", "grid", 0.7)
for c in range(5):
    for r in range(4):
        p = zp.rounded_box("plate", 1.16, 1.22, 0.02, 0.05, 2)
        p.location = at(c, r, z=-0.2)
        zp.add_mat(p, plate_m)

pic_img = bpy.data.images.load(PIC)


def crystal_mat(name, use_pic=False, tint="#7FB6FF", win=(0.52, 0.64, 0)):
    m = zp.principled(name, tint, rough=0.08, coat=1.0, emit="#4F82E0", emit_str=0.32)
    if use_pic:
        nt = m.node_tree
        bsdf = next(x for x in nt.nodes if x.type == "BSDF_PRINCIPLED")
        tc = nt.nodes.new("ShaderNodeNewGeometry")
        mp = nt.nodes.new("ShaderNodeMapping")
        # world-space window into the picture, like the game's field UV
        mp.inputs["Scale"].default_value = (0.25, 0.25, 1)
        mp.inputs["Location"].default_value = win
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = pic_img
        nt.links.new(tc.outputs["Position"], mp.inputs[0])
        nt.links.new(mp.outputs[0], tex.inputs["Vector"])
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 0.38
    return m


# ---------------- row 0: balls ----------------
o = zp.make_orb("ball")
o.location = at(0, 0, z=0.3)
zp.trail(o.location, (1, -0.7), 0.9, 0.36)

stor = zp.make_orb("stor", r=0.34)
stor.location = at(1, 0, z=0.4)
r2 = zp.torus("stor_ring2", 0.34 * 1.85, 0.025)
r2.data.materials.append(zp.emissive("stor_r2m", "orb_ring", 3.0))
r2.rotation_euler = (math.radians(68), math.radians(-18), 0)
r2.location = stor.location

kv = zp.make_orb("kvikk", r=0.18)
kv.location = at(2, 0, dx=0.15, dy=0.12, z=0.3)
zp.trail(kv.location, (1, 0.7), 0.75, 0.30)

sn = zp.make_orb("snegl_ball")
sn.location = at(3, 0, z=0.3)
cu = bpy.data.curves.new("swirl", "CURVE")
cu.dimensions = "3D"
spl = cu.splines.new("POLY")
pts = []
for i in range(90):
    t = i / 89
    a = t * 2.2 * 2 * math.pi
    rr = 0.42 - t * 0.12
    pts.append((rr * math.cos(a), rr * math.sin(a), 0.0))
spl.points.add(len(pts) - 1)
for p_, c_ in zip(spl.points, pts):
    p_.co = (*c_, 1)
cu.bevel_depth = 0.022
swirl = zp.link(bpy.data.objects.new("swirl", cu))
swirl.data.materials.append(zp.emissive("swirl_m", "token", 3.0))
swirl.location = sn.location

# caged: 2x2 picture crystal room, ball shrunk to 70%, static bars
cage_room = zp.rounded_box("cage_room", 1.0, 1.0, 0.06, 0.03, 2)
cage_room.location = at(4, 0, z=-0.05)
zp.add_mat(cage_room, crystal_mat("cage_m", use_pic=True, win=(0.16, 0.29, 0)))
cb = zp.make_orb("caged", r=0.24 * 0.7, ring=True)
cb.location = at(4, 0, z=0.15)
bar_m = zp.principled("bar", "#C9D3E6", rough=0.25, metal=0.9, coat=0.5)
for i in range(5):
    b = zp.cylinder("bar", 0.03, 1.0, 12, axis="Y")
    b.location = at(4, 0, dx=-0.4 + i * 0.2, z=0.35)
    zp.add_mat(b, bar_m)
for dy in (-0.5, 0.5):
    b = zp.rounded_box("barframe", 1.04, 0.07, 0.07, 0.02, 1)
    b.location = at(4, 0, dy=dy, z=0.35)
    zp.add_mat(b, bar_m)

# ---------------- row 1: walls ----------------
# growing wall: horizontal piece with two heads (scaled call into make_beam)
zp.make_beam(ROWY[1], COLX[0] - 0.46, COLX[0] + 0.46, COLX[0], vertical=False, dash=0.12, gap=0.06)
for ob in bpy.data.objects:
    if ob.name.startswith("head"):
        ob.scale = (ob.scale[0] * 0.5, ob.scale[1] * 0.5, ob.scale[2] * 0.5)

# ghost wall: dotted white line + hollow origin ring
dot_m = zp.emissive("ghost_dot", "#FFFFFF", 2.2)
for i in range(-5, 6):
    if i == 0:
        continue
    dd = zp.uv_sphere("gdot", 0.035, 12, 6)
    dd.location = at(1, 1, dx=i * 0.095, z=0.08)
    zp.add_mat(dd, dot_m)
gr = zp.torus("ghost_origin", 0.12, 0.018, 32, 6)
gr.location = at(1, 1, z=0.08)
zp.add_mat(gr, dot_m)

# completed wall (standing alone in open field): solid ice bar + faint gold core
wall = zp.rounded_box("wall_done", 1.0, 0.22, 0.14, 0.05, 2)
wall.location = at(2, 1, z=0.06)
zp.add_mat(wall, zp.principled("wall_done_m", "#CFE4FF", rough=0.1, coat=1.0, emit="#9CC4FF", emit_str=0.6))
wc = zp.rounded_box("wall_core", 0.96, 0.04, 0.03, 0.01, 1)
wc.location = at(2, 1, z=0.14)
zp.add_mat(wc, zp.emissive("wall_core_m", "beam", 2.0))

# pop: soap bubbles drifting from the popped half
bub = bpy.data.materials.new("bubble")
bub.use_nodes = True
nt = bub.node_tree
for x in list(nt.nodes):
    nt.nodes.remove(x)
out = nt.nodes.new("ShaderNodeOutputMaterial")
lw = nt.nodes.new("ShaderNodeLayerWeight")
lw.inputs["Blend"].default_value = 0.3
pw = nt.nodes.new("ShaderNodeMath")
pw.operation = "POWER"
pw.inputs[1].default_value = 2.0
mul = nt.nodes.new("ShaderNodeMath")
mul.operation = "MULTIPLY"
mul.inputs[1].default_value = 3.0
em = nt.nodes.new("ShaderNodeEmission")
em.inputs["Color"].default_value = zp.col("#E6F6FF")
tr = nt.nodes.new("ShaderNodeBsdfTransparent")
ad = nt.nodes.new("ShaderNodeAddShader")
nt.links.new(lw.outputs["Facing"], pw.inputs[0])
nt.links.new(pw.outputs[0], mul.inputs[0])
nt.links.new(mul.outputs[0], em.inputs["Strength"])
nt.links.new(tr.outputs[0], ad.inputs[0])
nt.links.new(em.outputs[0], ad.inputs[1])
nt.links.new(ad.outputs[0], out.inputs[0])
try:
    bub.surface_render_method = "BLENDED"
except AttributeError:
    pass
random.seed(5)
for i in range(11):
    rr = random.uniform(0.05, 0.13)
    bb = zp.uv_sphere("bubble", rr, 24, 12)
    bb.location = at(3, 1, dx=random.uniform(-0.45, 0.45), dy=random.uniform(-0.3, 0.35), z=0.2)
    zp.add_mat(bb, bub)

# origin cell burst ring (wall start)
og = zp.torus("start_ring", 0.32, 0.03, 48, 8)
og.location = at(4, 1, z=0.1)
zp.add_mat(og, zp.emissive("start_m", "beam", 5.0))
og2 = zp.torus("start_ring_in", 0.14, 0.03, 32, 8)
og2.location = at(4, 1, z=0.1)
zp.add_mat(og2, zp.emissive("start_m2", "beam_core", 8.0))

# ---------------- row 2: cells ----------------
tile = zp.crystal_tile_mesh(apex_h=0.26, apex_off=(0.12, 0.07))
tile.location = at(0, 2)
zp.add_mat(tile, crystal_mat("crys_plain"))
for i, (dx, dy) in enumerate(((-0.36, 0.36), (0.36, 0.36), (-0.36, -0.36), (0.36, -0.36))):
    t2 = bpy.data.objects.new("tile_pic", tile.data.copy())
    zp.link(t2)
    t2.scale = (0.68, 0.68, 0.68)
    t2.location = at(1, 2, dx=dx * 0.68, dy=dy * 0.68)
    t2.rotation_euler.z = math.radians(90 * i)
    t2.data.materials.clear()
    t2.data.materials.append(crystal_mat("crys_pic", use_pic=True))


def stone(name, loc):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * 0.70, v.co.y * 0.70, v.co.z * 0.34))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.09, segments=1, affect="EDGES")
    random.seed(len(name))
    for v in bm.verts:
        if v.co.z > 0.1:
            v.co.z += random.uniform(-0.02, 0.03)
    ob = zp.mesh_obj(name, bm)
    zp.set_smooth(ob, False)
    ob.location = loc
    rock = zp.make_rock("tmp_rock")
    m = rock.data.materials[0]
    bpy.data.objects.remove(rock)
    ob.data.materials.append(m)
    return ob


stone("stone", at(2, 2, z=0.17))
for c, ang in ((3, 45), (4, -45)):
    stone(f"mirror{c}", at(c, 2, z=0.17))
    face = zp.rounded_box("mirror_face", 0.86, 0.10, 0.06, 0.02, 2)
    face.location = at(c, 2, z=0.36)
    face.rotation_euler.z = math.radians(ang)
    zp.add_mat(face, zp.principled("mirror_m", "#E8FBFF", rough=0.03, metal=1.0, emit="#BFF4FF", emit_str=2.5))

# ---------------- row 3: tokens + frame node ----------------
zp.make_token_sakte("snegl").location = at(0, 3, z=0.05)


def token_disc(name, color, loc):
    d = zp.cylinder(name, 0.30, 0.07, 40, axis="Z")
    d.data.materials.append(zp.principled(name + "_m", color, rough=0.25, emit=color, emit_str=0.5, coat=1.0))
    d.location = loc
    ring = zp.torus(name + "_rim", 0.312, 0.025, 48, 8)
    ring.data.materials.append(zp.emissive(name + "_rimm", "#FFFFFF", 2.0))
    ring.location = (loc[0], loc[1], loc[2] + 0.035)
    return d


def flat_icon(name, pts, loc, depth=0.04, scale=1.0):
    bm = bmesh.new()
    vs = [bm.verts.new((x * scale, y * scale, 0)) for x, y in pts]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z += depth
    ob = zp.mesh_obj(name, bm)
    ob.location = loc
    ob.data.materials.append(zp.emissive(name + "_m", "#FFFFFF", 2.5))
    return ob


lyn_loc = at(1, 3, z=0.05)
token_disc("lyn", "#6CD0FF", lyn_loc)
bolt = [(0.05, 0.22), (-0.10, 0.0), (0.0, 0.0), (-0.06, -0.22), (0.11, 0.04), (0.01, 0.04)]
flat_icon("bolt", bolt, (lyn_loc[0], lyn_loc[1], 0.1))

sk_loc = at(2, 3, z=0.05)
token_disc("skjold", "#B79CFF", sk_loc)
hx = zp.torus("hex", 0.16, 0.03, 6, 6)
hx.data.materials.append(zp.emissive("hex_m", "#FFFFFF", 2.5))
hx.location = (sk_loc[0], sk_loc[1], 0.12)
hx.rotation_euler.z = math.radians(30)

# frame corner node + a bit of rail
zp.make_frame(COLX[3] - 0.32, ROWY[3] - 0.32, COLX[3] + 0.32, ROWY[3] + 0.32, width=0.14, depth=0.16)
# slot 4,3: halo quad sample (what a phone gets if post glow is off)
hq = zp.plane("halo_demo", 1.0, 1.0)
hq.location = at(4, 3, z=0.0)
hq.data.materials.append(zp.radial_glow("halo_demo_m", "orb_shell", 1.8, 2.2))
core = zp.uv_sphere("halo_core", 0.13, 24, 12)
core.location = at(4, 3, z=0.1)
core.data.materials.append(zp.emissive("halo_core_m", "orb_core", 1.0))

# sheet is zoomed 2.5x vs the game, so tone glow down to keep shapes readable
for ob in list(bpy.data.objects):
    if ob.name.startswith(("beamglow", "headglow")):
        bpy.data.objects.remove(ob)
for m in bpy.data.materials:
    if m.name.endswith("_mat") and m.name.split("_")[0] in ("ball", "stor", "kvikk", "snegl", "caged"):
        for n in m.node_tree.nodes:
            if n.type == "EMISSION":
                n.inputs["Strength"].default_value = 1.5
    if m.name.startswith(("beam_head", "beam_core")):
        for n in m.node_tree.nodes:
            if n.type == "EMISSION":
                n.inputs["Strength"].default_value = 3.0
zp.bloom(threshold=1.2, size=4)
sc.render.filepath = OUT
sc.render.image_settings.file_format = "PNG"
bpy.ops.render.render(write_still=True)
if BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print("WROTE", OUT)
