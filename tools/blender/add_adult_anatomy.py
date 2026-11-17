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
    "t_introitus": 0.0, "t_fourchette": -0.022, "t_mons": 0.098,
    # labia majora (outer folds) and the cleft between them
    "majora_height": 0.0125, "majora_x": 0.0190, "majora_sigma": 0.0118,
    "cleft_depth": 0.0058, "cleft_sigma": 0.0060,
    # labia minora (inner folds). minora_x is the centre of each fold.
    "minora_height": 0.0098, "minora_x": 0.0078, "minora_sigma": 0.0027,
    "minora_wave": 0.07, "minora_wave_len": 0.026,   # free-edge undulation
    "vestibule_depth": 0.0025,
    # clitoral complex and openings
    "hood_height": 0.0050, "glans_height": 0.0028,
    "meatus_depth": 0.0012, "introitus_depth": 0.0045,
    "fourchette_height": 0.0030, "mons_height": 0.0080,
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


def _female_displacement(t, x, P):
    """Outward displacement (m, in k-normalised units) at surface coords (t, x)."""
    ax = abs(x)
    th, tg, tm, ti, tf, tmons = (P["t_hood"], P["t_glans"], P["t_meatus"],
                                 P["t_introitus"], P["t_fourchette"], P["t_mons"])
    d = 0.0
    # mons pubis
    d += P["mons_height"] * _g2(x, t - tmons, 0.045, 0.036)
    # labia majora: two rounded ridges that converge toward the mons and the fourchette
    xm = P["majora_x"] * (1.0 - 0.35 * _ss(th - 0.020, th + 0.012, t)) \
        * (1.0 - 0.45 * _ss(tf + 0.012, tf - 0.004, t))
    env_maj = _env(t, tf - 0.002, th + 0.004, 0.010)
    d += P["majora_height"] * env_maj * math.exp(-0.5 * ((ax - xm) / P["majora_sigma"]) ** 2)
    # cleft between the majora
    d -= P["cleft_depth"] * _env(t, tf + 0.004, th - 0.006, 0.006) * math.exp(-0.5 * (x / P["cleft_sigma"]) ** 2)
    # labia minora: thin folds, converging at the hood, with a wavy free edge
    xn = P["minora_x"] * (0.40 + 0.60 * _ss(th - 0.004, tm, t)) * (1.0 - 0.35 * _ss(tf + 0.012, tf + 0.002, t))
    wave = 1.0 + P["minora_wave"] * math.sin(2.0 * math.pi * t / P["minora_wave_len"])
    env_min = _env(t, tf + 0.008, th - 0.004, 0.006)
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


