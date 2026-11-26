"""Sculpt adult female external anatomy directly into the existing Ara skin mesh.

The mons, labial folds, clitoral structures, vestibule and external openings
are surface deformations of the original skin mesh. Its material, UVs, vertex
groups and rig remain in place; no genital object is attached. This is an
anatomy sculpt pass requiring multi-angle visual review before acceptance.
On clothed exports, lower garments are fitted around the deformed body surface.

Ara GLB axes after Blender import: Z up, character facing -Y.
"""
import argparse
import os
import sys
import math

import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default=os.environ.get("ARA_INPUT"), required=not bool(os.environ.get("ARA_INPUT")))
    parser.add_argument("--output", default=os.environ.get("ARA_OUTPUT"), required=not bool(os.environ.get("ARA_OUTPUT")))
    parser.add_argument("--profile", choices=("female", "none"), default=os.environ.get("ARA_PROFILE"), required=not bool(os.environ.get("ARA_PROFILE")))
    parser.add_argument("--adult", action="store_true", default=os.environ.get("ARA_ADULT") == "1")
    parser.add_argument("--fit-existing", action="store_true", help="Only expand lower garments around anatomy already present in the input GLB")
    parser.add_argument("--deformation-scale", type=float, default=1.65, help="Scale the enhanced female anatomy relief targets")
    parser.add_argument("--no-canal", action="store_true", help="Skip the collapsed vaginal canal")
    parser.add_argument("--no-anus", action="store_true", help="Skip the anus and anal canal")
    parser.add_argument("--method", choices=("integrated", "hybrid"), default="integrated", help="Compare the integrated skin sculpt with an additional buried, skin-material loft treatment")
    return parser.parse_args(raw)


def material_name(obj):
    return " ".join(slot.material.name.lower() for slot in obj.material_slots if slot.material)


def mesh_world_bounds(obj):
    pts = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector(tuple(min(p[i] for p in pts) for i in range(3))),
        Vector(tuple(max(p[i] for p in pts) for i in range(3))),
    )


def build_bvh(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    verts = [obj.matrix_world @ v.co for v in mesh.vertices]
    polys = [list(p.vertices) for p in mesh.polygons]
    tree = BVHTree.FromPolygons(verts, polys, all_triangles=False)
    evaluated.to_mesh_clear()
    return tree


def front_hit_data(tree, x, z):
    location, normal, _index, _distance = tree.ray_cast(
        Vector((x, -2.0, z)), Vector((0.0, 1.0, 0.0)), 4.0
    )
    if location is None:
        return None
    return location, normal


def front_hit(tree, x, z):
    hit = front_hit_data(tree, x, z)
    return hit[0] if hit else None


def create_socket(armature, name, location, normal, bone_name):
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "SPHERE"
    empty.empty_display_size = 0.007
    bpy.context.collection.objects.link(empty)
    empty.parent = armature
    empty.parent_type = "BONE"
    empty.parent_bone = bone_name
    orientation = Vector((0.0, 0.0, 1.0)).rotation_difference(normal.normalized())
    empty.matrix_world = Matrix.Translation(location) @ orientation.to_matrix().to_4x4()
    empty["socket_type"] = name.replace("SOCKET_", "").lower()
    empty["review_anchor"] = "surface-derived"
    return empty


def bone_world_span(armature, names, fallback=None):
    for bone in armature.data.bones:
        if bone.name.lower() in names:
            a = armature.matrix_world @ bone.head_local
            b = armature.matrix_world @ bone.tail_local
            return min(a.z, b.z), max(a.z, b.z), bone.name
    if fallback:
        return fallback
    raise RuntimeError("Required anatomical rig landmark not found: " + "/".join(sorted(names)))


def pelvis_landmark_from_leg_roots(armature, height):
    """Use paired femur roots as the hip-joint line, not the long Hips bone midpoint."""
    aliases = {
        "left": {"leftupleg", "leftupperleg", "upleg_l", "upperleg_l",
                 "thigh_l", "leftthigh", "lthigh", "thigh.l"},
        "right": {"rightupleg", "rightupperleg", "upleg_r", "upperleg_r",
                  "thigh_r", "rightthigh", "rthigh", "thigh.r"},
    }
    found = {}
    for side, names in aliases.items():
        bone = next((b for b in armature.data.bones
                     if b.name.lower().replace(" ", "").replace("-", "_") in names), None)
        if bone is not None:
            found[side] = armature.matrix_world @ bone.head_local
    if len(found) != 2:
        relevant = ", ".join(b.name for b in armature.data.bones
                             if any(token in b.name.lower() for token in ("leg", "thigh", "upleg")))
        raise RuntimeError(
            "Cannot locate paired upper-leg roots for pelvic anatomy placement. "
            f"Found {sorted(found)}; relevant rig bones: {relevant or 'none'}"
        )
    z = (found["left"].z + found["right"].z) * 0.5
    print(
        "Pelvic landmark from paired upper-leg roots: "
        f"left={found['left'].z:.4f}, right={found['right'].z:.4f}, "
        f"centre={z:.4f}, character height={height:.4f}"
    )
    return z


def frontmost_vertex_anchor(obj, x_min, x_max, z_min, z_max):
    # Pick an actual evaluated skin vertex in a tightly bounded anatomical region.
    # The vertex normal gives a stable surface orientation for the accessory.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    best = None
    for v in mesh.vertices:
        p = obj.matrix_world @ v.co
        if not (x_min <= p.x <= x_max and z_min <= p.z <= z_max):
            continue
        n = (obj.matrix_world.to_3x3() @ v.normal).normalized()
        if n.y > -0.12:
            continue
        score = p.y
        if best is None or score < best[0]:
            best = (score, p.copy(), n.copy())
    evaluated.to_mesh_clear()
    return (best[1], best[2]) if best else None


def create_piercing_sockets(armature, skin, surface_tree, minimum, height, width, pelvis_z, body_front_y):
    bones = list(armature.data.bones)
    def find_bone(names, fallback):
        return next((b.name for b in bones if b.name.lower() in names), fallback)

    head_bone = find_bone({"head", "head01"}, find_bone({"neck"}, "Hips"))
    chest_bone = find_bone({"spine2", "spine_2", "chest"}, find_bone({"spine1", "spine_1"}, "Hips"))

    # Ear sockets are selected from the lateral ear contour, not a front-view
    # point on the cheek. Require a side-facing normal and the lower head band.
    ear_z = minimum.z + height * 0.875
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = skin.evaluated_get(depsgraph)
    mesh_eval = evaluated.to_mesh()
    for side, label in ((1.0, "L"), (-1.0, "R")):
        best = None
        for v in mesh_eval.vertices:
            p = skin.matrix_world @ v.co
            n = (skin.matrix_world.to_3x3() @ v.normal).normalized()
            if side*p.x < width*0.13 or side*p.x > width*0.29:
                continue
            if abs(p.z-ear_z) > height*0.035 or side*n.x < 0.22:
                continue
            score = side*n.x*2.0 - abs(p.z-ear_z)/max(height*0.035, 1e-5)
            if best is None or score > best[0]:
                best = (score, p.copy(), n.copy())
        if best:
            # Move the earring anchor just clear of the ear surface and slightly
            # forward of the hairline so hoops remain visible in the Workshop.
            earring_location = best[1] + best[2] * 0.003 + Vector((0.0, -0.005, 0.0))
            create_socket(armature, "SOCKET_Earring_" + label, earring_location, best[2], head_bone)
    evaluated.to_mesh_clear()

    # Nose ring sits 1 cm below the former anchor, with a fresh surface raycast
    # at that lower height so the socket remains flush to the nose.
    head_lo, head_hi, _ = bone_world_span(armature, {"head", "head01"},
                                          (minimum.z + height*.84, minimum.z + height*.96, head_bone))
    nose = frontmost_vertex_anchor(skin, -width*.055, width*.055,
                                   head_lo + (head_hi-head_lo)*.34,
                                   head_lo + (head_hi-head_lo)*.78)
    if nose:
        lowered = front_hit_data(surface_tree, nose[0].x, nose[0].z - 0.010)
        if lowered:
            create_socket(armature, "SOCKET_NoseRing", lowered[0], lowered[1], head_bone)

    necklace_hit = front_hit_data(surface_tree, 0.0, minimum.z + height * 0.82)
    if necklace_hit:
        create_socket(armature, "SOCKET_Necklace", necklace_hit[0], necklace_hit[1], chest_bone)

    # Use the actual breast-height band of the body. Do not derive this from
    # Spine1: on this Ara rig that bone can span the upper abdomen.
    # Use the skin mesh bounds rather than all character meshes (hair and
    # footwear distort whole-character height ratios). The earlier band sat too
    # low on this Ara body; keep the search above the navel and within the bust.
    skin_min, skin_max = mesh_world_bounds(skin)
    skin_height = skin_max.z - skin_min.z
    nipple_z0 = skin_min.z + skin_height * 0.69
    nipple_z1 = skin_min.z + skin_height * 0.84
    for side, label in ((1.0, "L"), (-1.0, "R")):
        x0, x1 = ((width*.055, width*.30) if side > 0 else (-width*.30, -width*.055))
        hit = frontmost_vertex_anchor(skin, x0, x1, nipple_z0, nipple_z1)
        if hit:
            create_socket(armature, "SOCKET_Nipple_" + label, hit[0], hit[1], chest_bone)


def uv_ellipsoid(name, location, scale, collection):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    collection.objects.link(obj)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj



def wire_vertex_colour_to_skin_material(material, attribute_name="Color"):
    """Multiply the existing skin texture by the exported anatomy vertex colours."""
    if material is None or not material.use_nodes:
        raise RuntimeError("Skin material must use nodes to display anatomy vertex colours")
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
    if shader is None:
        raise RuntimeError("Skin material has no Principled BSDF for anatomy colour integration")
    base = shader.inputs.get("Base Color")
    if base is None:
        raise RuntimeError("Skin shader has no Base Color input")
    # Avoid adding duplicate multipliers if this builder is run more than once.
    if any(node.get("anatomy_vertex_colour_layer") == attribute_name for node in nodes):
        return
    vertex_colour = nodes.new("ShaderNodeVertexColor")
    vertex_colour.layer_name = attribute_name
    vertex_colour.label = "Anatomy skin-tone variation"
    vertex_colour.name = "AnatomyVertexColour"
    vertex_colour.location = (shader.location.x - 420, shader.location.y - 180)
    multiply = nodes.new("ShaderNodeMixRGB")
    multiply.blend_type = "MULTIPLY"
    multiply.inputs["Fac"].default_value = 1.0
    multiply.label = "Preserve skin texture; apply anatomy tint"
    multiply.name = "AnatomyColourMultiply"
    multiply.location = (shader.location.x - 190, shader.location.y - 100)
    multiply["anatomy_vertex_colour_layer"] = attribute_name
    existing_links = list(base.links)
    if existing_links:
        original_socket = existing_links[0].from_socket
        for link in existing_links:
            links.remove(link)
        links.new(original_socket, multiply.inputs["Color1"])
    else:
        multiply.inputs["Color1"].default_value = (1.0, 1.0, 1.0, 1.0)
    links.new(vertex_colour.outputs["Color"], multiply.inputs["Color2"])
    links.new(multiply.outputs["Color"], base)
    print(f"Skin shader now multiplies its base texture by vertex colour layer {attribute_name!r}")


# ---------------------------------------------------------------------------
# Adult female external anatomy: surface-following sculpt.
#
# Every feature is defined in (t, x) surface coordinates, not world XYZ:
#   t = arc length along the body's midline surface, measured from the vaginal
#       introitus (t = 0); positive toward the mons, negative toward the perineum.
#   x = lateral distance from the midline.
# Each vertex is projected onto the midline curve to get its (t, x), then moved
# along its own surface normal. This keeps the detail on the skin where the
# pelvis curves under between the thighs, which a world-Y displacement cannot do.
#
# All values are metres for a 1.687 m body and are scaled by the character's
# height. Edit this block to fine-tune; no other code needs to change.
# ---------------------------------------------------------------------------
FEMALE_ANATOMY = {
    # landmark positions along the midline (t axis)
    "t_hood": 0.062, "t_glans": 0.047, "t_meatus": 0.024,
    "t_introitus": 0.0, "t_fourchette": -0.022, "t_mons": 0.092,
    # labia majora (outer folds) and the cleft between them
    "majora_height": 0.0125, "majora_x": 0.0190, "majora_sigma": 0.0118,
    "cleft_depth": 0.0058, "cleft_sigma": 0.0060,
    # labia minora (inner folds). minora_x is the centre of each fold.
    "minora_height": 0.0075, "minora_x": 0.0078, "minora_sigma": 0.0027,
    "minora_wave": 0.07, "minora_wave_len": 0.026,   # free-edge undulation
    "vestibule_depth": 0.0025,
    # clitoral complex and openings
    "hood_height": 0.0035, "glans_height": 0.0028,
    "meatus_depth": 0.0012, "introitus_depth": 0.0045,
    "fourchette_height": 0.0030, "mons_height": 0.0060,
    # overall prominence: scales EVERY raised or recessed component (mons, labia, hood, cleft, introitus ...)
    "prominence": 0.70,
    # slide the whole vulval complex toward the perineum (metres at 1.687 m height; positive = down/back).
    # 0.0 keeps the introitus where the midline search put it.
    "t_shift": 0.0,
    # local mesh density target (faces with longer edges are split)
    "target_edge": 0.0013,
    "posterior_floor": 0.03, "underside_ease": 0.0,   # keep relief out of the thigh gap
    "smooth_passes": 3, "smooth_factor": 0.35,   # post-sculpt softening of the folds
}


_FRAME = {}   # midline frame of the last sculpt, reused by pigmentation


def _ss(a, b, x):
    if a == b:
        return 1.0 if x >= b else 0.0
    u = max(0.0, min(1.0, (x - a) / (b - a)))
    return u * u * (3.0 - 2.0 * u)


def _g2(dx, dt, sx, st):
    return math.exp(-0.5 * ((dx / sx) ** 2 + (dt / st) ** 2))


def _env(t, a, b, w):
    """Smooth plateau: rises around a, falls around b."""
    return _ss(a - w, a + w, t) * (1.0 - _ss(b - w, b + w, t))


def _surface_midline(skin, hipline_z, k):
    """Ordered (y, z) polyline of the front/underside midline surface, plus arc length."""
    mw = skin.matrix_world
    rot = mw.to_3x3()
    pts = []
    for v in skin.data.vertices:
        p = mw @ v.co
        if abs(p.x) > 0.002 * k or not (hipline_z - 0.14 * k < p.z < hipline_z + 0.10 * k):
            continue
        n = (rot @ v.normal).normalized()
        if p.y > 0.0 or n.y > 0.35:
            continue
        pts.append((p.y, p.z))
    if len(pts) < 8:
        raise RuntimeError("Could not extract the pelvic midline surface (%d points)" % len(pts))
    cy, cz = -0.02 * k, hipline_z + 0.035 * k
    pts.sort(key=lambda q: math.atan2(-(q[1] - cz), -(q[0] - cy)))
    # light smoothing (1-2-1) to remove vertex jitter
    for _ in range(4):
        pts = [pts[0]] + [
            (0.25 * pts[i - 1][0] + 0.5 * pts[i][0] + 0.25 * pts[i + 1][0],
             0.25 * pts[i - 1][1] + 0.5 * pts[i][1] + 0.25 * pts[i + 1][1])
            for i in range(1, len(pts) - 1)] + [pts[-1]]
    # resample uniformly (1.5 mm)
    seg = [0.0]
    for i in range(1, len(pts)):
        seg.append(seg[-1] + math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]))
    step = 0.0015 * k
    out, s, j = [], 0.0, 0
    while s <= seg[-1]:
        while j < len(seg) - 2 and seg[j + 1] < s:
            j += 1
        f = (s - seg[j]) / max(seg[j + 1] - seg[j], 1e-9)
        out.append((pts[j][0] + f * (pts[j + 1][0] - pts[j][0]),
                    pts[j][1] + f * (pts[j + 1][1] - pts[j][1])))
        s += step
    arc = [i * step for i in range(len(out))]
    return out, arc


