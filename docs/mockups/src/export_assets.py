"""Export game-ready parts and world 1 backdrop layers.

blender -b -P export_assets.py -- <models_dir> <textures_dir>
GLB: Y-up (glTF default), metres, origin at the centre, 1 logic px = 0.01 m.
Materials in the GLBs are placeholders: the Godot shaders in DESIGN.md section 7 replace them.
Textures: world1_sky.png (opaque 1152x2048), world1_planet.png and world1_moon.png (alpha cards).
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
import zb_parts as zp  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :]
MODELS, TEX = Path(argv[0]), Path(argv[1])
MODELS.mkdir(parents=True, exist_ok=True)
TEX.mkdir(parents=True, exist_ok=True)


def export(name, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=str(MODELS / f"{name}.glb"), export_format="GLB", use_selection=True, export_apply=True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs if o.type == "MESH")
    print(f"GLB {name}: {tris} tris")


def tree(root):
    out = [root]
    for c in root.children_recursive:
        if not c.name.split(".")[0].endswith("_halo"):
            out.append(c)
    return out


def curve_to_mesh(o):
    if o.type != "CURVE":
        return o
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
    return bpy.context.view_layer.objects.active


# ---------------- models ----------------
zp.reset_scene()
o = zp.make_orb("ball_orb")
export("ball_orb", tree(o))

zp.reset_scene()
o = zp.make_orb("ball_stor", r=0.34)
r2 = zp.torus("ball_stor_ring2", 0.34 * 1.85, 0.025)
r2.data.materials.append(zp.emissive("r2", "orb_ring", 3.0))
r2.rotation_euler = (math.radians(68), math.radians(-18), 0)
r2.parent = o
export("ball_stor", tree(o))

zp.reset_scene()
t = zp.crystal_tile_mesh(apex_h=0.26, apex_off=(0.12, 0.07))
t.data.materials.append(zp.principled("crystal", "crystal_w1", rough=0.08, coat=1.0))
export("crystal_tile", [t])

zp.reset_scene()
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
for v in bm.verts:
    v.co = Vector((v.co.x * 0.70, v.co.y * 0.70, v.co.z * 0.34))
bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.09, segments=1, affect="EDGES")
st = zp.mesh_obj("stone_block", bm)
st.data.materials.append(zp.principled("stone", "rock", rough=0.85))
export("stone_block", [st])
face = zp.rounded_box("mirror_face", 0.86, 0.10, 0.06, 0.02, 2)
face.location = (0, 0, 0.19)
face.rotation_euler.z = math.radians(45)
face.data.materials.append(zp.principled("mirror", "#E8FBFF", rough=0.03, metal=1.0, emit="#BFF4FF", emit_str=2.5))
face.parent = st
export("mirror_block", [st, face])

for name, colr, icon in (("token_snegl", "token", "spiral"), ("token_lyn", "#6CD0FF", "bolt"), ("token_skjold", "#B79CFF", "hex")):
    zp.reset_scene()
    if icon == "spiral":
        d = zp.make_token_sakte(name)
        parts = [curve_to_mesh(c) if c.type == "CURVE" else c for c in tree(d)]
        export(name, parts)
        continue
    d = zp.cylinder(name, 0.30, 0.07, 40, axis="Z")
    d.data.materials.append(zp.principled(name + "_m", colr, rough=0.25, emit=colr, emit_str=0.5, coat=1.0))
    rim = zp.torus(name + "_rim", 0.312, 0.025, 48, 8)
    rim.location.z = 0.035
    rim.data.materials.append(zp.emissive("rim", "#FFFFFF", 2.0))
    rim.parent = d
    if icon == "bolt":
        pts = [(0.05, 0.22), (-0.10, 0.0), (0.0, 0.0), (-0.06, -0.22), (0.11, 0.04), (0.01, 0.04)]
        b2 = bmesh.new()
        f = b2.faces.new([b2.verts.new((x, y, 0)) for x, y in pts])
        ext = bmesh.ops.extrude_face_region(b2, geom=[f])
        for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
            v.co.z += 0.04
        ic = zp.mesh_obj(name + "_icon", b2)
    else:
        ic = zp.torus(name + "_icon", 0.16, 0.03, 6, 6)
        ic.rotation_euler.z = math.radians(30)
    ic.location.z = 0.05
    ic.data.materials.append(zp.emissive("icon", "#FFFFFF", 2.5))
    ic.parent = d
    export(name, [d, rim, ic])

zp.reset_scene()
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.30, radius2=0.30, depth=0.30)
bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.035, segments=2, affect="EDGES")
nd = zp.mesh_obj("frame_node", bm)
nd.data.materials.append(zp.principled("node", "#2A3550", rough=0.25, metal=0.85, coat=1.0))
lens = zp.cylinder("frame_node_lens", 0.13, 0.05, 24, axis="Z")
lens.location.z = 0.16
lens.data.materials.append(zp.emissive("lens", "#8FD0FF", 6.0))
lens.parent = nd
export("frame_node", [nd, lens])

# ---------------- world 1 backdrop layers ----------------
def backdrop_cam(res_x, res_y, ortho=None, loc=(0, 0, 30), lens_mm=None):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = res_x, res_y
    cd = bpy.data.cameras.new("cam")
    cd.clip_end = 3000
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.sensor_fit = "VERTICAL"
        cd.sensor_height = 36
        cd.lens = lens_mm
    cam = zp.link(bpy.data.objects.new("cam", cd))
    cam.location = loc
    sc.camera = cam


def render(path, transparent):
    sc = bpy.context.scene
    sc.render.film_transparent = transparent
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print("TEX", path)


# sky: same framing as world1_mock but 1152x2048 (covers 1080x1920 and tablets by crop)
zp.reset_scene()
backdrop_cam(1152, 2048, lens_mm=30 * 36.0 / 20.48)
zp.star_world(1.0)
zp.nebula_plane("neb_a", 240, -150, [(0.0, "#071233"), (0.45, "#0E3D66"), (0.62, "#0B6A78"), (0.8, "#2B3F9E"), (1.0, "#3A2C86")], seed=2.3, strength=2.0, scale=2.2)
zp.nebula_plane("neb_b", 200, -140, [(0.0, "#061024"), (0.5, "#15306E"), (0.75, "#1F7F8C"), (1.0, "#8FE3E0")], seed=7.1, strength=1.2, scale=3.5).location.x = 20
render(TEX / "world1_sky.png", False)


def lit():
    sun = bpy.data.lights.new("key", "SUN")
    sun.energy = 3.2
    so = zp.link(bpy.data.objects.new("key", sun))
    so.rotation_euler = Vector((0.55, -0.55, -0.62)).normalized().to_track_quat("-Z", "Y").to_euler()


zp.reset_scene()
w = bpy.data.worlds.new("black")
bpy.context.scene.world = w
lit()
zp.planet("home", 1.0, (0, 0, 0), [(0.0, "#0B2F5A"), (0.42, "#1466A0"), (0.55, "#2C9CC4"), (0.62, "#E8F4FF"), (0.7, "#1F7FB0"), (1.0, "#0A3A6E")], band_scale=(1.0, 1.0, 2.6), atmo="#5FD3FF", atmo_str=3.0, noise_scale=2.4)
backdrop_cam(1024, 1024, ortho=2.16)
render(TEX / "world1_planet.png", True)

zp.reset_scene()
w = bpy.data.worlds.new("black")
bpy.context.scene.world = w
lit()
zp.planet("moon", 1.0, (0, 0, 0), [(0.0, "#5E6577"), (0.5, "#9AA3B5"), (1.0, "#C9D0DC")], band_scale=(1, 1, 1), noise_scale=6.0, rough=0.95)
backdrop_cam(512, 512, ortho=2.1)
render(TEX / "world1_moon.png", True)
