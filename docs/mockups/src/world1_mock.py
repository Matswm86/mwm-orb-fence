"""World 1 gameplay mock (3D layer). Run:
blender -b -P world1_mock.py -- <out_raw.png> [<save.blend>]
Then overlay.py adds the HUD, home disc and direction toggle.
"""

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
import zb_parts as zp  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = argv[0] if argv else "/tmp/world1_raw.png"
BLEND = argv[1] if len(argv) > 1 else None

CELL = 72
COLS, ROWS = 14, 16
FX0, FY0 = 36, 256  # field top-left in px
FX1, FY1 = FX0 + COLS * CELL, FY0 + ROWS * CELL  # 1044, 1408

sc = zp.reset_scene()
cam = zp.camera_px()
zp.star_world(1.0)


def cell_center(c, r):
    return zp.px(FX0 + c * CELL + CELL / 2, FY0 + r * CELL + CELL / 2)


# ---------------- backdrop (world 1: Moon orbit) ----------------
zp.nebula_plane(
    "neb_a", 150, -150,
    [(0.0, "#071233"), (0.45, "#0E3D66"), (0.62, "#0B6A78"), (0.8, "#2B3F9E"), (1.0, "#3A2C86")],
    seed=2.3, strength=9.0, scale=2.2,
)
zp.nebula_plane(
    "neb_b", 120, -140,
    [(0.0, "#061024"), (0.5, "#15306E"), (0.75, "#1F7F8C"), (1.0, "#8FE3E0")],
    seed=7.1, strength=6.0, scale=3.5,
).location.x = 20

# home planet: big ocean world whose limb crosses the bottom of the screen
zp.planet(
    "home", 52, (-14, -84, -125),
    [(0.0, "#0B2F5A"), (0.42, "#1466A0"), (0.55, "#2C9CC4"), (0.62, "#E8F4FF"), (0.7, "#1F7FB0"), (1.0, "#0A3A6E")],
    band_scale=(1.0, 1.0, 2.6), atmo="#5FD3FF", atmo_str=3.0, noise_scale=2.4,
)
# moon, upper right behind the field
zp.planet(
    "moon", 5.2, (10.4, 15.5, -60),
    [(0.0, "#5E6577"), (0.5, "#9AA3B5"), (1.0, "#C9D0DC")],
    band_scale=(1, 1, 1), atmo=None, noise_scale=6.0, rough=0.95,
)

# key light from upper-left, slightly in front
sun = bpy.data.lights.new("key", "SUN")
sun.energy = 3.2
sun.color = (1.0, 0.96, 0.9)
sun.angle = math.radians(2)
so = zp.link(bpy.data.objects.new("key", sun))
d = Vector((0.55, -0.55, -0.62)).normalized()
so.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
fill = bpy.data.lights.new("fill", "SUN")
fill.energy = 0.6
fill.color = (0.55, 0.75, 1.0)
fo = zp.link(bpy.data.objects.new("fill", fill))
fo.rotation_euler = Vector((-0.6, 0.4, -0.7)).normalized().to_track_quat("-Z", "Y").to_euler()
rim_l = bpy.data.lights.new("rimlight", "SUN")
rim_l.energy = 1.6
rim_l.color = (0.75, 0.9, 1.0)
ro = zp.link(bpy.data.objects.new("rimlight", rim_l))
ro.rotation_euler = Vector((-0.8, 0.5, -0.35)).normalized().to_track_quat("-Z", "Y").to_euler()

# ---------------- field ----------------
x0, y1w = zp.px(FX0, FY0)
x1, y0w = zp.px(FX1, FY1)
glass = zp.plane("glass", x1 - x0, y1w - y0w)
glass.location = ((x0 + x1) / 2, (y0w + y1w) / 2, -0.02)
zp.add_mat(glass, zp.principled("glass", "field_glass", rough=0.2, alpha=0.70))
zp.make_frame(x0, y0w, x1, y1w)

# level 3 state: captured strip left, top-right block, bottom-right block (89/224 = 39.7%)
captured = set()
for c in range(0, 3):
    for r in range(ROWS):
        captured.add((c, r))
for c in range(10, 14):
    for r in range(0, 4):
        captured.add((c, r))
for c in range(9, 14):
    for r in range(13, 16):
        captured.add((c, r))
print("captured", len(captured), len(captured) / (COLS * ROWS))

grid_m = zp.emissive("grid", "grid", 0.9)
for c in range(1, COLS):
    gx = zp.px(FX0 + c * CELL, 0)[0]
    g = zp.rounded_box("gv", 0.022, y1w - y0w, 0.01, 0.004, 1)
    g.location = (gx, (y0w + y1w) / 2, 0.0)
    zp.add_mat(g, grid_m)
for r in range(1, ROWS):
    gy = zp.px(0, FY0 + r * CELL)[1]
    g = zp.rounded_box("gh", x1 - x0, 0.022, 0.01, 0.004, 1)
    g.location = ((x0 + x1) / 2, gy, 0.0)
    zp.add_mat(g, grid_m)
# grid intersection dots (force-field nodes)
dot_m = zp.emissive("gdot", "#9CC4FF", 2.0)
for c in range(1, COLS):
    for r in range(1, ROWS):
        if (c, r) in captured and (c - 1, r - 1) in captured:
            continue
        gx, gy = zp.px(FX0 + c * CELL, FY0 + r * CELL)
        dt = zp.cylinder("gd", 0.04, 0.02, 8, axis="Z")
        dt.location = (gx, gy, 0.01)
        zp.add_mat(dt, dot_m)