def _locate_introitus(line, arc, k):
    """The introitus sits where the front surface turns under: the foremost point of the underside."""
    zmin = min(p[1] for p in line)
    flat = [i for i, p in enumerate(line) if p[1] <= zmin + 0.004 * k]
    return min(flat, key=lambda i: line[i][0])


def _prep_line(line, arc):
    import numpy as np
    L = np.asarray(line, dtype=np.float64)
    A = np.asarray(arc, dtype=np.float64)
    d = L[1:] - L[:-1]
    return L[:-1], d, np.maximum((d * d).sum(1), 1e-12), A[:-1], A[1:] - A[:-1]


def _project_many(prep, ys, zs, chunk=4000):
    """Nearest point on the midline for many (y, z) points: returns (arc_length, distance) arrays."""
    import numpy as np
    a, d, L2, A0, dA = prep
    pts = np.stack([np.asarray(ys, dtype=np.float64), np.asarray(zs, dtype=np.float64)], 1)
    out_s, out_d = [], []
    for i in range(0, len(pts), chunk):
        p = pts[i:i + chunk]
        rel = p[:, None, :] - a[None, :, :]
        f = np.clip((rel * d[None]).sum(2) / L2[None], 0.0, 1.0)
        proj = a[None] + f[..., None] * d[None]
        d2 = ((p[:, None, :] - proj) ** 2).sum(2)
        j = d2.argmin(1)
        idx = np.arange(len(p))
        out_s.append(A0[j] + f[idx, j] * dA[j])
        out_d.append(np.sqrt(d2[idx, j]))
    if not out_s:
        return np.zeros(0), np.zeros(0)
    return np.concatenate(out_s), np.concatenate(out_d)


def _female_mons(t, x, P):
    """The broad mons mound. Separate from the fine vulval detail so it can fade out smoothly into the
    abdomen and hips (a hard cutoff here showed up as a raised plateau with a step edge)."""
    return P["mons_height"] * _g2(x, t - P["t_mons"], 0.050, 0.040)


def _female_displacement(t, x, P):
    """Outward displacement (m, in k-normalised units) at surface coords (t, x)."""
    ax = abs(x)
    th, tg, tm, ti, tf, tmons = (P["t_hood"], P["t_glans"], P["t_meatus"],
                                 P["t_introitus"], P["t_fourchette"], P["t_mons"])
    d = 0.0
    # labia majora: two rounded ridges that converge toward the mons and the fourchette
    xm = P["majora_x"] * (1.0 - 0.35 * _ss(th - 0.020, th + 0.012, t)) \
        * (1.0 - 0.45 * _ss(tf + 0.012, tf - 0.004, t))
    env_maj = _env(t, tf - 0.002, th - 0.006, 0.010)
    d += P["majora_height"] * env_maj * math.exp(-0.5 * ((ax - xm) / P["majora_sigma"]) ** 2)
    # cleft between the majora
    d -= P["cleft_depth"] * _env(t, tf + 0.004, th - 0.006, 0.006) * math.exp(-0.5 * (x / P["cleft_sigma"]) ** 2)
    # labia minora: thin folds, converging at the hood, with a wavy free edge
    xn = P["minora_x"] * (0.40 + 0.60 * _ss(th - 0.004, tm, t)) * (1.0 - 0.35 * _ss(tf + 0.012, tf + 0.002, t))
    wave = 1.0 + P["minora_wave"] * math.sin(2.0 * math.pi * t / P["minora_wave_len"])
    env_min = _env(t, tf + 0.008, tg, 0.006)       # fade out at the glans, not into the hood
    d += P["minora_height"] * wave * env_min * math.exp(-0.5 * ((ax - xn) / P["minora_sigma"]) ** 2)
    # vestibule floor between the minora
    d -= P["vestibule_depth"] * _env(t, ti - 0.006, tm + 0.004, 0.004) * math.exp(-0.5 * (x / 0.0045) ** 2)
    # clitoral hood and glans
    d += P["hood_height"] * _g2(x, t - (th - 0.004), 0.0045, 0.0075)
    d += P["glans_height"] * _g2(x, t - tg, 0.0021, 0.0022)
    # urethral meatus and vaginal introitus
    d -= P["meatus_depth"] * _g2(x, t - tm, 0.0013, 0.0016)
    d -= P["introitus_depth"] * _g2(x, t - ti, 0.0042, 0.0075)
    # posterior fourchette
    d += P["fourchette_height"] * _g2(x, t - tf, 0.008, 0.004)
    return d


