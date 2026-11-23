"""Surface-following female anatomy sculpt for the Ara adult base body.

This is deliberately anatomy-only: no garment expansion or clothing fitting.
The original skin mesh, UVs, material, vertex groups and armature are retained;
surface-derived accessory sockets are recreated for downstream character details.
Review the generated adult model from multiple angles before production use.
"""
import argparse
import json
import os
import sys
import math

import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", default="")
    parser.add_argument("--subdivision-plan", required=True)
    parser.add_argument("--adult", action="store_true")
    parser.add_argument("--deformation-scale", type=float, default=1.65)
    return parser.parse_args(raw)


def material_name(obj):
    return " ".join(slot.material.name.lower() for slot in obj.material_slots if slot.material)


def mesh_world_bounds(obj):
    pts = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector(tuple(min(p[i] for p in pts) for i in range(3))),
        Vector(tuple(max(p[i] for p in pts) for i in range(3))),
    )

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
    "minora_height": 0.0098, "minora_x": 0.0078, "minora_sigma": 0.0027,
    "minora_wave": 0.07, "minora_wave_len": 0.026,   # free-edge undulation
    "vestibule_depth": 0.0025,
    # clitoral complex and openings
    "hood_height": 0.0050, "glans_height": 0.0028,
    "meatus_depth": 0.0012, "introitus_depth": 0.0045,
    "fourchette_height": 0.0030, "mons_height": 0.0060,
    # overall prominence: scales EVERY raised or recessed component (mons, labia, hood, cleft, introitus ...)
    "prominence": 0.70,
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


def integrate_anatomy_into_skin(skin, anatomy_z, width, height, deformation_scale=1.65, hipline_z=None, subdivision_plan_path=None):
    """Sculpt the existing skin mesh in place (UVs, material, weights and rig are kept)."""
    import bmesh
    P = dict(FEMALE_ANATOMY)
    k = height / 1.687
    amp = deformation_scale / 1.65 * P["prominence"]     # 1.65 is the CLI default; prominence scales every component
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
    t_lo = P["t_fourchette"] - 0.025
    t_ref_hi = P["t_hood"] + 0.030        # refine only the vulva zone; the broad mons needs no extra vertices
    t_top = P["t_mons"] + 0.055           # the mons fades to exactly zero here

    def coords_for(worlds):
        s_arr, dist = _project_many(prep, [w.y for w in worlds], [w.z for w in worlds])
        return (sA - s_arr) / k, dist / k

    # Apply the deterministic shared subdivision plan generated once from the
    # neutral Ara export. The plan records exact edge-index operations and a
    # final topology signature; all body states must match it exactly.
    if not subdivision_plan_path:
        raise RuntimeError("A shared neutral subdivision plan is required")
    with open(os.path.abspath(subdivision_plan_path), "r", encoding="utf-8") as handle:
        subdivision_plan = json.load(handle)
    original_signature = {
        "vertices": len(skin.data.vertices),
        "faces": [list(poly.vertices) for poly in skin.data.polygons],
    }
    if original_signature != subdivision_plan["source_topology"]:
        raise RuntimeError(
            "Ara source topology differs from the neutral subdivision reference; "
            "refusing to apply an unsafe shared subdivision plan"
        )
    bm.verts.ensure_lookup_table()
    bm.verts.index_update()
    for pass_index, edge_pairs in enumerate(subdivision_plan["passes"]):
        edge_lookup = {
            tuple(sorted((edge.verts[0].index, edge.verts[1].index))): edge
            for edge in bm.edges
        }
        missing = [tuple(pair) for pair in edge_pairs if tuple(pair) not in edge_lookup]
        if missing:
            raise RuntimeError(
                f"Shared subdivision pass {pass_index + 1}: "
                f"{len(missing)} planned edges are missing"
            )
        edges = [edge_lookup[tuple(pair)] for pair in edge_pairs]
        if edges:
            bmesh.ops.subdivide_edges(
                bm, edges=edges, cuts=1, use_grid_fill=True
            )
            bm.verts.ensure_lookup_table()
            bm.verts.index_update()
            bm.edges.ensure_lookup_table()
            bm.faces.ensure_lookup_table()
            bm.normal_update()
    actual_topology = {
        "vertices": len(bm.verts),
        "faces": [list(face.verts[i].index for i in range(len(face.verts))) for face in bm.faces],
    }
    if actual_topology != subdivision_plan["subdivided_topology"]:
        raise RuntimeError(
            "Shared subdivision did not reproduce the neutral topology exactly; "
            "refusing to sculpt a morph-incompatible mesh"
        )
    print(
        "Applied shared subdivision plan: "
        f"{len(subdivision_plan['passes'])} passes, "
        f"{len(bm.verts)} vertices, {len(bm.faces)} faces"
    )

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
    # The glTF exporter is explicitly set to ACTIVE; Blender 5 FloatColorAttribute
    # does not expose an .index property, so keep the collection's active layer.
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

