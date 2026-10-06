"""Shared Blender builders for the MWM Orb Fence look (deep-space force field).

Run inside Blender 4.5 (imported by world1_mock.py, elements.py, export_assets.py).
Units: metres. 1 logic px = 0.01 m on the play plane (z = 0), camera looks down -Z.
"""

import math
import random

import bmesh
import bpy
from mathutils import Vector

# ---- palette (linear-ish sRGB hex, converted below) -----------------------------
HEX = {
    "void": "#050816",
    "field_glass": "#0A1430",
    "grid": "#3D7BFF",
    "rail": "#1A2238",
    "rail_light": "#5AA9FF",
    "crystal_w1": "#7FB6FF",
    "crystal_w1_deep": "#3F6FD8",
    "rim": "#E6F3FF",
    "beam": "#FFC94D",
    "beam_core": "#FFF6DA",
    "orb_shell": "#FF6F61",
    "orb_core": "#FFF4EC",
    "orb_ring": "#FFFFFF",
    "rock": "#6B5E57",
    "rock_dark": "#3A332F",
    "token": "#5CF2B8",
    "token_icon": "#FFFFFF",
    "frost": "#BFE6FF",
}


def srgb_to_lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def col(name_or_hex: str, a: float = 1.0):
    h = HEX.get(name_or_hex, name_or_hex).lstrip("#")
    r, g, b = (int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))
    return (srgb_to_lin(r), srgb_to_lin(g), srgb_to_lin(b), a)


# ---- scene helpers ---------------------------------------------------------------
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    try:
        sc.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    return sc


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def mesh_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new(name, me))


def set_smooth(ob, smooth=True):
    for p in ob.data.polygons:
        p.use_smooth = smooth