# crystal tiles
random.seed(11)
tile_mats = []
PIC = str(Path(__file__).resolve().parents[3] / "assets/textures/pictures/w1_l3_ringplanet.png")
pic_img = bpy.data.images.load(PIC)


def crystal_pic_mat(name, tint):
    m = zp.principled(name, "#FFFFFF", rough=0.08, coat=1.0)
    nt = m.node_tree
    bsdf = next(x for x in nt.nodes if x.type == "BSDF_PRINCIPLED")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / 10.08, 1 / 11.52, 1)
    mp.inputs["Location"].default_value = (5.04 / 10.08, 4.48 / 11.52, 0)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = pic_img
    tex.extension = "EXTEND"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs["B"].default_value = zp.col(tint)
    nt.links.new(geo.outputs["Position"], mp.inputs[0])
    nt.links.new(mp.outputs[0], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], mix.inputs["A"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0.38
    return m


for i, hx in enumerate(("#F2F7FF", "#FFFFFF", "#E6F4FF", "#EEEAFF")):
    tile_mats.append(crystal_pic_mat(f"crys{i}", hx))
proto = zp.crystal_tile_mesh(apex_h=0.26, apex_off=(0.12, 0.07))
proto.hide_render = True
for c, r in sorted(captured):
    ob = bpy.data.objects.new("tile", proto.data.copy())
    zp.link(ob)
    cx, cy = cell_center(c, r)
    ob.location = (cx, cy, 0.0)
    ob.rotation_euler.z = math.radians(90 * random.randint(0, 3))
    ob.data.materials.clear()
    ob.data.materials.append(random.choice(tile_mats))

# rim along captured / open boundaries
rim_m = zp.emissive("rim", "rim", 5.0)
for c, r in captured:
    for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        n = (c + dc, r + dr)
        if n in captured or not (0 <= n[0] < COLS and 0 <= n[1] < ROWS):
            continue
        cx, cy = cell_center(c, r)
        if dc:
            ex = cx + dc * 0.36
            seg = zp.rounded_box("rim", 0.05, 0.74, 0.05, 0.02, 1)
            seg.location = (ex, cy, 0.09)
        else:
            ey = cy - dr * 0.36
            seg = zp.rounded_box("rim", 0.74, 0.05, 0.05, 0.02, 1)
            seg.location = (cx, ey, 0.09)
        zp.add_mat(seg, rim_m)

# wall being built: vertical, column 7, origin row 6, heads at rows 3 and 9 ends
bx = cell_center(7, 0)[0]
top = zp.px(0, FY0 + 3 * CELL + 10)[1]
bot = zp.px(0, FY0 + 10 * CELL - 10)[1]
org = cell_center(7, 6)[1]
zp.make_beam(bx, bot, top, org, vertical=True)

# Sakte token at col 3 row 3
tk = zp.make_token_sakte("sakte")
tx, ty = cell_center(3, 3)
tk.location = (tx, ty, 0.06)
tk2 = zp.make_token_sakte("sakte2")
tx, ty = cell_center(10, 12)
tk2.location = (tx, ty, 0.06)

# balls (3) with motion trails
def trail(loc, vel, length=1.3):
    v = Vector(vel).normalized()
    pl = zp.plane("trail", 0.40, length)
    pl.location = (loc[0] - v.x * length / 2, loc[1] - v.y * length / 2, 0.05)
    pl.rotation_euler.z = math.atan2(v.y, v.x) - math.pi / 2
    m = bpy.data.materials.new("trail_m")
    m.use_nodes = True
    nt = m.node_tree
    for x in list(nt.nodes):
        nt.nodes.remove(x)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    pp = nt.nodes.new("ShaderNodeMath")
    pp.operation = "PINGPONG"
    pp.inputs[1].default_value = 0.5
    w = nt.nodes.new("ShaderNodeMath")
    w.operation = "MULTIPLY"
    nt.links.new(tc.outputs["UV"], sep.inputs[0])
    # across: 0 at edges, 0.5 centre -> power; along: v
    sharp = nt.nodes.new("ShaderNodeMath")
    sharp.operation = "POWER"
    sharp.inputs[1].default_value = 1.6
    nt.links.new(sep.outputs[0], pp.inputs[0])
    nt.links.new(pp.outputs[0], sharp.inputs[0])
    along = nt.nodes.new("ShaderNodeMath")
    along.operation = "POWER"
    along.inputs[1].default_value = 2.0
    nt.links.new(sep.outputs[1], along.inputs[0])
    nt.links.new(sharp.outputs[0], w.inputs[0])
    nt.links.new(along.outputs[0], w.inputs[1])
    k = nt.nodes.new("ShaderNodeMath")
    k.operation = "MULTIPLY"
    k.inputs[1].default_value = 9.0
    nt.links.new(w.outputs[0], k.inputs[0])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = zp.col("orb_shell")
    nt.links.new(k.outputs[0], em.inputs["Strength"])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    ad = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(tr.outputs[0], ad.inputs[0])
    nt.links.new(em.outputs[0], ad.inputs[1])
    nt.links.new(ad.outputs[0], out.inputs[0])
    try:
        m.surface_render_method = "BLENDED"
    except AttributeError:
        pass
    pl.data.materials.append(m)


for i, (bxp, byp, vel) in enumerate(((440, 360, (1, -0.6)), (760, 650, (-1, -0.75)))):
    o = zp.make_orb(f"orb{i}")
    wx, wy = zp.px(bxp, byp)
    o.location = (wx, wy, 0.26)
    trail((wx, wy), vel)

# wrist-strip: nothing tappable; planet limb shows there
zp.bloom(threshold=0.9, size=7)
sc.render.film_transparent = False
sc.render.image_settings.file_format = "PNG"
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
if BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print("WROTE", OUT)