def build_vulva_mons_region_weights(skin, hipline_z, height):
    """Build one combined external vulva + mons pubis surface mask.

    Uses the same midline arc-length coordinate system as the Ara anatomy
    sculpt. The result is one [0, 1] weight per skin vertex, with soft edges.
    """
    P = FEMALE_ANATOMY
    k = height / 1.687
    line, arc = _surface_midline(skin, hipline_z, k)
    introitus_index = _locate_introitus(line, arc, k)
    sA = arc[introitus_index]
    prep = _prep_line(line, arc)
    mw = skin.matrix_world
    hip_lo, hip_hi = hipline_z - 0.15 * k, hipline_z + 0.10 * k
    t_lo = P["t_fourchette"] - 0.025
    t_vulva_hi = P["t_hood"] + 0.020
    t_top = P["t_mons"] + 0.055
    worlds = [mw @ vertex.co for vertex in skin.data.vertices]
    s_values, distances = _project_many(
        prep, [point.y for point in worlds], [point.z for point in worlds]
    )
    weights = [0.0] * len(worlds)
    for index, (vertex, point, surface_s, distance) in enumerate(
        zip(skin.data.vertices, worlds, s_values, distances)
    ):
        if abs(point.x) > 0.070 * k or not (hip_lo <= point.z <= hip_hi) or point.y > 0.02:
            continue
        normal = (mw.to_3x3() @ vertex.normal).normalized()
        if normal.y > 0.35:
            continue
        t = (sA - surface_s) / k
        x = point.x / k
        surface_distance = distance / k
        if t < t_lo or t > t_top or surface_distance > 0.035:
            continue
        vulva_envelope = _env(t, t_lo, t_vulva_hi, 0.012)
        vulva_lateral = math.exp(-0.5 * (x / 0.038) ** 2)
        mons = _g2(x, t - P["t_mons"], 0.052, 0.050)
        lateral_fade = 1.0 - _ss(0.055, 0.070, abs(x))
        surface_fade = 1.0 - _ss(0.015, 0.035, surface_distance)
        weights[index] = max(vulva_envelope * vulva_lateral, mons) * lateral_fade * surface_fade
    return weights