def principled(name, base, rough=0.4, metal=0.0, emit=None, emit_str=0.0, coat=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n = next(x for x in m.node_tree.nodes if x.type == "BSDF_PRINCIPLED")
    n.inputs["Base Color"].default_value = col(base)
    n.inputs["Roughness"].default_value = rough
    n.inputs["Metallic"].default_value = metal
    if emit:
        n.inputs["Emission Color"].default_value = col(emit)
        n.inputs["Emission Strength"].default_value = emit_str
    if coat:
        n.inputs["Coat Weight"].default_value = coat
        n.inputs["Coat Roughness"].default_value = 0.05
    if alpha < 1.0:
        n.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except AttributeError:
            m.blend_method = "BLEND"
    return m


def emissive(name, color, strength, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for x in list(nt.nodes):
        nt.nodes.remove(x)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = col(color)
    em.inputs["Strength"].default_value = strength
    if alpha < 1.0:
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mix = nt.nodes.new("ShaderNodeMixShader")
        mix.inputs[0].default_value = alpha
        nt.links.new(tr.outputs[0], mix.inputs[1])
        nt.links.new(em.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs[0])
        try:
            m.surface_render_method = "BLENDED"
        except AttributeError:
            m.blend_method = "BLEND"
    else:
        nt.links.new(em.outputs[0], out.inputs[0])
    return m


def radial_glow(name, color, strength, falloff=2.0):
    """Additive-looking soft disc: emission * (1-r)^falloff over transparent (halo quad)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for x in list(nt.nodes):
        nt.nodes.remove(x)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    grad = nt.nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Location"].default_value = (0.0, 0.0, 0.0)
    pw = nt.nodes.new("ShaderNodeMath")
    pw.operation = "POWER"
    pw.inputs[1].default_value = falloff
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = col(color)
    em.inputs["Strength"].default_value = strength
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    mp.inputs["Location"].default_value = (-1.0, -1.0, 0.0)
    mp.inputs["Scale"].default_value = (2.0, 2.0, 0.0)
    nt.links.new(tc.outputs["Generated"], mp.inputs[0])
    nt.links.new(mp.outputs[0], grad.inputs[0])
    nt.links.new(grad.outputs["Fac"], pw.inputs[0])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = strength
    nt.links.new(pw.outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], em.inputs["Strength"])
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs[0])
    try:
        m.surface_render_method = "BLENDED"
    except AttributeError:
        m.blend_method = "BLEND"
    return m


def add_mat(ob, m):
    ob.data.materials.append(m)
    return ob


# ---- primitives -------------------------------------------------------------------
def rounded_box(name, sx, sy, sz, bevel, segs=3):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segs, profile=0.5, affect="EDGES")
    ob = mesh_obj(name, bm)
    set_smooth(ob)
    return ob


def cylinder(name, r, length, verts=16, axis="Y"):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r, depth=length)
    if axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(math.radians(90), 3, "X"))
    elif axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(math.radians(90), 3, "Y"))
    ob = mesh_obj(name, bm)
    set_smooth(ob)
    return ob


def uv_sphere(name, r, seg=32, rings=16):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    ob = mesh_obj(name, bm)
    set_smooth(ob)
    return ob


def plane(name, sx, sy):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
    bm.verts.ensure_lookup_table()
    ob = mesh_obj(name, bm)
    ob.data.uv_layers.new(name="UVMap")
    return ob


def torus(name, major, minor, seg=48, mseg=12):
    bm = bmesh.new()
    verts = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for j in range(mseg):
            b = 2 * math.pi * j / mseg
            r = major + minor * math.cos(b)
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), minor * math.sin(b))))
        verts.append(ring)
    for i in range(seg):
        for j in range(mseg):
            a, b = verts[i][j], verts[i][(j + 1) % mseg]
            c, d = verts[(i + 1) % seg][(j + 1) % mseg], verts[(i + 1) % seg][j]
            bm.faces.new((a, b, c, d))
    ob = mesh_obj(name, bm)
    set_smooth(ob)
    return ob


# ---- game parts -------------------------------------------------------------------
def crystal_tile_mesh(name="crystal_tile", size=0.70, base_h=0.05, apex_h=0.13, apex_off=(0.09, 0.05)):
    """Square gem slab: bevelled base + off-centre low pyramid (5 facets read as crystal).
    Off-centre apex means a random 90-degree turn per instance varies the facets."""
    bm = bmesh.new()
    s = size / 2
    inset = 0.07
    b = [bm.verts.new((x, y, 0.0)) for x, y in ((-s, -s), (s, -s), (s, s), (-s, s))]
    t = [bm.verts.new((x, y, base_h)) for x, y in ((-s, -s), (s, -s), (s, s), (-s, s))]
    si = s - inset
    ti = [bm.verts.new((x, y, base_h + 0.035)) for x, y in ((-si, -si), (si, -si), (si, si), (-si, si))]
    apex = bm.verts.new((apex_off[0], apex_off[1], apex_h))
    bm.faces.new(list(reversed(b)))
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((b[i], b[j], t[j], t[i]))
        bm.faces.new((t[i], t[j], ti[j], ti[i]))
        bm.faces.new((ti[i], ti[j], apex))
    ob = mesh_obj(name, bm)
    set_smooth(ob, False)
    return ob


def make_orb(name, r=0.24, ring=True, mats=None):
    """Glowing orb ball: emissive core (white centre to coral rim) + tilted ring = 'ball' shape cue."""
    core = uv_sphere(name, r, 32, 16)
    m = bpy.data.materials.new(name + "_mat")
    m.use_nodes = True
    nt = m.node_tree
    for x in list(nt.nodes):
        nt.nodes.remove(x)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.45
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = col("orb_core")
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = col("orb_shell")
    e = ramp.color_ramp.elements.new(0.35)
    e.color = col("#FFB3A6")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 3.2
    nt.links.new(lw.outputs["Facing"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], em.inputs[0])
    nt.links.new(em.outputs[0], out.inputs[0])
    core.data.materials.append(m)
    parts = [core]
    if ring:
        rg = torus(name + "_ring", r * 1.55, r * 0.085)
        rg.data.materials.append(emissive(name + "_ringmat", "orb_ring", 3.5))
        rg.rotation_euler = (math.radians(68), math.radians(-18), 0)
        rg.parent = core
        parts.append(rg)
    halo = plane(name + "_halo", r * 5.0, r * 5.0)
    halo.data.materials.append(radial_glow(name + "_halomat", "orb_shell", 1.6, 2.2))
    halo.location.z = -0.05
    halo.parent = core
    parts.append(halo)
    return core


def make_rock(name, r=0.33, seed=3):
    random.seed(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    for v in bm.verts:
        n = v.co.normalized()
        k = 1.0 + 0.16 * math.sin(7 * n.x + seed) * math.cos(5 * n.y) + random.uniform(-0.07, 0.07)
        v.co = n * r * k
        v.co.z *= 0.72
    ob = mesh_obj(name, bm)
    set_smooth(ob, False)
    m = principled(name + "_mat", "rock", rough=0.85)
    # crater tint via voronoi
    nt = m.node_tree
    bsdf = next(x for x in nt.nodes if x.type == "BSDF_PRINCIPLED")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 6.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = col("rock_dark")
    ramp.color_ramp.elements[1].position = 0.35
    ramp.color_ramp.elements[1].color = col("rock")
    nt.links.new(vor.outputs["Distance"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    ob.data.materials.append(m)
    return ob


def make_token_sakte(name, r=0.30):
    """'Sakte' (slow) token: mint disc with a white snail-shell spiral. Spiral = slow, not colour."""
    disc = cylinder(name, r, 0.07, 40, axis="Z")
    disc.data.materials.append(principled(name + "_mat", "token", rough=0.25, emit="token", emit_str=0.5, coat=1.0))
    # spiral as a curve
    cu = bpy.data.curves.new(name + "_spiral", "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    pts = []
    turns = 2.3
    n = 70
    for i in range(n):
        t = i / (n - 1)
        a = t * turns * 2 * math.pi
        rr = 0.03 + t * r * 0.62
        pts.append((rr * math.cos(a), rr * math.sin(a), 0.05))
    sp.points.add(len(pts) - 1)
    for p, c in zip(sp.points, pts):
        p.co = (*c, 1)
    cu.bevel_depth = 0.022
    cu.bevel_resolution = 3
    sob = link(bpy.data.objects.new(name + "_spiral", cu))
    sob.data.materials.append(emissive(name + "_iconmat", "token_icon", 2.5))
    sob.parent = disc
    ring = torus(name + "_rim", r * 1.04, 0.025, 48, 8)
    ring.data.materials.append(emissive(name + "_rimmat", "token_icon", 2.0))
    ring.location.z = 0.035
    ring.parent = disc
    halo = plane(name + "_halo", r * 3.6, r * 3.6)
    halo.data.materials.append(radial_glow(name + "_halomat", "token", 0.9, 2.5))
    halo.location.z = -0.04
    halo.parent = disc
    return disc


def make_frame(x0, y0, x1, y1, width=0.22, depth=0.22):
    """Force-field frame: gunmetal rails + inner blue emitter line + hex emitter nodes at corners."""
    rail_m = principled("rail", "rail", rough=0.32, metal=0.8, coat=0.6)
    light_m = emissive("rail_light", "rail_light", 3.0)
    node_m = principled("node", "#2A3550", rough=0.25, metal=0.85, coat=1.0)
    node_light = emissive("node_light", "#8FD0FF", 6.0)
    obs = []
    w = width
    for name, cx, cy, sx, sy in (
        ("rail_top", (x0 + x1) / 2, y1 + w / 2, x1 - x0 + 2 * w, w),
        ("rail_bot", (x0 + x1) / 2, y0 - w / 2, x1 - x0 + 2 * w, w),
        ("rail_l", x0 - w / 2, (y0 + y1) / 2, w, y1 - y0),
        ("rail_r", x1 + w / 2, (y0 + y1) / 2, w, y1 - y0),
    ):
        ob = rounded_box(name, sx, sy, depth, 0.05)
        ob.location = (cx, cy, depth / 2 - 0.06)
        add_mat(ob, rail_m)
        obs.append(ob)
    # inner light lines
    t = 0.022
    for name, cx, cy, sx, sy in (
        ("lt", (x0 + x1) / 2, y1 + 0.01, x1 - x0, t),
        ("lb", (x0 + x1) / 2, y0 - 0.01, x1 - x0, t),
        ("ll", x0 - 0.01, (y0 + y1) / 2, t, y1 - y0),
        ("lr", x1 + 0.01, (y0 + y1) / 2, t, y1 - y0),
    ):
        ob = rounded_box(name, sx, sy, 0.03, 0.008, 1)
        ob.location = (cx, cy, 0.04)
        add_mat(ob, light_m)
    for i, (cx, cy) in enumerate(((x0, y0), (x1, y0), (x0, y1), (x1, y1))):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.30, radius2=0.30, depth=0.30)
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.035, segments=2, affect="EDGES")
        nd = mesh_obj(f"node{i}", bm)
        set_smooth(nd)
        nd.location = (cx - math.copysign(w / 2, (x0 + x1) / 2 - cx), cy - math.copysign(w / 2, (y0 + y1) / 2 - cy), 0.12)
        add_mat(nd, node_m)
        lens = cylinder(f"lens{i}", 0.13, 0.05, 24, axis="Z")
        lens.location = nd.location + Vector((0, 0, 0.16))
        add_mat(lens, node_light)
    return obs


def make_beam(x, y_a, y_b, origin_y, vertical=True, dash=0.40, gap=0.14):
    """Wall being built: thin white core + gold dashed sleeve + diamond heads + origin ring."""
    core_m = emissive("beam_core", "beam_core", 9.0)
    sleeve_m = emissive("beam_sleeve", "beam", 4.0)
    head_m = emissive("beam_head", "#FFFFFF", 14.0)
    lo, hi = min(y_a, y_b), max(y_a, y_b)
    L = hi - lo
    core = cylinder("beam_core", 0.035, L, 12, axis="Y" if vertical else "X")
    core.location = (x, (lo + hi) / 2, 0.10) if vertical else ((lo + hi) / 2, x, 0.10)
    add_mat(core, core_m)
    # dashes laid out from the origin outward both ways
    for direction in (1, -1):
        p = origin_y + direction * 0.05
        while (direction > 0 and p + dash <= hi) or (direction < 0 and p - dash >= lo):
            c = p + direction * dash / 2
            d = rounded_box("dash", 0.15 if vertical else dash, dash if vertical else 0.15, 0.12, 0.05, 2)
            d.location = (x, c, 0.10) if vertical else (c, x, 0.10)
            add_mat(d, sleeve_m)
            p += direction * (dash + gap)
    for yy, sgn in ((hi, 1), (lo, -1)):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=0, radius=0.17)
        hd = mesh_obj("head", bm)
        hd.scale = (0.8, 1.3, 0.8) if vertical else (1.3, 0.8, 0.8)
        hd.location = (x, yy, 0.12) if vertical else (yy, x, 0.12)
        add_mat(hd, head_m)
        hl = plane("headglow", 1.2, 1.2)
        hl.location = (hd.location.x, hd.location.y, 0.06)
        add_mat(hl, radial_glow("headglowm", "beam", 2.5, 2.0))
    og = torus("origin", 0.20, 0.03, 32, 8)
    og.location = (x, origin_y, 0.12) if vertical else (origin_y, x, 0.12)
    add_mat(og, emissive("origin_m", "beam", 6.0))
    bl = plane("beamglow", 0.75 if vertical else L, L if vertical else 0.75)
    bl.location = (x, (lo + hi) / 2, 0.03) if vertical else ((lo + hi) / 2, x, 0.03)
    m = bpy.data.materials.new("beamglow_m")
    m.use_nodes = True
    nt = m.node_tree
    for n_ in list(nt.nodes):
        nt.nodes.remove(n_)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    f = nt.nodes.new("ShaderNodeMath")
    f.operation = "PINGPONG"
    f.inputs[1].default_value = 0.5
    sm = nt.nodes.new("ShaderNodeMath")
    sm.operation = "POWER"
    sm.inputs[1].default_value = 2.5
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 4.0 * 2.0
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = col("beam")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(tc.outputs["UV"], sep.inputs[0])
    nt.links.new(sep.outputs[0 if vertical else 1], f.inputs[0])
    nt.links.new(f.outputs[0], sm.inputs[0])
    nt.links.new(sm.outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], em.inputs["Strength"])
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs[0])
    try:
        m.surface_render_method = "BLENDED"
    except AttributeError:
        pass
    add_mat(bl, m)


# ---- ball trail (additive tapered ribbon) ----
def trail(loc, vel, length=1.3, width=0.40, z=0.05):
    v = Vector(vel).normalized()
    pl = plane("trail", width, length)
    pl.location = (loc[0] - v.x * length / 2, loc[1] - v.y * length / 2, z)
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
    em.inputs["Color"].default_value = col("orb_shell")
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




# ---- backdrop ---------------------------------------------------------------------
def star_world(strength=1.0):
    w = bpy.data.worlds.new("space")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    for x in list(nt.nodes):
        nt.nodes.remove(x)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    total = None
    for scale, thr, s in ((180.0, 0.05, 1.6), (70.0, 0.035, 3.5)):
        vor = nt.nodes.new("ShaderNodeTexVoronoi")
        vor.inputs["Scale"].default_value = scale
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = thr
        mr.inputs["From Max"].default_value = 0.0
        mr.inputs["To Max"].default_value = s
        nt.links.new(tc.outputs["Generated"], vor.inputs["Vector"])
        nt.links.new(vor.outputs["Distance"], mr.inputs["Value"])
        if total is None:
            total = mr
        else:
            ad = nt.nodes.new("ShaderNodeMath")
            ad.operation = "ADD"
            nt.links.new(total.outputs[0], ad.inputs[0])
            nt.links.new(mr.outputs[0], ad.inputs[1])
            total = ad
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = col("void")
    mix.inputs["B"].default_value = (1.0, 1.0, 1.0, 1)
    clamp = nt.nodes.new("ShaderNodeClamp")
    nt.links.new(total.outputs[0], clamp.inputs[0])
    nt.links.new(clamp.outputs[0], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength
    nt.links.new(bg.outputs[0], out.inputs[0])


def nebula_plane(name, size, z, colors, seed=0.0, strength=1.2, scale=1.3):
    """Big emissive cloud card. colors = list of (pos, hex) for the ramp; alpha from noise."""
    ob = plane(name, size, size)
    ob.location.z = z
    m = bpy.data.materials.new(name + "_m")
    m.use_nodes = True
    nt = m.node_tree
    for x in list(nt.nodes):
        nt.nodes.remove(x)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Location"].default_value = (seed, seed * 0.7, seed * 0.3)
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = 9.0
    nz.inputs["Roughness"].default_value = 0.62
    nz.inputs["Distortion"].default_value = 0.6
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = colors[0][0], col(colors[0][1])
    els[1].position, els[1].color = colors[-1][0], col(colors[-1][1])
    for pos, hx in colors[1:-1]:
        e = els.new(pos)
        e.color = col(hx)
    dens = nt.nodes.new("ShaderNodeMapRange")
    dens.inputs["From Min"].default_value = 0.36
    dens.inputs["From Max"].default_value = 0.72
    # soft edge falloff toward the card border
    grad = nt.nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    mp2 = nt.nodes.new("ShaderNodeMapping")
    mp2.inputs["Scale"].default_value = (1.6, 1.6, 1.6)
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    em = nt.nodes.new("ShaderNodeEmission")
    smul = nt.nodes.new("ShaderNodeMath")
    smul.operation = "MULTIPLY"
    smul.inputs[1].default_value = strength
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(tc.outputs["Generated"], mp.inputs[0])
    nt.links.new(mp.outputs[0], nz.inputs["Vector"])
    nt.links.new(nz.outputs["Fac"], ramp.inputs[0])
    nt.links.new(nz.outputs["Fac"], dens.inputs["Value"])
    nt.links.new(tc.outputs["Generated"], mp2.inputs[0])
    mp2.inputs["Location"].default_value = (-0.8, -0.8, 0)
    nt.links.new(mp2.outputs[0], grad.inputs[0])
    nt.links.new(dens.outputs[0], mul.inputs[0])
    nt.links.new(grad.outputs["Fac"], mul.inputs[1])
    nt.links.new(mul.outputs[0], smul.inputs[0])
    nt.links.new(ramp.outputs[0], em.inputs["Color"])
    nt.links.new(smul.outputs[0], em.inputs["Strength"])
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs[0])
    try:
        m.surface_render_method = "BLENDED"
    except AttributeError:
        pass
    ob.data.materials.append(m)
    return ob


def planet(name, r, loc, ramp_cols, band_scale=(1.0, 1.0, 4.0), atmo=None, atmo_str=2.0, noise_scale=3.0, rough=0.7):
    ob = uv_sphere(name, r, 96, 48)
    ob.location = loc
    m = bpy.data.materials.new(name + "_m")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(x for x in nt.nodes if x.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = rough
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = tuple(b / r for b in band_scale)
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = noise_scale
    nz.inputs["Detail"].default_value = 8.0
    nz.inputs["Distortion"].default_value = 1.2
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = ramp_cols[0][0], col(ramp_cols[0][1])
    els[1].position, els[1].color = ramp_cols[-1][0], col(ramp_cols[-1][1])
    for pos, hx in ramp_cols[1:-1]:
        e = els.new(pos)
        e.color = col(hx)
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    nt.links.new(mp.outputs[0], nz.inputs["Vector"])
    nt.links.new(nz.outputs["Fac"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    ob.data.materials.append(m)
    if atmo:
        a = uv_sphere(name + "_atmo", r * 1.035, 96, 48)
        a.location = loc
        am = bpy.data.materials.new(name + "_atmo_m")
        am.use_nodes = True
        nt = am.node_tree
        for x in list(nt.nodes):
            nt.nodes.remove(x)
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        lw = nt.nodes.new("ShaderNodeLayerWeight")
        lw.inputs["Blend"].default_value = 0.2
        pw = nt.nodes.new("ShaderNodeMath")
        pw.operation = "POWER"
        pw.inputs[1].default_value = 3.0
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = atmo_str
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = col(atmo)
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        add = nt.nodes.new("ShaderNodeAddShader")
        nt.links.new(lw.outputs["Facing"], pw.inputs[0])
        nt.links.new(pw.outputs[0], mul.inputs[0])
        nt.links.new(mul.outputs[0], em.inputs["Strength"])
        nt.links.new(tr.outputs[0], add.inputs[0])
        nt.links.new(em.outputs[0], add.inputs[1])
        nt.links.new(add.outputs[0], out.inputs[0])
        try:
            am.surface_render_method = "BLENDED"
        except AttributeError:
            pass
        a.data.materials.append(am)
    return ob


def bloom(threshold=1.0, size=7, mix=0.0):
    sc = bpy.context.scene
    sc.use_nodes = True
    nt = sc.node_tree
    for x in list(nt.nodes):
        nt.nodes.remove(x)
    rl = nt.nodes.new("CompositorNodeRLayers")
    comp = nt.nodes.new("CompositorNodeComposite")
    g = nt.nodes.new("CompositorNodeGlare")
    for gt in ("BLOOM", "FOG_GLOW"):
        try:
            g.glare_type = gt
            break
        except TypeError:
            continue
    for attr, val in (("threshold", threshold), ("size", size), ("mix", mix), ("quality", "HIGH")):
        try:
            setattr(g, attr, val)
        except (AttributeError, TypeError):
            pass
    # Blender 4.5 moved some glare options to inputs
    for key, val in (("Threshold", threshold), ("Size", size / 9.0), ("Strength", 1.0)):
        if key in g.inputs:
            try:
                g.inputs[key].default_value = val
            except TypeError:
                pass
    nt.links.new(rl.outputs["Image"], g.inputs["Image"])
    nt.links.new(g.outputs["Image"], comp.inputs["Image"])


def camera_px(res_x=1080, res_y=1920, dist=30.0):
    """Perspective camera whose z=0 plane maps 1 px = 0.01 m, centred on px (540, 960)."""
    sc = bpy.context.scene
    sc.render.resolution_x = res_x
    sc.render.resolution_y = res_y
    sc.render.resolution_percentage = 100
    cd = bpy.data.cameras.new("cam")
    cd.sensor_fit = "VERTICAL"
    cd.sensor_height = 36.0
    cd.lens = dist * 36.0 / (res_y * 0.01)
    cd.clip_end = 2000
    cam = link(bpy.data.objects.new("cam", cd))
    cam.location = (0, 0, dist)
    sc.camera = cam
    return cam


def px(x, y):
    return ((x - 540) * 0.01, (960 - y) * 0.01)