# ---------------------------------------------------------------------------
# Internal passages (vagina, anal canal): collapsed, blind-ended invaginations.
#
# Each is built by extruding a disc of skin faces inward, step by step, so the mesh stays ONE closed
# manifold surface (no holes, no separate object; skin material, UVs and weights carry over). Every new
# vertex is a pure function of where its source vertex started, so coincident vertices cannot drift
# apart. After carving, boundary and non-manifold edge counts must be unchanged or the script stops.
#
# Axis specs are (half-size at the mouth, half-size at the far end, depth where the change starts,
# depth where it ends), in metres at 1.687 m height, scaled by the character's height.
#   u = lateral (x).  v = in the sagittal plane, perpendicular to the passage (front/up side positive).
# A collapsed passage has one axis shrink to slit_half (walls ~2x that apart) and the other widen.
# ---------------------------------------------------------------------------
CANAL = {   # vagina: anterior and posterior walls in contact (slit wide laterally)
    # 200 mm is the depth the passage can accept, not the resting length of a vagina (which is shorter and
    # distends with arousal). With wall_asymmetry the anterior wall is ~190 mm and the posterior ~210 mm.
    "length": 0.200,
    # tilt back from vertical (degrees) at the mouth and at the far end, blended between the two depths
    "axis": (20.0, 10.0, 0.040, 0.150),
    # tried in order; the first that reaches full length with clearance wins, else the one that gets deepest
    "axis_candidates": [(20.0, 10.0), (15.0, 10.0), (25.0, 15.0), (10.0, 10.0), (20.0, 20.0), (30.0, 20.0),
                        (30.0, 30.0), (5.0, 5.0), (0.0, 0.0)],
    "segments": 30,
    "wall_asymmetry": 0.05,
    "u": (0.0032, 0.014, 0.002, 0.030),
    "v": (0.0090, 0.00025, 0.0, 0.004),
    "wall_clearance": 0.006,  # min distance kept to other skin / the other passage once past check_from
    "check_from": 0.012,
    "min_steps": 4,
}

ANUS = {    # anus + anal canal (~40 mm) continuing as the rectum; closed as a front-to-back slit
    "perineal_body": 0.033,   # target posterior fourchette to anal verge centre (33 mm absolute; contour-shortfall fallback)
    "length": 0.200,
    "axis": (5.0, 15.0, 0.035, 0.090),   # near vertical through the canal, then curving back along the sacrum
    "axis_candidates": [(5.0, 15.0), (10.0, 15.0), (0.0, 15.0), (5.0, 10.0), (10.0, 10.0), (5.0, 20.0),
                        (0.0, 10.0), (-5.0, 15.0), (10.0, 20.0), (-10.0, 20.0)],
    "segments": 30,
    "wall_asymmetry": 0.0,
    "u": (0.0035, 0.00025, 0.0, 0.004),
    "v": (0.0035, 0.012, 0.002, 0.060),
    "wall_clearance": 0.004,
    "check_from": 0.010,
    "min_steps": 3,
    # surface: raised verge ring, central pucker, radial folds
    "relief_radius": 0.016, "ring_radius": 0.0085, "ring_sigma": 0.0040, "ring_height": 0.0012,
    "pit_sigma": 0.0040, "pit_depth": 0.0012, "folds": 12, "fold_amp": 0.0005,
    "tint_radius": 0.016,
}


def _bmesh_defects(bm):
    """(boundary edges, non-manifold edges): must be identical before and after a carve."""
    return (sum(1 for e in bm.edges if e.is_boundary),
            sum(1 for e in bm.edges if not e.is_boundary and not e.is_manifold))


def _surface_point(bm, mw, y, z):
    """Nearest point on the current skin surface to (0, y, z), and its outward normal (world)."""
    from mathutils.bvhtree import BVHTree
    bm.verts.index_update()
    world = [mw @ v.co for v in bm.verts]
    tree = BVHTree.FromPolygons(world, [[v.index for v in f.verts] for f in bm.faces], all_triangles=False)
    loc, nrm, _i, _d = tree.find_nearest(Vector((0.0, y, z)))
    return loc, nrm.normalized()


def _tube_frame(n, cfg):
    """(L, T, A): lateral, front/up-in-plane, and inward axis at the mouth for outward surface normal n."""
    bb = math.radians(cfg["axis"][0])
    A = Vector((0.0, math.sin(bb), math.cos(bb)))
    if A.dot(n) > -0.2:                      # the axis must head into the body
        A = (A - n).normalized()
    L = Vector((1.0, 0.0, 0.0))
    L = (L - A * L.dot(A)).normalized()
    return L, L.cross(A).normalized(), A


def _mouth_patch(bm, mw, C, L, T, A, ax, at, reach, normal_limit=-0.1):
    """Largest connected outward-facing skin patch inside an adaptively sized mouth ellipse."""
    rot = mw.to_3x3()
    cand = set()
    for f in bm.faces:
        rel = mw @ f.calc_center_median() - C
        if abs(rel.dot(A)) > reach:
            continue
        if (rel.dot(L) / ax) ** 2 + (rel.dot(T) / at) ** 2 > 1.0:
            continue
        # A relaxed threshold tolerates triangulated/curved skin whose face normals
        # are not perfectly aligned with the local inward passage axis.
        if (rot @ f.normal).dot(A) > normal_limit:
            continue
        cand.add(f)
    best, seen = [], set()
    for f0 in cand:
        if f0 in seen:
            continue
        comp, stack = [], [f0]
        seen.add(f0)
        while stack:
            g = stack.pop()
            comp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h in cand and h not in seen:
                        seen.add(h)
                        stack.append(h)
        if len(comp) > len(best):
            best = comp
    return best


def _single_clean_loop(patch):
    """True if the patch is a disc: exactly one boundary loop, no pinch points."""
    pset = set(patch)
    adj = {}
    for f in patch:
        for e in f.edges:
            if sum(1 for h in e.link_faces if h in pset) == 1:
                a, b = e.verts
                adj.setdefault(a, []).append(b)
                adj.setdefault(b, []).append(a)
    if not adj or any(len(n) != 2 for n in adj.values()):
        return False
    start = next(iter(adj))
    seen, stack = {start}, [start]
    while stack:
        for w in adj[stack.pop()]:
            if w not in seen:
                seen.add(w)
                stack.append(w)
    return len(seen) == len(adj)

def _patch_loop_diagnostic(patch):
    """Compact boundary diagnostics for a rejected mouth patch."""
    pset = set(patch)
    adj = {}
    for face in patch:
        for edge in face.edges:
            if sum(1 for linked in edge.link_faces if linked in pset) == 1:
                a, b = edge.verts
                adj.setdefault(a, []).append(b)
                adj.setdefault(b, []).append(a)
    degrees = [len(neighbours) for neighbours in adj.values()]
    unseen, loops = set(adj), 0
    while unseen:
        loops += 1
        stack = [unseen.pop()]
        while stack:
            for neighbour in adj[stack.pop()]:
                if neighbour in unseen:
                    unseen.remove(neighbour)
                    stack.append(neighbour)
    return (len(patch), len(adj), sum(d == 1 for d in degrees),
            sum(d == 2 for d in degrees), sum(d > 2 for d in degrees), loops)


def _grow_clean_disc(candidates, bm, mw, centre):
    """Grow a single-loop disc through adjacent candidate faces, never across a branch."""
    if not candidates:
        return []
    allowed = set(candidates)
    seed = min(allowed, key=lambda face: (mw @ face.calc_center_median() - centre).length_squared)
    patch = [seed]
    patch_set = {seed}
    frontier = {linked for edge in seed.edges for linked in edge.link_faces
                if linked in allowed and linked not in patch_set}
    while frontier:
        choices = []
        for face in frontier:
            shared = sum(1 for edge in face.edges
                         if any(linked in patch_set for linked in edge.link_faces))
            if shared != 1:
                continue
            trial = patch + [face]
            if _single_clean_loop(trial):
                distance = (mw @ face.calc_center_median() - centre).length_squared
                choices.append((distance, face))
        if not choices:
            break
        _distance, chosen = min(choices, key=lambda item: item[0])
        frontier.remove(chosen)
        patch.append(chosen)
        patch_set.add(chosen)
        for edge in chosen.edges:
            for linked in edge.link_faces:
                if linked in allowed and linked not in patch_set:
                    frontier.add(linked)
    return patch


class _TubePath:
    """Advances a cross-section along a curved centreline (bends about the lateral axis, parallel transport).
    The dry run and the real carve both use this class, so what is checked is exactly what is built."""

    def __init__(self, C, cfg, axis, mu, mv, k):
        self.cfg, self.k, self.mu, self.mv = cfg, k, mu, mv
        self.b0, self.b1, self.d0, self.d1 = axis[0], axis[1], axis[2] * k, axis[3] * k
        self.L = Vector((1.0, 0.0, 0.0))
        self.A, self.T = self.frame(0.0)
        self.C, self.s, self.fl, self.fa = C.copy(), 0.0, 1.0, 1.0

    def frame(self, s):
        bb = math.radians(self.b0 + (self.b1 - self.b0) * _ss(self.d0, self.d1, s))
        A = Vector((0.0, math.sin(bb), math.cos(bb)))
        return A, self.L.cross(A)

    def half(self, spec, mouth, s):
        return mouth + (spec[1] * self.k - mouth) * _ss(spec[2] * self.k, spec[3] * self.k, s)

    def advance(self, s, pts):
        cfg = self.cfg
        fl = self.half(cfg["u"], self.mu, s) / self.mu
        fa = self.half(cfg["v"], self.mv, s) / self.mv
        A_new, T_new = self.frame(s)
        ds = s - self.s
        C_new = self.C + (self.A + A_new).normalized() * ds
        asym = cfg["wall_asymmetry"]
        out = []
        for p in pts:
            r = p - self.C
            ru, rv, ra = r.dot(self.L), r.dot(self.T), r.dot(self.A)
            w = max(-1.0, min(1.0, -rv / (self.mv * self.fa)))     # +1 posterior wall, -1 anterior wall
            out.append(C_new + self.L * (ru * fl / self.fl) + T_new * (rv * fa / self.fa)
                       + A_new * (ra + ds * asym * w))
        self.C, self.A, self.T, self.s, self.fl, self.fa = C_new, A_new, T_new, s, fl, fa
        return out