def add_correspondence_uv_layer(mesh, name="CorrespondenceID", region_weights=None):
    """Encode stable vertex identity in TEXCOORD_1.x and one region mask in .y.

    The morph builder intentionally reads only .x for CorrespondenceID. The
    second component is therefore available for a semantic mask without
    changing the existing vertex-correspondence contract.
    """
    if region_weights is not None and len(region_weights) != len(mesh.vertices):
        raise RuntimeError(
            f"Region mask has {len(region_weights)} weights for {len(mesh.vertices)} vertices"
        )
    layer = mesh.uv_layers.get(name)
    if layer is not None:
        mesh.uv_layers.remove(layer)
    layer = mesh.uv_layers.new(name=name)
    count = max(len(mesh.vertices), 1)
    for loop in mesh.loops:
        vertex_id = int(loop.vertex_index)
        weight = float(region_weights[vertex_id]) if region_weights is not None else 0.0
        layer.data[loop.index].uv = ((vertex_id + 0.5) / count, weight)
    mesh.update()
    mesh["correspondence_uv_layer"] = name
    mesh["region_mask_uv_component"] = "TEXCOORD_1.y"
    print(
        f"Added {name} TEXCOORD identity and vulva_mons_pubis mask "
        f"for {len(mesh.vertices)} source vertices"
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


def main():
    args = arguments()
    if not args.adult:
        raise SystemExit("Refusing to add external anatomy without explicit --adult confirmation")
    if args.deformation_scale <= 0:
        raise ValueError("--deformation-scale must be positive")

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if not meshes or armature is None:
        raise RuntimeError("Expected Ara mesh objects and an armature")

    skin = max(
        (obj for obj in meshes if "skin" in material_name(obj)),
        key=lambda obj: len(obj.data.polygons),
        default=None,
    )
    if skin is None or not skin.data.materials:
        raise RuntimeError("Could not identify Ara's skin mesh/material")

    # Isolate the vertex-colour shader change to this skin mesh. Do not mutate
    # a shared material that may also be used by other character components.
    skin_index = next(
        (i for i, material in enumerate(skin.data.materials)
         if material and "skin" in material.name.lower()),
        0,
    )
    skin_material = skin.data.materials[skin_index].copy()
    skin_material.name = "Skin_Anatomy"
    skin.data.materials[skin_index] = skin_material

    all_bounds = [mesh_world_bounds(obj) for obj in meshes]
    minimum = Vector(tuple(min(bounds[0][i] for bounds in all_bounds) for i in range(3)))
    maximum = Vector(tuple(max(bounds[1][i] for bounds in all_bounds) for i in range(3)))
    height = maximum.z - minimum.z
    if height <= 0:
        raise RuntimeError(f"Invalid character height: {height}")
    skin_min, skin_max = mesh_world_bounds(skin)
    width = max(skin_max.x - skin_min.x, 0.4)

    hipline_z = pelvis_landmark_from_leg_roots(armature, height)
    anatomy_z = hipline_z - height * 0.035

    integrate_anatomy_into_skin(
        skin, anatomy_z, width, height, args.deformation_scale,
        hipline_z=hipline_z, subdivision_plan_path=args.subdivision_plan
    )
    apply_anatomy_pigmentation(skin, anatomy_z, width, height)
    wire_vertex_colour_to_skin_material(skin_material, "Color")

    # Recreate surface-derived accessory sockets used by downstream character
    # details. These are rig anchors, not garment or clothing operations.
    surface_tree = build_bvh(skin)
    create_piercing_sockets(armature, skin, surface_tree, minimum, height,
                            width, anatomy_z, None)
    hood_anchor = skin.get("anatomy_hood_anchor")
    if hood_anchor:
        hood_normal = Vector((hood_anchor[3], hood_anchor[4], hood_anchor[5])).normalized()
        hood_location = Vector((hood_anchor[0], hood_anchor[1], hood_anchor[2])) + hood_normal * 0.0015
        hip_name = next((b.name for b in armature.data.bones
                         if b.name.lower() in ("hips", "hip", "pelvis")), "Hips")
        create_socket(armature, "SOCKET_ClitoralHood", hood_location, hood_normal, hip_name)

    # Preserve shared-subdivision vertex identity and carry the combined
    # vulva + mons pubis semantic mask in TEXCOORD_1.y. TEXCOORD_1.x remains
    # the exact correspondence ID consumed by the morph builder.
    vulva_mons_weights = build_vulva_mons_region_weights(skin, hipline_z, height)
    add_correspondence_uv_layer(skin.data, region_weights=vulva_mons_weights)
    skin["anatomy_region_mask"] = "vulva_external_including_mons_pubis"
    skin["anatomy_region_mask_channel"] = "TEXCOORD_1.y"

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature

    output_path = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_morph=True,
        export_animations=True,
        export_apply=False,
        export_vertex_color="ACTIVE",
    )

    colour = skin.data.color_attributes.get("Color")
    original_colour_vertices = len(colour.data) if colour else 0
    original_pigmented_vertices = skin.get("anatomy_pigmented_vertex_count", 0)
    original_skin_name = skin.name
    original_skin_vertices = len(skin.data.vertices)
    original_skin_faces = len(skin.data.polygons)
    original_anatomy_profile = skin.get("anatomy_profile", "")
    original_anatomy_method = skin.get("anatomy_method", "")

    # Verify the actual GLB payload by importing it again. This catches a
    # Blender-only colour layer that silently disappears during export.
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=output_path)
    exported_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    exported_skin = max(
        (obj for obj in exported_meshes if "skin" in material_name(obj)),
        key=lambda obj: len(obj.data.polygons), default=None,
    )
    if exported_skin is None:
        raise RuntimeError("Exported GLB re-import contains no identifiable skin mesh")
    exported_colour = next(
        (attribute for attribute in exported_skin.data.color_attributes
         if len(attribute.data) in (len(exported_skin.data.vertices), len(exported_skin.data.loops))),
        None,
    )
    if exported_colour is None:
        raise RuntimeError("Anatomy pigmentation did not survive GLB export/re-import")
    if len(exported_skin.data.uv_layers) < 2:
        raise RuntimeError("Vulva/mons semantic mask TEXCOORD_1 did not survive GLB export/re-import")
    exported_mask_layer = exported_skin.data.uv_layers[1]
    exported_mask_by_vertex = [None] * len(exported_skin.data.vertices)
    for loop in exported_skin.data.loops:
        uv = exported_mask_layer.data[loop.index].uv
        value = (round(float(uv.x), 7), round(float(uv.y), 6))
        previous = exported_mask_by_vertex[loop.vertex_index]
        if previous is not None and previous != value:
            raise RuntimeError(
                f"Exported TEXCOORD_1 identity/mask differs across loops for vertex {loop.vertex_index}"
            )
        exported_mask_by_vertex[loop.vertex_index] = value
    if any(value is None for value in exported_mask_by_vertex):
        raise RuntimeError("Exported TEXCOORD_1 does not identify every skin vertex")
    exported_mask_weighted = sum(value[1] >= 0.15 for value in exported_mask_by_vertex)
    if exported_mask_weighted == 0:
        raise RuntimeError("Vulva/mons semantic mask is empty after GLB export/re-import")
    exported_nonwhite = 0
    for item in exported_colour.data:
        rgba = item.color
        if any(abs(float(rgba[channel]) - 1.0) > 1e-4 for channel in range(3)):
            exported_nonwhite += 1
    if exported_nonwhite == 0:
        raise RuntimeError("Exported GLB contains a colour layer, but all values are white")

    report = {
        "input": os.path.abspath(args.input),
        "output": output_path,
        "height_metres": height,
        "hipline_z": hipline_z,
        "anatomy_z": anatomy_z,
        "deformation_scale": args.deformation_scale,
        "skin_mesh": original_skin_name,
        "skin_vertices": original_skin_vertices,
        "skin_faces": original_skin_faces,
        "colour_attribute_vertices": original_colour_vertices,
        "exported_colour_attribute": exported_colour.name,
        "exported_colour_vertices": len(exported_colour.data),
        "exported_nonwhite_colour_vertices": exported_nonwhite,
        "anatomy_pigmented_vertex_count": original_pigmented_vertices,
        "semantic_region_masks": {
            "vulva_external": {
                "includes": ["external_vulva", "mons_pubis"],
                "channel": "TEXCOORD_1.y",
                "weighted_vertices_at_0_15": exported_mask_weighted,
                "vertex_count": len(exported_mask_by_vertex)
            }
        },
        "vertex_colour_export_mode": "ACTIVE",
        "anatomy_profile": original_anatomy_profile,
        "anatomy_method": original_anatomy_method,
        "anatomy_pigmented_vertex_count": original_pigmented_vertices,
        "clothing_operations": "not run",
    }
    if args.report:
        report_path = os.path.abspath(args.report)
        os.makedirs(os.path.dirname(report_path), exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2)
            handle.write("\n")
    print(json.dumps(report, indent=2))
    print("Exported anatomy-only adult female Ara variant. Multi-angle art review required.")


if __name__ == "__main__":
    main()