def integrate_anatomy_into_skin(skin, anatomy_z, width, height, deformation_scale=1.65, hipline_z=None):
    """Sculpt the existing skin mesh in place (UVs, material, weights and rig are kept)."""
    import bmesh
    P = dict(FEMALE_ANATOMY)
    k = height / 1.687
    amp = deformation_scale / 1.65     # 1.65 is the CLI default and maps to the tuned baseline
    if hipline_z is None:
        hipline_z = anatomy_z + height * 0.035
    line, arc = _surface_midline(skin, hipline_z, k)
    iA = _locate_introitus(line, arc, k)
    sA = arc[iA]
    print(f"Female anatomy: midline {len(line)} samples, introitus at y={line[iA][0]:.4f} z={line[iA][1]:.4f}")

    prep = _prep_line(line, arc)
    bm = bmesh.new()
    bm.from_mesh(skin.data)
    bm.normal_update()
    mw, inv, rot = skin.matrix_world, skin.matrix_world.inverted(), skin.matrix_world.to_3x3()
    z_lo, z_hi = hipline_z - 0.15 * k, hipline_z + 0.10 * k
    t_lo, t_hi = P["t_fourchette"] - 0.025, P["t_mons"] + 0.045

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
            if abs(c.x) <= 0.05 * k and z_lo <= c.z <= z_hi and c.y < 0.02 \
                    and f.calc_perimeter() / len(f.verts) > target * 1.6:
                cand.append((f, c))
        if not cand:
            break
        ts, ds = coords_for([c for _f, c in cand])
        faces = [f for (f, _c), t, dd in zip(cand, ts, ds) if t_lo <= t <= t_hi and dd <= 0.016]
        if not faces:
            break
        edges = list({e for f in faces for e in f.edges})
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=True)
        bm.normal_update()

    sel = []
    for v in bm.verts:
        p = mw @ v.co
        if abs(p.x) <= 0.06 * k and z_lo <= p.z <= z_hi and p.y < 0.02:
            sel.append((v, p))
    moved = 0
    touched = []
    if sel:
        ts, ds = coords_for([p for _v, p in sel])
        for (v, p), t, dist in zip(sel, ts, ds):
            if not (t_lo <= t <= t_hi) or dist > 0.020:
                continue
            mask = 1.0 - _ss(0.006, 0.016, dist)      # stay on the skin surface, off inner thighs
            d = _female_displacement(t, p.x / k, P) * k * mask * amp
            if abs(d) < 1e-6:
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
                             "urethral_meatus,vaginal_introitus,posterior_fourchette")
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
    outer = _env(t, tf, th + 0.004, 0.010) * math.exp(-0.5 * ((ax - xm) / (P["majora_sigma"] * 1.3)) ** 2)
    xn = P["minora_x"] * (0.40 + 0.60 * _ss(th - 0.004, tm, t)) * (1.0 - 0.35 * _ss(tf + 0.012, tf + 0.002, t))
    inner = _env(t, tf + 0.006, th - 0.002, 0.006) * math.exp(-0.5 * ((ax - xn) / (P["minora_sigma"] * 1.6)) ** 2)
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


def fit_garment_clearance(objects, skin, material_tokens, clearance=0.004):
    """Push selected garment vertices just outside the full retained skin surface.

    The body remains untouched. Fitting is performed against the integrated
    female Ara skin, so briefs/bikini bottoms clear the vulvar contour and
    bras/tops clear the lower breast fold instead of relying on the original
    generic body shell offset.
    """
    tree = build_bvh(skin)
    tokens = tuple(token.lower() for token in material_tokens)
    moved_total = 0
    for obj in objects:
        if obj.type != "MESH":
            continue
        garment_vertices = set()
        for poly in obj.data.polygons:
            if poly.material_index >= len(obj.material_slots):
                continue
            material = obj.material_slots[poly.material_index].material
            label = material.name.lower() if material else ""
            if any(token in label for token in tokens):
                garment_vertices.update(poly.vertices)
        if not garment_vertices:
            continue
        inv = obj.matrix_world.inverted()
        moved = 0
        for index in garment_vertices:
            vert = obj.data.vertices[index]
            world = obj.matrix_world @ vert.co
            nearest = tree.find_nearest(world)
            if not nearest or nearest[0] is None or nearest[1] is None:
                continue
            location, normal, _face, _distance = nearest
            normal = normal.normalized()
            signed = (world - location).dot(normal)
            if signed < clearance:
                world += normal * (clearance - signed)
                vert.co = inv @ world
                moved += 1
        if moved:
            obj.data.update()
            print(f"Garment clearance: {obj.name} moved {moved} vertices ({clearance:.4f} m)")
            moved_total += moved
    return moved_total


def fit_female_clothing(objects, skin):
    # Lower garments need a little more stand-off around the integrated vulvar
    # contour; upper layers need a smaller clearance to avoid the inframammary
    # fold without making the clothing visibly float away from the chest.
    lower = fit_garment_clearance(
        objects, skin,
        ("brief", "bikini bottom", "bikini strings", "pants", "trouser", "breech"),
        clearance=0.006,
    )
    upper = fit_garment_clearance(
        objects, skin,
        ("bra", "halter", "fatigue shirt", "tank top", "shirt", "dress"),
        clearance=0.0045,
    )
    print(f"Female garment fitting complete: {lower} lower-body and {upper} upper-body vertices adjusted")


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
        anatomy = integrate_anatomy_into_skin(skin, anatomy_z, width, height, args.deformation_scale)
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