def _carve_tube(bm, mw, inv, C, n, k, cfg, name, hips_gi=None):
    """Extrude the skin disc at C inward into a collapsed, curved passage. Returns (new vertex indices, depth in metres)."""
    import bmesh
    from mathutils.bvhtree import BVHTree
    bm.normal_update()
    bm.verts.index_update()
    world = [mw @ v.co for v in bm.verts]
    L0, T0, A0 = _tube_frame(n, cfg)

    patch, mouth_C, selected = [], C.copy(), None
    # Imported Ara meshes vary in triangulation, UV seam placement and local curvature.
    # Search progressively wider ellipses, slightly shifted centres, and more tolerant
    # face-normal angles. Keep the first clean disc, preferring the intended anchor.
    offsets = ((0.0, 0.0), (0.25, 0.0), (-0.25, 0.0), (0.0, 0.25), (0.0, -0.25),
               (0.5, 0.0), (-0.5, 0.0), (0.0, 0.5), (0.0, -0.5))
    diagnostics = []
    for grow, reach_scale, normal_limit in (
            (1.0, 1.0, -0.1), (1.25, 1.25, -0.1), (1.6, 1.5, -0.05),
            (2.0, 1.75, 0.0), (2.5, 2.0, 0.1)):
        mu, mv = cfg["u"][0] * k * grow, cfg["v"][0] * k * grow
        best_diag = None
        for ou, ov in offsets:
            candidate_C = C + L0 * (ou * mu) + T0 * (ov * mv)
            raw_cand = _mouth_patch(bm, mw, candidate_C, L0, T0, A0, mu, mv,
                                    0.012 * k * reach_scale, normal_limit)
            if raw_cand:
                diag = _patch_loop_diagnostic(raw_cand)
                clean_cand = _grow_clean_disc(raw_cand, bm, mw, candidate_C)
                clean_diag = _patch_loop_diagnostic(clean_cand)
                if best_diag is None or len(clean_cand) > best_diag[0]:
                    best_diag = (len(clean_cand), clean_diag[1], clean_diag[2],
                                 clean_diag[3], clean_diag[4], clean_diag[5],
                                 "from", diag[0])
            else:
                clean_cand = []
            if len(clean_cand) >= 6 and _single_clean_loop(clean_cand):
                patch, mouth_C = clean_cand, candidate_C
                selected = (grow, reach_scale, normal_limit, ou, ov)
                break
        diagnostics.append((grow, reach_scale, normal_limit, best_diag))
        if patch:
            break
    if not patch:
        print(f"{name} mouth-patch diagnostics (scale, reach, normal, clean faces/boundary/degree1/degree2/degree3+/loops, raw faces): {diagnostics}")
        raise RuntimeError(f"{name}: no clean disc of skin faces after adaptive search "
                           "(see mouth-patch diagnostics above); mesh topology may be unsuitable")
    if selected != (1.0, 1.0, -0.1, 0.0, 0.0):
        print(f"{name} mouth selection adapted: scale={selected[0]:.2f}, "
              f"reach={selected[1]:.2f}, normal_limit={selected[2]:.2f}, "
              f"offset=({selected[3]:.2f},{selected[4]:.2f})")
    C = mouth_C

    n_steps = int(cfg["segments"])
    depths = [cfg["length"] * k * (j / n_steps) ** 1.6 for j in range(1, n_steps + 1)]

    # dry run per candidate centreline: the passage must stay inside the body and keep wall_clearance from every
    # other surface, including a passage carved earlier. First full-length candidate wins, else the deepest.
    pset = set(patch)
    rest_pts = [world[v.index] for v in {v for f in patch for v in f.verts}]
    outer = BVHTree.FromPolygons(world, [[v.index for v in f.verts] for f in bm.faces if f not in pset],
                                 all_triangles=False)

    def run(axis):
        path = _TubePath(C, cfg, axis, mu, mv, k)
        pts, keep = list(rest_pts), 0
        for s in depths:
            pts = path.advance(s, pts)
            if s >= cfg["check_from"] * k:
                for p in pts:
                    loc, nrm, _i, dist = outer.find_nearest(p)
                    if loc is None or (p - loc).dot(nrm) >= 0.0 or dist < cfg["wall_clearance"] * k:
                        return keep
            keep += 1
        return keep

    best_axis, best_keep = None, -1
    for b0, b1 in cfg["axis_candidates"]:
        bb = math.radians(b0)
        if Vector((0.0, math.sin(bb), math.cos(bb))).dot(n) > -0.2:
            continue                                            # does not head into the body
        axis = (b0, b1, cfg["axis"][2], cfg["axis"][3])
        kp = run(axis)
        if kp > best_keep:
            best_axis, best_keep = axis, kp
        if kp == len(depths):
            break
    if best_axis is None or best_keep < cfg["min_steps"]:
        raise RuntimeError(f"{name}: no room inside the body along any candidate path; skip it with the matching "
                           "--no-... flag or edit axis_candidates / length")
    if best_keep < len(depths):
        print(f"{name} limited to {depths[best_keep - 1] * 1000:.0f} mm of {depths[-1] * 1000:.0f} mm: "
              "that is the deepest path with clearance inside this body")
    depths = depths[:best_keep]

    before = _bmesh_defects(bm)
    path = _TubePath(C, cfg, best_axis, mu, mv, k)
    cap, new_all, by_depth = list(patch), [], []
    for s in depths:
        # Include the region's edges explicitly. On imported glTF skin meshes,
        # passing faces alone can leave the source patch's internal edges behind
        # while the duplicate cap is extruded, producing 3+/4-face non-manifold
        # edges. Explicit edge input lets the operator replace the source region.
        cap_edges = {e for f in cap for e in f.edges}
        geom = bmesh.ops.extrude_face_region(
            bm, geom=list(cap) + list(cap_edges), use_keep_orig=False
        )["geom"]
        new_verts = [g for g in geom if isinstance(g, bmesh.types.BMVert)]
        nv = set(new_verts)
        for v, p in zip(new_verts, path.advance(s, [mw @ v.co for v in new_verts])):
            v.co = inv @ p
        cap = [g for g in geom if isinstance(g, bmesh.types.BMFace) and all(v in nv for v in g.verts)]
        # BMesh operators may invalidate BMVert wrappers from earlier steps.
        # Keep plain coordinate snapshots and resolve them against the final mesh.
        step_coords = [tuple(float(c) for c in v.co) for v in new_verts]
        new_all.extend(step_coords)
        by_depth.append((s, step_coords))
    bm.normal_update()
    after = _bmesh_defects(bm)
    if after != before:
        raise RuntimeError(f"{name} changed mesh integrity (boundary, non-manifold) {before} -> {after}")

    # deep vertices must not follow the thighs: fade their skin weights to the pelvis bone with depth
    # Resolve only vertices that survived all subsequent extrusion operations.
    # Never retain BMVert references across BMesh topology edits.
    bm.verts.index_update()
    verts_by_coord = {}
    for v in bm.verts:
        key = tuple(round(float(c), 8) for c in v.co)
        verts_by_coord.setdefault(key, []).append(v)

    deform = bm.verts.layers.deform.active
    if hips_gi is not None and deform is not None:
        for s, coords in by_depth:
            f = _ss(0.03 * k, 0.10 * k, s)
            if f <= 0.0:
                continue
            for co in coords:
                key = tuple(round(float(c), 8) for c in co)
                for v in verts_by_coord.get(key, ()):
                    d = v[deform]
                    for gi in list(d.keys()):
                        d[gi] = d[gi] * (1.0 - f)
                    d[hips_gi] = (d[hips_gi] if hips_gi in d else 0.0) + f

    idx = sorted({v.index for co in new_all
                  for v in verts_by_coord.get(tuple(round(float(c), 8) for c in co), ())})
    print(f"{name}: {len(patch)} faces extruded in {len(depths)} steps to {depths[-1] * 1000:.0f} mm, "
          f"centreline tilt {best_axis[0]:.0f} to {best_axis[1]:.0f} deg; "
          f"boundary/non-manifold edges {before} -> {after}")
    return idx, depths[-1]


def _perineal_anchor(skin, hipline_z, k, line, arc, sA, P):
    """(y, z) of the anal verge centre: walk the x~0 body contour posteriorly from the introitus past the
    fourchette by the perineal body. Uses the pre-sculpt skin."""
    mw = skin.matrix_world
    cy, cz = -0.02 * k, hipline_z + 0.035 * k
    pts = []
    for v in skin.data.vertices:
        p = mw @ v.co
        if abs(p.x) > 0.002 * k or not (hipline_z - 0.16 * k < p.z < hipline_z + 0.10 * k):
            continue
        ang = math.atan2(-(p.z - cz), -(p.y - cy))
        if ang < -0.5 * math.pi:          # back above the centre: not part of the lower contour
            continue
        pts.append((ang, p.y, p.z))
    if len(pts) < 12:
        raise RuntimeError("Anus: could not extract the perineal contour (%d points)" % len(pts))
    pts.sort()
    pts = [(y, z) for _a, y, z in pts]
    for _ in range(4):
        pts = [pts[0]] + [(0.25 * pts[i - 1][0] + 0.5 * pts[i][0] + 0.25 * pts[i + 1][0],
                           0.25 * pts[i - 1][1] + 0.5 * pts[i][1] + 0.25 * pts[i + 1][1])
                          for i in range(1, len(pts) - 1)] + [pts[-1]]
    seg = [0.0]
    for i in range(1, len(pts)):
        seg.append(seg[-1] + math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]))
    step = 0.0015 * k
    out, s, j = [], 0.0, 0
    while s <= seg[-1]:
        while j < len(seg) - 2 and seg[j + 1] < s:
            j += 1
        f = (s - seg[j]) / max(seg[j + 1] - seg[j], 1e-9)
        out.append((pts[j][0] + f * (pts[j + 1][0] - pts[j][0]), pts[j][1] + f * (pts[j + 1][1] - pts[j][1])))
        s += step
    iA = min(range(len(arc)), key=lambda q: abs(arc[q] - sA))
    y0, z0 = line[iA]
    j0 = min(range(len(out)), key=lambda q: (out[q][0] - y0) ** 2 + (out[q][1] - z0) ** 2)
    # Keep the target perineal-body distance absolute. The fourchette location
    # still scales with character proportions. If the posterior contour is too
    # short, clamp to its available endpoint rather than failing the build.
    target_distance = abs(P["t_fourchette"]) * k + ANUS["perineal_body"]
    want = int(round(target_distance / step))
    available = max(0, len(out) - 1 - j0)
    j1 = j0 + min(want, available)
    achieved_distance = (j1 - j0) * step
    achieved_perineal = max(0.0, achieved_distance - abs(P["t_fourchette"]) * k)
    if available < want:
        print(f"Anus spacing fallback: target {ANUS['perineal_body'] * 1000:.1f} mm after "
              f"fourchette; contour supports {achieved_perineal * 1000:.1f} mm; "
              "using the longest available contour")
    print(f"Anus anchor: {achieved_distance * 1000:.1f} mm behind the introitus along the midline "
          f"(fourchette-to-verge approx. {achieved_perineal * 1000:.1f} mm), "
          f"y={out[j1][0]:.4f} z={out[j1][1]:.4f}")
    return out[j1]


def _anus_relief(bm, mw, inv, C, n, k):
    """Raised verge ring, central pucker and radial folds, displaced along vertex normals."""
    cfg = ANUS
    L, T, A = _tube_frame(n, cfg)
    rot = mw.to_3x3()
    R = cfg["relief_radius"]
    moved = 0
    for v in bm.verts:
        p = mw @ v.co
        rel = p - C
        if abs(rel.dot(A)) > 0.012 * k:
            continue
        u, w = rel.dot(L) / k, rel.dot(T) / k
        r = math.hypot(u, w)
        if r > R:
            continue
        nv = (rot @ v.normal).normalized()
        if nv.dot(A) > -0.1:
            continue
        theta = math.atan2(u, w)
        edge = 1.0 - _ss(0.6 * R, R, r)
        ring = cfg["ring_height"] * math.exp(-0.5 * ((r - cfg["ring_radius"]) / cfg["ring_sigma"]) ** 2)
        fold = cfg["fold_amp"] * math.cos(cfg["folds"] * theta) * _ss(0.003, 0.006, r) * (1.0 - _ss(0.010, 0.014, r))
        pit = cfg["pit_depth"] * math.exp(-0.5 * (r / cfg["pit_sigma"]) ** 2)
        d = (ring + fold - pit) * edge * k
        if abs(d) > 1e-8:
            v.co = inv @ (p + nv * d)
            moved += 1
    return moved


def _prep_anus(bm, mw, inv, yz, k):
    """Weld seam twins, refine, and sculpt the anal surface. Returns the surface anchor (point, normal)."""
    import bmesh
    C0 = Vector((0.0, yz[0], yz[1]))
    bm.normal_update()
    zone = [v for v in bm.verts if (mw @ v.co - C0).length <= 0.030 * k]
    n0 = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=zone, dist=1e-5)
    target = 0.0012 * k
    for _ in range(4):
        faces = [f for f in bm.faces
                 if (mw @ f.calc_center_median() - C0).length <= 0.020 * k
                 and f.calc_perimeter() / len(f.verts) > target * 1.6]
        if not faces:
            break
        bmesh.ops.subdivide_edges(bm, edges=list({e for f in faces for e in f.edges}), cuts=1, use_grid_fill=True)
        bm.normal_update()
    C, n = _surface_point(bm, mw, yz[0], yz[1])
    moved = _anus_relief(bm, mw, inv, C, n, k)
    bm.normal_update()
    C, n = _surface_point(bm, mw, yz[0], yz[1])
    print(f"Anus surface: {n0 - len(bm.verts)} seam twins welded, {moved} vertices sculpted")
    return C, n


def integrate_anatomy_into_skin(skin, anatomy_z, width, height, deformation_scale=1.65, hipline_z=None,
                                  canal=True, anus=True):
    """Sculpt the existing skin mesh in place (UVs, material, weights and rig are kept)."""
    import bmesh
    P = dict(FEMALE_ANATOMY)
    shift = P.pop("t_shift", 0.0)
    for key in ("t_hood", "t_glans", "t_meatus", "t_introitus", "t_fourchette", "t_mons"):
        P[key] -= shift
    k = height / 1.687
    amp = deformation_scale / 1.65 * P["prominence"]     # 1.65 is the CLI default; prominence scales every component
    if hipline_z is None:
        hipline_z = anatomy_z + height * 0.035
    line, arc = _surface_midline(skin, hipline_z, k)
    iA = _locate_introitus(line, arc, k)
    sA = arc[iA]
    anus_yz = _perineal_anchor(skin, hipline_z, k, line, arc, sA, P) if anus else None
    print(f"Female anatomy: midline {len(line)} samples, introitus at y={line[iA][0]:.4f} z={line[iA][1]:.4f}")

    prep = _prep_line(line, arc)
    bm = bmesh.new()
    bm.from_mesh(skin.data)
    bm.normal_update()
    mw, inv, rot = skin.matrix_world, skin.matrix_world.inverted(), skin.matrix_world.to_3x3()
    z_lo, z_hi = hipline_z - 0.15 * k, hipline_z + 0.10 * k
    t_lo = P["t_fourchette"] - 0.025
    t_ref_hi = P["t_hood"] + 0.030        # refine only the vulva zone; the broad mons needs no extra vertices
    t_top = P["t_mons"] + 0.055           # the mons fades to exactly zero here

    # glTF import splits vertices at UV seams and material edges. Displacing split twins independently
    # opens cracks, so weld them in the sculpt zone first (the exporter re-splits at UV seams itself).
    n_before = len(bm.verts)
    zone = []
    for v in bm.verts:
        w = mw @ v.co
        if abs(w.x) <= 0.07 * k and z_lo <= w.z <= z_hi and w.y < 0.02:
            zone.append(v)
    bmesh.ops.remove_doubles(bm, verts=zone, dist=1e-5)
    print(f"Sculpt zone weld: {n_before - len(bm.verts)} seam-twin vertices merged")

    def coords_for(worlds):
        s_arr, dist = _project_many(prep, [w.y for w in worlds], [w.z for w in worlds])
        return (sA - s_arr) / k, dist / k

    # adaptive local refinement: split whole faces (not lone edges) so the region
    # stays a regular grid and the folds do not pick up sliver triangles
    target = P["target_edge"] * k
    for _ in range(4):
        cand = []
        for f in bm.faces:
            c = mw @ f.calc_center_median()
            if abs(c.x) <= 0.042 * k and z_lo <= c.z <= z_hi and c.y < 0.02 \
                    and f.calc_perimeter() / len(f.verts) > target * 1.6:
                cand.append((f, c))
        if not cand:
            break
        ts, ds = coords_for([c for _f, c in cand])
        faces = [f for (f, _c), t, dd in zip(cand, ts, ds) if t_lo <= t <= t_ref_hi and dd <= 0.016]
        if not faces:
            break
        edges = list({e for f in faces for e in f.edges})
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=True)
        bm.normal_update()

    sel = []
    for v in bm.verts:
        p = mw @ v.co
        if abs(p.x) <= 0.065 * k and z_lo <= p.z <= z_hi and p.y < 0.02:
            sel.append((v, p))
    moved = 0
    touched = []
    if sel:
        ts, ds = coords_for([p for _v, p in sel])
        for (v, p), t, dist in zip(sel, ts, ds):
            if not (t_lo <= t <= t_top) or dist > 0.035:
                continue
            w_t = _ss(t_lo, t_lo + 0.025, t) * (1.0 - _ss(t_top - 0.045, t_top, t))     # smooth window ends
            fine = _female_displacement(t, p.x / k, P) * (1.0 - _ss(0.006, 0.016, dist))   # stay off the inner thighs
            mons = _female_mons(t, p.x / k, P) * (1.0 - _ss(0.032, 0.060, abs(p.x) / k)) \
                * (1.0 - _ss(0.010, 0.030, dist))
            d = (fine + mons) * w_t * k * amp
            if abs(d) < 1e-7:
                continue
            n = (rot @ v.normal).normalized()
            if d > 0:
                # The folds merge into the perineum rather than hanging below the pelvis:
                # taper raised relief toward the posterior, and ease it on downward-facing skin
                # so nothing protrudes into the gap between the thighs (visible from behind).
                d *= (P["posterior_floor"] + (1.0 - P["posterior_floor"]) * _ss(-0.006, 0.020, t)) \
                    * (1.0 - P["underside_ease"] * _ss(0.55, 0.95, -n.z))
            v.co = inv @ (p + n * d)
            touched.append(v)
            moved += 1
    for _ in range(int(P["smooth_passes"])):
        bmesh.ops.smooth_vert(bm, verts=touched, factor=P["smooth_factor"],
                              use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    hips_gi = next((g.index for g in skin.vertex_groups
                    if g.name.lower().replace(" ", "") in ("hips", "hip", "pelvis")), None)
    canal_idx, canal_depth, anus_idx, anus_depth, anus_C = [], 0.0, [], 0.0, None
    if anus_yz is not None:
        anus_C, anus_n = _prep_anus(bm, mw, inv, anus_yz, k)
    if canal:
        vC, vn = _surface_point(bm, mw, line[iA][0], line[iA][1])
        canal_idx, canal_depth = _carve_tube(bm, mw, inv, vC, vn, k, CANAL, "Vaginal canal", hips_gi)
    if anus_C is not None:
        anus_idx, anus_depth = _carve_tube(bm, mw, inv, anus_C, anus_n, k, ANUS, "Anal canal", hips_gi)
    bm.to_mesh(skin.data)
    bm.free()
    skin.data.update()
    for poly in skin.data.polygons:
        poly.use_smooth = True

    def anchor(t_land):
        s = sA - t_land * k
        i = min(max(int(round(s / (0.0015 * k))), 1), len(line) - 2)
        ty, tz = line[i + 1][0] - line[i - 1][0], line[i + 1][1] - line[i - 1][1]
        ln = math.hypot(ty, tz) or 1.0
        # outward normal of the front/underside surface in the (y, z) plane
        ny, nz = tz / ln, -ty / ln
        if ny > 0:
            ny, nz = -ny, -nz
        return [0.0, line[i][0], line[i][1], 0.0, ny, nz]

    skin["anatomy_profile"] = "adult_female_integrated_skin"
    skin["review_status"] = "integrated_mesh_blockout_for_art_review"
    skin["anatomy_method"] = "surface_following_displacement_v2"
    skin["anatomy_parts"] = ("mons,labia_majora,labia_minora,clitoral_hood,clitoral_glans,"
                             "urethral_meatus,vaginal_introitus,posterior_fourchette"
                             + (",vaginal_canal_collapsed" if canal_idx else "")
                             + (",anus" if anus_C is not None else "")
                             + (",anal_canal_collapsed" if anus_idx else ""))
    if canal_idx or anus_idx:
        skin["anatomy_canal_verts"] = canal_idx + anus_idx
    if canal_idx:
        skin["anatomy_canal_depth_mm"] = round(canal_depth * 1000.0, 1)
    if anus_C is not None:
        skin["anatomy_anus_anchor"] = [anus_C.x, anus_C.y, anus_C.z]
    if anus_idx:
        skin["anatomy_anal_canal_depth_mm"] = round(anus_depth * 1000.0, 1)
    skin["anatomy_hood_anchor"] = anchor(P["t_hood"] - 0.004)
    skin["anatomy_deformation_scale"] = float(deformation_scale)
    _FRAME.clear()
    _FRAME.update(line=line, arc=arc, sA=sA, k=k, P=P, hipline_z=hipline_z)
    print(f"Female anatomy v2: {moved} skin vertices displaced")
    return skin


def _pigment_weights(t, x, P):
    """0..1 strengths for outer folds, inner folds and the dark cleft/vestibule."""
    ax = abs(x)
    th, tm, ti, tf = P["t_hood"], P["t_meatus"], P["t_introitus"], P["t_fourchette"]
    xm = P["majora_x"] * (1.0 - 0.35 * _ss(th - 0.020, th + 0.012, t)) * (1.0 - 0.45 * _ss(tf + 0.012, tf - 0.004, t))
    outer = _env(t, tf, th - 0.006, 0.010) * math.exp(-0.5 * ((ax - xm) / (P["majora_sigma"] * 1.3)) ** 2)
    xn = P["minora_x"] * (0.40 + 0.60 * _ss(th - 0.004, tm, t)) * (1.0 - 0.35 * _ss(tf + 0.012, tf + 0.002, t))
    inner = _env(t, tf + 0.006, P["t_glans"], 0.006) * math.exp(-0.5 * ((ax - xn) / (P["minora_sigma"] * 1.6)) ** 2)
    dark = (_env(t, tf + 0.004, th - 0.006, 0.006) * math.exp(-0.5 * (x / 0.0045) ** 2) * 0.75
            + _g2(x, t - ti, 0.0050, 0.0080) * 0.5)
    return min(1.0, outer * 0.95), min(1.0, inner * 0.85), min(1.0, dark)


def apply_anatomy_pigmentation(skin, anatomy_z, width, height):
    """Skin-tone-relative vertex colour (COLOR_0), driven by the same surface coordinates as the sculpt."""
    import numpy as np
    if not _FRAME:
        raise RuntimeError("Pigmentation needs the sculpt frame: run integrate_anatomy_into_skin first")
    line, arc, sA, k, P = _FRAME["line"], _FRAME["arc"], _FRAME["sA"], _FRAME["k"], _FRAME["P"]
    hipline_z = _FRAME["hipline_z"]
    mesh = skin.data
    existing = mesh.color_attributes.get("Color")
    if existing:
        mesh.color_attributes.remove(existing)
    colour = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    mesh.color_attributes.active_color = colour
    mw = skin.matrix_world
    worlds = [mw @ v.co for v in mesh.vertices]
    z_lo, z_hi = hipline_z - 0.15 * k, hipline_z + 0.10 * k
    cand = [i for i, p in enumerate(worlds) if abs(p.x) <= 0.05 * k and z_lo <= p.z <= z_hi and p.y < 0.02]
    out = np.ones(len(worlds) * 4, dtype=np.float32)
    painted = 0
    if cand:
        s_arr, d_arr = _project_many(_prep_line(line, arc), [worlds[i].y for i in cand], [worlds[i].z for i in cand])
        for i, s_v, dist in zip(cand, s_arr, d_arr):
            if dist / k > 0.020:
                continue
            outer, inner, dark = _pigment_weights((sA - s_v) / k, worlds[i].x / k, P)
            fade = 1.0 - _ss(0.006, 0.016, dist / k)
            outer, inner, dark = outer * fade, inner * fade, dark * fade
            # Multipliers tint the existing skin texture rather than replacing it:
            # muted rose on outer folds, deeper rose on inner folds, warm shadow in the cleft.
            out[i * 4 + 0] = 1.0 + 0.045 * outer - 0.035 * inner - 0.12 * dark
            out[i * 4 + 1] = 1.0 - 0.075 * outer - 0.24 * inner - 0.42 * dark
            out[i * 4 + 2] = 1.0 - 0.060 * outer - 0.20 * inner - 0.34 * dark
            if max(outer, inner, dark) > 0.12:
                painted += 1
    anchor = skin.get("anatomy_anus_anchor")
    if anchor:
        c0, R = Vector((anchor[0], anchor[1], anchor[2])), ANUS["tint_radius"] * k
        for i, p in enumerate(worlds):
            wgt = 1.0 - _ss(0.45 * R, R, (p - c0).length)
            if wgt > 0.0:     # slightly deeper perianal skin tone, fading out
                for ch, amt in ((0, 0.05), (1, 0.18), (2, 0.22)):
                    out[i * 4 + ch] = min(out[i * 4 + ch], 1.0 - amt * wgt)
    for i in (skin.get("anatomy_canal_verts") or []):
        if i < len(worlds):
            out[i * 4:i * 4 + 3] = (0.93, 0.55, 0.56)      # mucosal interior, hidden unless the walls are parted
    colour.data.foreach_set("color", out)
    mesh.update()
    mesh.color_attributes.active_color = colour
    skin["anatomy_pigmented_vertex_count"] = painted
    skin["anatomy_pigmentation"] = "skin-relative_vertex_colour_surface_coordinates"
    print(f"Anatomy pigmentation assigned to {painted} skin vertices")
    return colour


def add_hybrid_labial_forms(skin, surface_tree, armature, anatomy_z, width, height):
    """Add restrained, buried loft forms over the integrated skin sculpt.

    Each loft follows sampled Ara skin ring-by-ring, embeds its rear half beneath
    the surface, tapers into the body, shares the skin material and is pelvis
    weighted. The underlying body remains continuous and morph-compatible.
    """
    skin_material = next((m for m in skin.data.materials if m and "skin" in m.name.lower()), None)
    if skin_material is None:
        raise RuntimeError("Hybrid anatomy requires the original Ara skin material")
    modifier_source = next((m for m in skin.modifiers if m.type == "ARMATURE"), None)
    if modifier_source is None:
        raise RuntimeError("Hybrid anatomy requires the original Ara armature modifier")
    armature = modifier_source.object
    hips = next((b.name for b in armature.data.bones
                 if b.name.lower().replace(" ", "") in ("hips", "hip", "pelvis")), None)
    if hips is None:
        hips = next((b.name for b in armature.data.bones if "hip" in b.name.lower() or "pelvis" in b.name.lower()), None)
    if hips is None:
        raise RuntimeError("Hybrid anatomy could not locate the pelvis weighting bone")

    # Ara's pelvis/upper-thigh topology has small gaps in the front silhouette.
    # A strict single ray at every loft vertex can therefore miss even though
    # the surrounding skin is present. Search a small local X/Z neighbourhood
    # for the nearest front-facing skin hit; never substitute a distant point.
    fallback_samples = 0
    def sample_skin(x, z):
        nonlocal fallback_samples
        hit = front_hit_data(surface_tree, x, z)
        if hit is not None:
            return hit
        candidates = []
        # Fine-to-coarse local search, prioritising the closest anatomical point.
        for step in range(1, 9):
            delta = step * 0.0025
            for dx, dz in ((delta, 0.0), (-delta, 0.0),
                           (0.0, delta), (0.0, -delta),
                           (delta, delta), (delta, -delta),
                           (-delta, delta), (-delta, -delta)):
                candidate = front_hit_data(surface_tree, x + dx, z + dz)
                if candidate is not None:
                    candidates.append((dx*dx + dz*dz, candidate))
            if candidates:
                break
        if not candidates:
            return None
        fallback_samples += 1
        return min(candidates, key=lambda item: item[0])[1]

    vertices, faces, uv_values = [], [], []
    segments, rings = 32, 24
    forms = [
        (width * 0.043, width * 0.028, height * 0.0060, 0.006, 0.054),
        (width * 0.019, width * 0.012, height * 0.0034, 0.002, 0.041),
    ]
    for side in (-1.0, 1.0):
        for form_index, (offset, radius_x, radius_y, top, span) in enumerate(forms):
            start = len(vertices)
            for ri in range(rings + 1):
                t = ri / rings
                z = anatomy_z + height * top - height * span * t
                taper = max(0.0, math.sin(math.pi * t)) ** (0.62 if form_index == 0 else 0.72)
                local_radius_x = radius_x * (0.16 + 0.84 * taper)
                local_radius_y = radius_y * (0.12 + 0.88 * taper)
                centre_x = side * offset
                for si in range(segments):
                    angle = 2.0 * math.pi * si / segments
                    x = centre_x + local_radius_x * math.cos(angle)
                    sample = sample_skin(x, z)
                    if sample is None:
                        raise RuntimeError(f"Hybrid anatomy could not sample Ara skin at x={x:.4f}, z={z:.4f}")
                    surface_y = sample[0].y
                    y = surface_y - local_radius_y * (0.48 + 0.98 * math.sin(angle))
                    vertices.append((x, y, z))
                    uv_values.append((si / segments, t))
            for ri in range(rings):
                for si in range(segments):
                    a = start + ri * segments + si
                    b = start + ri * segments + (si + 1) % segments
                    c = start + (ri + 1) * segments + (si + 1) % segments
                    d = start + (ri + 1) * segments + si
                    faces.append((a, b, c, d))

    mesh = bpy.data.meshes.new("AraHybridPelvicFormsMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(skin_material)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        poly.use_smooth = True
        for loop_index in poly.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            uv_layer.data[loop_index].uv = uv_values[vertex_index]
    obj = bpy.data.objects.new("Adult female anatomy · buried hybrid skin lofts", mesh)
    bpy.context.collection.objects.link(obj)
    group = obj.vertex_groups.new(name=hips)
    group.add(list(range(len(vertices))), 1.0, "REPLACE")
    obj.parent = armature
    obj.matrix_parent_inverse = armature.matrix_world.inverted()
    modifier = obj.modifiers.new("Ara pelvis skinning", "ARMATURE")
    modifier.object = armature
    obj["anatomy_method"] = "buried_surface_sampled_lofts_shared_skin_material"
    obj["anatomy_profile"] = "adult_female_hybrid_review_only"
    obj["review_status"] = "experimental_not_production_approved"
    print(f"Added {len(vertices)} surface-sampled, pelvis-weighted hybrid anatomy vertices; local fallback samples={fallback_samples}")
    return obj



def expand_lower_garments(objects, pelvis_z, body_front_y, width):
    # Apply the local pelvic allowance only to vertices belonging to lower-garment
    # material faces. Modular GLBs can contain skin and garments in one Blender
    # object; moving every vertex in that object would deform the body itself.
    for obj in objects:
        if obj.type != "MESH":
            continue
        briefs_vertices, trouser_vertices = set(), set()
        for poly in obj.data.polygons:
            if poly.material_index >= len(obj.material_slots):
                continue
            material = obj.material_slots[poly.material_index].material
            label = material.name.lower() if material else ""
            is_bikini_lower = "bikini bottom" in label or "bikini string" in label
            if "brief" in label or "underwear" in label or is_bikini_lower:
                briefs_vertices.update(poly.vertices)
            elif any(k in label for k in ("pants", "trouser", "breech")):
                trouser_vertices.update(poly.vertices)
        inv = obj.matrix_world.inverted()
        for indices, amplitude in ((briefs_vertices, 0.034), (trouser_vertices, 0.040)):
            for index in indices:
                vert = obj.data.vertices[index]
                world = obj.matrix_world @ vert.co
                if world.y > body_front_y + 0.055:
                    continue
                if abs(world.x) > width * 0.22 or abs(world.z - pelvis_z) > 0.13:
                    continue
                fx = (world.x / max(width * 0.18, 0.065)) ** 2
                fz = ((world.z - pelvis_z) / 0.115) ** 2
                falloff = max(0.0, 1.0 - fx) * max(0.0, 1.0 - fz)
                falloff = falloff * falloff
                world.y -= amplitude * falloff
                vert.co = inv @ world
        obj.data.update()


# ---------------------------------------------------------------------------
# Garment fitting.
#
# Fits garments to the FINAL skin surface (anatomy included) so they sit over it with a small,
# uniform clearance instead of cutting through it. Works whether the garments share one mesh with
# the body (the modular GLBs) or live in separate objects.
#
#  * The reference surface is built from skin-material faces ONLY. (The old version built it from the
#    whole mesh, so a garment vertex found its own garment as the "nearest surface", read ~0 mm of
#    clearance and was inflated 6 mm along its own face normal, whatever the body looked like.)
#  * Normals are interpolated across the skin face, so the push direction is smooth.
#  * Required pushes are spread over neighbouring garment vertices (Laplacian smoothing) and re-checked,
#    so the cloth drapes over a mound instead of rippling around it.
#  * Vertices that share a position (glTF splits them at UV seams and material edges) always move
#    together, so no cracks open.
#  * Edits go through bmesh, so every shape key (facial morphs etc.) keeps its relative deltas, and the
#    imported custom normals are rotated with the surface they sit on.
#
# Clearances are metres. Edit this block to tune.
# ---------------------------------------------------------------------------
GARMENT_FIT = {
    # (material-name tokens, clearance). The first matching group wins.
    "groups": (
        (("brief", "string bikini", "lace briefs", "fishnet briefs"), 0.0025, True),   # snug underwear (+ crotch extension)
        (("triangle bikini", "bra", "halter"), 0.0030, False),                         # snug upper underwear
        (("pants", "trouser", "breech"), 0.0050, False),
        (("fatigue shirt", "tank top", "shirt", "dress"), 0.0045, False),
    ),
    # The neutral Ara body has no genital volume, so its garments end their crotch about 2-3 cm above the
    # body's real crotch. Underwear is slid down to just under the crotch roof before it is fitted.
    "crotch": {"half_width": 0.045, "reach": 0.075, "min_shift": 0.003},
    # Cloth bridges folds rather than sinking into them, and a coarse garment triangle can span a fine ridge.
    # Underwear therefore gets extra clearance over the vulva zone (front, centre, around the crotch).
    "vulva_margin": {"amount": 0.008, "half_width": 0.04, "z_lo": 0.755, "z_hi": 0.870, "fade": 0.03},
    "max_push_per_round": 0.02, "max_total_push": 0.04,
    # The narrow crotch strip has to bridge the vulva. Pushing each vertex out independently crumples it, so after
    # the push its OFFSETS are smoothed, re-cleared from the skin, and repeated.
    "crotch_smooth": {"rounds": 3, "passes": 8, "factor": 0.5, "half_width": 0.05, "z_above": 0.10},
    "skin_tokens": ("skin",),               # materials that make up the body surface
    "skin_exclude": ("skin details",),      # overlay layers that are not the body surface
    "outer_iterations": 4,                  # push -> smooth -> re-check rounds
    "smooth_passes": 6, "smooth_factor": 0.5,
    "final_clearance_fraction": 0.8,        # after smoothing, nothing may sit closer than this x clearance
}


def _rotate_loop_normals(mesh, old_vertex_normals, new_vertex_normals):
    """Rotate the authored (imported) custom normals of moved vertices by the rotation their surface
    normal went through, so shading follows the new surface and the exported NORMAL stays correct."""
    import numpy as np
    if not mesh.has_custom_normals or not old_vertex_normals:
        return
    mesh.calc_normals_split()
    n_loops = len(mesh.loops)
    ln = np.empty(n_loops * 3, dtype=np.float32); mesh.loops.foreach_get("normal", ln); ln = ln.reshape(-1, 3)
    vidx = np.empty(n_loops, dtype=np.int32); mesh.loops.foreach_get("vertex_index", vidx)
    loops_of = {}
    for li, vi in enumerate(vidx):
        if int(vi) in old_vertex_normals:
            loops_of.setdefault(int(vi), []).append(li)
    for vi, loops in loops_of.items():
        q = old_vertex_normals[vi].rotation_difference(new_vertex_normals[vi])
        ln[loops] = ln[loops] @ np.array(q.to_matrix()).T
    mesh.normals_split_custom_set([tuple(x) for x in ln])
    mesh.update()


def _skin_reference(skin_obj):
    """BVH + smooth normals of the body surface (skin-material faces only), in world space."""
    from mathutils.bvhtree import BVHTree
    cfg = GARMENT_FIT
    mesh = skin_obj.data
    mw = skin_obj.matrix_world
    rot = mw.to_3x3()
    polys = []
    for p in mesh.polygons:
        slot = skin_obj.material_slots[p.material_index] if p.material_index < len(skin_obj.material_slots) else None
        label = slot.material.name.lower() if slot and slot.material else ""
        if any(t in label for t in cfg["skin_tokens"]) and not any(t in label for t in cfg["skin_exclude"]):
            polys.append(p)
    if not polys:
        raise RuntimeError("Garment fitting: no skin faces found to fit against")
    verts = [mw @ v.co for v in mesh.vertices]
    normals = [(rot @ v.normal).normalized() for v in mesh.vertices]
    tree = BVHTree.FromPolygons(verts, [list(p.vertices) for p in polys], all_triangles=False)
    return tree, verts, normals, polys


def _garment_family(label):
    """'string bikini strings' and 'string bikini bottom' are one garment; trim and ties move with their panel."""
    for word in (" ties", " strings", " bottom"):
        label = label.replace(word, "")
    return label.strip()


def fit_garments_to_skin(garment_objects, skin_obj, verbose=True):
    """Fit every recognised garment vertex over the skin surface. Returns the number of vertices moved."""
    import bmesh
    from mathutils.interpolate import poly_3d_calc
    cfg = GARMENT_FIT
    tree, skin_verts, skin_normals, skin_polys = _skin_reference(skin_obj)

    def gap_and_normal(p):
        loc, nrm, idx, _d = tree.find_nearest(p)
        if loc is None:
            return None
        poly = skin_polys[idx]
        pts = [skin_verts[i] for i in poly.vertices]
        try:
            w = poly_3d_calc(pts, loc)
            n = sum((skin_normals[i] * wi for i, wi in zip(poly.vertices, w)), Vector((0.0, 0.0, 0.0)))
            n = n.normalized() if n.length > 1e-6 else nrm.normalized()
        except Exception:
            n = nrm.normalized()
        return (p - loc).dot(n), n

    total_moved = 0
    for obj in garment_objects:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        mw, inv = obj.matrix_world, obj.matrix_world.inverted()
        skin_vertex_ids = set()
        if obj is skin_obj:
            for p in skin_polys:
                skin_vertex_ids.update(p.vertices)
        clearance, extend_label = {}, {}
        for p in mesh.polygons:
            slot = obj.material_slots[p.material_index] if p.material_index < len(obj.material_slots) else None
            label = slot.material.name.lower() if slot and slot.material else ""
            for tokens, clr, extend in cfg["groups"]:
                if any(t in label for t in tokens) and not any(t in label for t in cfg["skin_tokens"]):
                    for vi in p.vertices:
                        if vi not in skin_vertex_ids:
                            clearance[vi] = max(clearance.get(vi, 0.0), clr)
                            if extend:
                                extend_label[vi] = _garment_family(label)
                    break
        if not clearance:
            continue
        # vertices at the same position (UV seams / material edges) form one group and move together
        key_of, groups, g_pos, g_clr = {}, [], [], []
        gid_of = {}
        for vi, clr in clearance.items():
            co = mw @ mesh.vertices[vi].co
            key = (round(co.x * 1e5), round(co.y * 1e5), round(co.z * 1e5))
            if key not in key_of:
                key_of[key] = len(groups); groups.append([]); g_pos.append(co); g_clr.append(clr)
            g = key_of[key]
            groups[g].append(vi); gid_of[vi] = g
            g_clr[g] = max(g_clr[g], clr)
        neighbours = [set() for _ in groups]
        for e in mesh.edges:
            a, b = e.vertices
            if a in gid_of and b in gid_of and gid_of[a] != gid_of[b]:
                neighbours[gid_of[a]].add(gid_of[b]); neighbours[gid_of[b]].add(gid_of[a])
        vm = cfg["vulva_margin"]

        def margin(p, g, n=None):
            if g not in extend_groups:
                return 0.0
            wn = 1.0 if n is None else _ss(-0.15, -0.5, n.y)        # only over forward-facing skin, not the underside
            wx = 1.0 - _ss(vm["half_width"] - 0.01, vm["half_width"] + 0.01, abs(p.x))
            wz = _ss(vm["z_lo"] - 0.02, vm["z_lo"] + 0.01, p.z) * (1.0 - _ss(vm["z_hi"], vm["z_hi"] + vm["fade"], p.z))
            wy = 1.0 - _ss(-0.06, -0.03, p.y)
            return vm["amount"] * wx * wz * wy * wn

        extend_groups = {gid_of[vi] for vi in extend_label}
        disp = [Vector((0.0, 0.0, 0.0)) for _ in groups]
        # crotch extension: slide underwear down to just under the body's crotch roof
        cr = cfg["crotch"]
        roof_z = None
        for y_probe in (-0.065, -0.05, -0.035, -0.02):
            hit = tree.ray_cast(Vector((0.0, y_probe, 0.35)), Vector((0.0, 0.0, 1.0)))
            if hit and hit[0] is not None:
                roof_z = hit[0].z if roof_z is None else min(roof_z, hit[0].z)
        if roof_z is not None and extend_label:
            by_label = {}
            for vi, lab in extend_label.items():
                by_label.setdefault(lab, []).append(gid_of[vi])
            for lab, gids in by_label.items():
                z_seam = min((g_pos[g].z for g in gids if abs(g_pos[g].x) < 0.03), default=None)
                if z_seam is None:
                    continue
                target = roof_z - g_clr[gids[0]]
                shift = z_seam - target
                if shift < cr["min_shift"]:
                    continue
                for g in set(gids):
                    p = g_pos[g]
                    wx = 1.0 - _ss(0.020, cr["half_width"], abs(p.x))
                    wz = 1.0 - _ss(z_seam, z_seam + cr["reach"], p.z)
                    disp[g] += Vector((0.0, 0.0, -shift * wx * wz))
                if verbose:
                    print(f"Garment crotch: '{lab}' seam z={z_seam:.4f} -> {target:.4f} (shift {shift*1000:.1f} mm)")
        shift0 = [d.copy() for d in disp]
        lam, passes = cfg["smooth_factor"], cfg["smooth_passes"]
        for _round in range(cfg["outer_iterations"]):
            pushed = 0
            for g in range(len(groups)):
                pos_g = g_pos[g] + disp[g]
                res = gap_and_normal(pos_g)
                need = g_clr[g] + (margin(pos_g, g, res[1]) if res else 0.0)
                if res and res[0] < need:
                    disp[g] += res[1] * min(need - res[0], cfg["max_push_per_round"])
                    pushed += 1
            for g in range(len(groups)):                  # no runaway: cap the push beyond the crotch shift
                extra = disp[g] - shift0[g]
                if extra.length > cfg["max_total_push"]:
                    disp[g] = shift0[g] + extra * (cfg["max_total_push"] / extra.length)
            if not pushed:
                break
            active = {g for g in range(len(groups)) if disp[g].length > 1e-5}
            for _ in range(passes):                       # spread the push so the cloth drapes
                nxt = {}
                for g in active:
                    nb = [h for h in neighbours[g]]
                    if nb:
                        avg = sum((disp[h] for h in nb), Vector((0.0, 0.0, 0.0))) / len(nb)
                        nxt[g] = disp[g] * (1.0 - lam) + avg * lam
                for g, v in nxt.items():
                    disp[g] = v
                active |= {h for g in list(active) for h in neighbours[g] if disp[h].length > 1e-5 or disp[g].length > 1e-4}
        # crotch strip smoothing (positions), alternating with re-clearing from the skin
        cs = cfg["crotch_smooth"]
        if cs["rounds"] and roof_z is not None and extend_groups:
            zone = [g for g in extend_groups
                    if abs(g_pos[g].x) < cs["half_width"] and (g_pos[g] + disp[g]).z < roof_z + cs["z_above"]]
            zone_set = set(zone)

            def roughness():
                tot = 0.0
                for g in zone:
                    nb = list(neighbours[g])
                    if nb:
                        avg = sum((g_pos[h] + disp[h] for h in nb), Vector((0.0, 0.0, 0.0))) / len(nb)
                        tot += ((g_pos[g] + disp[g]) - avg).length
                return 1000.0 * tot / max(len(zone), 1)

            rough_before = roughness()
            for _r in range(cs["rounds"]):
                for _p in range(cs["passes"]):
                    new_disp = {}
                    for g in zone:                                   # smooth the OFFSETS, not the positions: no shrinking
                        nb = list(neighbours[g])
                        if nb:
                            avg = sum((disp[h] for h in nb), Vector((0.0, 0.0, 0.0))) / len(nb)
                            new_disp[g] = disp[g] * (1.0 - cs["factor"]) + avg * cs["factor"]
                    for g, v in new_disp.items():
                        disp[g] = v
                for g in zone:                                           # re-clear from the skin after each smoothing round
                    pos_g = g_pos[g] + disp[g]
                    res = gap_and_normal(pos_g)
                    need = g_clr[g] + (margin(pos_g, g, res[1]) if res else 0.0)
                    if res and res[0] < need:
                        disp[g] += res[1] * min(need - res[0], cfg["max_push_per_round"])
            if verbose:
                print(f"Garment crotch smoothing: {len(zone)} vertices, roughness {rough_before:.2f} -> {roughness():.2f} mm")
        # final guarantee: no garment vertex ends up closer than a fraction of its clearance
        residual = 0
        for g in range(len(groups)):
            pos_g = g_pos[g] + disp[g]
            res = gap_and_normal(pos_g)
            floor = (g_clr[g] + (margin(pos_g, g, res[1]) if res else 0.0)) * cfg["final_clearance_fraction"]
            if res and res[0] < floor:
                disp[g] += res[1] * min(floor - res[0], cfg["max_push_per_round"]); residual += 1
        if verbose:
            for g in sorted(range(len(groups)), key=lambda q: -disp[q].length)[:4]:
                p0 = g_pos[g]
                print(f"Garment fit: big mover at ({p0.x:.3f},{p0.y:.3f},{p0.z:.3f}) moved {disp[g].length*1000:.0f} mm "
                      f"d=({disp[g].x*1000:.0f},{disp[g].y*1000:.0f},{disp[g].z*1000:.0f}) clr={g_clr[g]*1000:.1f}")
        moved_groups = [g for g in range(len(groups)) if disp[g].length > 1e-6]
        if not moved_groups:
            continue
        bm = bmesh.new(); bm.from_mesh(mesh); bm.normal_update(); bm.verts.ensure_lookup_table()
        old_n, new_n = {}, {}
        for g in moved_groups:
            for vi in groups[g]:
                old_n[vi] = bm.verts[vi].normal.copy()
        for g in moved_groups:
            local = inv.to_3x3() @ disp[g]
            for vi in groups[g]:
                bm.verts[vi].co = bm.verts[vi].co + local
        bm.normal_update()
        for vi in old_n:
            new_n[vi] = bm.verts[vi].normal.copy()
        bm.to_mesh(mesh); bm.free(); mesh.update()
        _rotate_loop_normals(mesh, old_n, new_n)
        n_moved = sum(len(groups[g]) for g in moved_groups)
        total_moved += n_moved
        if verbose:
            biggest = max(disp[g].length for g in moved_groups) * 1000.0
            print(f"Garment fit: {obj.name}: {n_moved} of {len(clearance)} garment vertices moved "
                  f"(max {biggest:.1f} mm, {residual} needed the final clamp)")
    return total_moved


def fit_female_clothing(objects, skin):
    moved = fit_garments_to_skin(objects, skin)
    print(f"Garment fitting complete: {moved} garment vertices adjusted")


def main():
    args = arguments()
    if not args.adult:
        raise SystemExit("Refusing to add external genital anatomy without explicit --adult confirmation")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    if not meshes or armature is None:
        raise RuntimeError("Expected Ara mesh objects and a game armature")

    skin = max((o for o in meshes if "skin" in material_name(o)), key=lambda o: len(o.data.polygons), default=None)
    if skin is None or not skin.data.materials:
        raise RuntimeError("Could not identify Ara's Skin mesh/material")
    skin_material = next((m for m in skin.data.materials if m and "skin" in m.name.lower()), skin.data.materials[0]).copy()
    skin_material.name = "Skin"

    all_bounds = [mesh_world_bounds(o) for o in meshes]
    minimum = Vector(tuple(min(b[0][i] for b in all_bounds) for i in range(3)))
    maximum = Vector(tuple(max(b[1][i] for b in all_bounds) for i in range(3)))
    height = maximum.z - minimum.z
    width = max(mesh_world_bounds(skin)[1].x - mesh_world_bounds(skin)[0].x, 0.4)
    # The Hips bone midpoint sits too high on this rig; the paired femur heads
    # identify the actual hip-joint line. The vulvar centre is inferior to it.
    hipline_z = pelvis_landmark_from_leg_roots(armature, height)
    anatomy_z = hipline_z - height * 0.035

    # Use the actual exposed skin surface when available. In clothed exports,
    # skin is removed under trousers, so use the trouser surface and step inward.
    surface_tree = build_bvh(skin)
    hit = front_hit(surface_tree, 0.0, anatomy_z)
    body_front_y = hit.y if hit is not None else None
    pelvis_surface_tree = surface_tree
    if body_front_y is None:
        # Ara may omit the exact centreline pelvis face in a clothed export.
        # Search a small grid across the lower torso and use an actual mesh
        # surface hit, rather than inventing a depth from the character bounds.
        candidates = []
        x_samples = [0.0, -0.025, 0.025, -0.05, 0.05, -0.075, 0.075,
                     -width * 0.10, width * 0.10, -width * 0.14, width * 0.14]
        z_samples = [anatomy_z + dz for dz in (0.0, -0.015, 0.015, -0.03, 0.03,
                                               -0.045, 0.045, -0.06, 0.06)]
        # Prefer a lower-garment mesh when its material is identifiable, but
        # also inspect all remaining meshes: Ara's material labels vary by export.
        ordered = sorted(meshes, key=lambda o: (
            0 if any(k in material_name(o) for k in ("pants", "trouser", "brief", "underwear")) else 1,
            -len(o.data.polygons)))
        for candidate_obj in ordered:
            tree = build_bvh(candidate_obj)
            for x in x_samples:
                for z in z_samples:
                    result = front_hit_data(tree, x, z)
                    if result:
                        location, normal = result
                        if normal.y < -0.15:
                            candidates.append((abs(z - anatomy_z) + abs(x) * 0.35,
                                               location.y, location, candidate_obj.name))
            if candidates and any(k in material_name(candidate_obj) for k in ("pants", "trouser", "brief", "underwear")):
                break
        if candidates:
            _score, surface_y, location, source_name = min(candidates, key=lambda item: item[0])
            body_front_y = surface_y + 0.010
            source_obj = next(o for o in meshes if o.name == source_name)
            pelvis_surface_tree = build_bvh(source_obj)
            print(f"Pelvis surface fallback: {source_name} at {tuple(round(v, 4) for v in location)}")
    if body_front_y is None:
        details = []
        for obj in meshes:
            lo, hi = mesh_world_bounds(obj)
            details.append(f"{obj.name}: materials={material_name(obj)!r}, z={lo.z:.3f}..{hi.z:.3f}, polys={len(obj.data.polygons)}")
        raise RuntimeError("Could not locate the front pelvis surface after grid scan. Meshes: " + " | ".join(details))

    if not args.fit_existing:
        # Expand lower garments before adding the anatomy so their surfaces clear it.
        expand_lower_garments(meshes, anatomy_z, body_front_y, width)

    if args.fit_existing:
        # The base skin remains present beneath transparent clothing. Fit only
        # trouser material vertices against it; never hide or displace the skin.
        fit_female_clothing(meshes, skin)
        # The modular GLBs already contain the anatomy and piercing sockets
        # from the integrated body base. Only fit briefs, bikini bottoms and
        # trousers over that existing geometry; do not add a second sculpt.
        bpy.ops.object.select_all(action="DESELECT")
        for obj in bpy.context.scene.objects:
            if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
                obj.select_set(True)
        bpy.context.view_layer.objects.active = armature
        os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
        bpy.ops.export_scene.gltf(
            filepath=os.path.abspath(args.output),
            export_format="GLB",
            use_selection=True,
            export_apply=False,
        )
        print("Fitted lower garments around existing adult anatomy")
        return

    anatomy = None
    if args.profile == "female":
        anatomy = integrate_anatomy_into_skin(skin, anatomy_z, width, height, args.deformation_scale,
                                              canal=not args.no_canal, anus=not args.no_anus)
        apply_anatomy_pigmentation(skin, anatomy_z, width, height)
        skin_material = next((m for m in skin.data.materials if m and "skin" in m.name.lower()), None)
        wire_vertex_colour_to_skin_material(skin_material, "Color")
        surface_tree = build_bvh(skin)
        pelvis_surface_tree = surface_tree
        if args.method == "hybrid":
            add_hybrid_labial_forms(skin, surface_tree, armature, anatomy_z, width, height)
            skin["anatomy_method"] = "integrated_skin_sculpt_plus_buried_surface_sampled_hybrid_lofts"
    create_piercing_sockets(armature, skin, surface_tree, minimum, height, width, anatomy_z, body_front_y)
    if anatomy is not None:
        # The hood sits just above the vulvar cleft, not on the mons pubis.
        anchor = skin.get("anatomy_hood_anchor")
        if anchor:
            hood_normal = Vector((anchor[3], anchor[4], anchor[5])).normalized()
            location = Vector((anchor[0], anchor[1], anchor[2])) + hood_normal * 0.0015
            hip_name = next((b.name for b in armature.data.bones if b.name.lower() in ("hips", "hip", "pelvis")), "Hips")
            create_socket(armature, "SOCKET_ClitoralHood", location, hood_normal, hip_name)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(args.output),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_animations=True,
    )
    print("Exported adult anatomy variant. Inspect front, side and three-quarter views before production use.")


if __name__ == "__main__":
    main()