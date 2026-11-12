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


def apply_anatomy_pigmentation(skin, anatomy_z, width, height):
    """Add skin-tone-relative pigmentation as glTF vertex colour (COLOR_0)."""
    mesh = skin.data
    existing = mesh.color_attributes.get("Color")
    if existing:
        mesh.color_attributes.remove(existing)
    colour = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    mesh.color_attributes.active_color = colour

    def g(x, z, cx, cz, sx, sz):
        return math.exp(-0.5 * (((x-cx)/sx)**2 + ((z-cz)/sz)**2))

    painted_vertices = 0
    for vertex in mesh.vertices:
        p = skin.matrix_world @ vertex.co
        normal = (skin.matrix_world.to_3x3() @ vertex.normal).normalized()
        if (normal.y > -0.08 or abs(p.x) > width * 0.18
                or abs(p.z-anatomy_z) > height * 0.070):
            colour.data[vertex.index].color = (1.0, 1.0, 1.0, 1.0)
            continue
        outer = max(
            g(p.x,p.z,-width*0.060,anatomy_z-height*0.002,width*0.030,height*0.030),
            g(p.x,p.z, width*0.060,anatomy_z-height*0.002,width*0.030,height*0.030),
        )
        inner = max(
            g(p.x,p.z,-width*0.025,anatomy_z-height*0.004,width*0.014,height*0.026),
            g(p.x,p.z, width*0.025,anatomy_z-height*0.004,width*0.014,height*0.026),
        )
        cleft = g(p.x,p.z,0.0,anatomy_z-height*0.018,width*0.0045,height*0.030)
        vestibule = g(p.x,p.z,0.0,anatomy_z-height*0.026,width*0.015,height*0.010)
        outer_strength = min(1.0, outer * 0.95)
        inner_strength = min(1.0, inner * 0.82)
        dark_strength = min(1.0, cleft * 0.92 + vestibule * 0.45)
        # Multipliers tint the existing skin texture rather than replacing it:
        # muted rose on outer folds, deeper rose on inner folds, and a narrow
        # warm shadow in the cleft/vestibule. Smooth Gaussian falloffs avoid decals.
        red = 1.0 + 0.045*outer_strength - 0.035*inner_strength - 0.12*dark_strength
        green = 1.0 - 0.075*outer_strength - 0.24*inner_strength - 0.42*dark_strength
        blue = 1.0 - 0.060*outer_strength - 0.20*inner_strength - 0.34*dark_strength
        colour.data[vertex.index].color = (red, green, blue, 1.0)
        if max(outer_strength, inner_strength, dark_strength) > 0.12:
            painted_vertices += 1
    mesh.color_attributes.active_color = colour
    skin["anatomy_pigmented_vertex_count"] = painted_vertices
    print(f"Anatomy pigmentation assigned to {painted_vertices} skin vertices")
    skin["anatomy_pigmentation"] = "skin-relative_vertex_colour_inner_and_central_regions"
    return colour


def integrate_anatomy_into_skin(skin, anatomy_z, width, height, deformation_scale=1.0):
    """Sculpt Ara skin while preserving its UVs, weights and any facial shape keys."""
    import bmesh
    inv = skin.matrix_world.inverted()
    normal_matrix = skin.matrix_world.to_3x3()
    shape_keys = skin.data.shape_keys
    key_blocks = list(shape_keys.key_blocks) if shape_keys else []
    preserve_morphs = len(key_blocks) > 1

    def g(x,z,cx,cz,sx,sz):
        return math.exp(-0.5*(((x-cx)/sx)**2+((z-cz)/sz)**2))

    def deform_world_point(p, normal):
        n = normal.normalized() if normal.length else normal
        if n.y > -0.10 or abs(p.x) > width*0.27 or abs(p.z-anatomy_z) > 0.15:
            return p
        # Stronger sculpt pass: distinct mons transition, paired outer/inner
        # folds, a readable median cleft, vestibular hollow and posterior fold.
        mons = g(p.x,p.z,0.0,anatomy_z+height*0.035,width*0.105,height*0.020)
        outer_l = g(p.x,p.z,-width*0.060,anatomy_z-height*0.002,width*0.027,height*0.030)
        outer_r = g(p.x,p.z, width*0.060,anatomy_z-height*0.002,width*0.027,height*0.030)
        inner_l = g(p.x,p.z,-width*0.026,anatomy_z-height*0.012,width*0.0085,height*0.019)
        inner_r = g(p.x,p.z, width*0.026,anatomy_z-height*0.012,width*0.0085,height*0.019)
        cleft = g(p.x,p.z,0.0,anatomy_z-height*0.024,width*0.0032,height*0.014)
        vestibule = g(p.x,p.z,0.0,anatomy_z-height*0.024,width*0.017,height*0.009)
        urethra = g(p.x,p.z,0.0,anatomy_z-height*0.016,width*0.0038,height*0.0025)
        vaginal = g(p.x,p.z,0.0,anatomy_z-height*0.035,width*0.011,height*0.006)
        hood = g(p.x,p.z,0.0,anatomy_z+height*0.013,width*0.022,height*0.0045)
        glans = g(p.x,p.z,0.0,anatomy_z+height*0.007,width*0.0050,height*0.0035)
        frenulum = g(p.x,p.z,0.0,anatomy_z+height*0.001,width*0.0030,height*0.0025)
        fourchette = g(p.x,p.z,0.0,anatomy_z-height*0.051,width*0.016,height*0.0035)
        perineum = g(p.x,p.z,0.0,anatomy_z-height*0.068,width*0.045,height*0.013)
        outward = deformation_scale * height * (
            0.0055*mons + 0.0080*(outer_l+outer_r)
            + 0.0080*(inner_l+inner_r) + 0.0055*hood
            + 0.0040*glans + 0.0018*frenulum + 0.0010*fourchette
        )
        inward = deformation_scale * height * (
            0.0040*vestibule + 0.0110*cleft
            + 0.0018*urethra + 0.0022*vaginal + 0.0004*perineum
        )
        p.y -= outward
        p.y += inward
        return p

    if preserve_morphs:
        # Ara's facial shape keys store absolute vertex positions. Apply the
        # exact same local displacement to every key block so facial morphs
        # retain their deltas and the mesh topology stays unchanged.
        print(f"Preserving {len(key_blocks)-1} Ara shape keys; anatomy sculpt will not subdivide the skin topology.")
        for vertex in skin.data.vertices:
            original = vertex.co.copy()
            world = skin.matrix_world @ original
            normal = normal_matrix @ vertex.normal
            deformed = inv @ deform_world_point(world, normal)
            delta = deformed - original
            if delta.length_squared <= 1e-18:
                continue
            vertex.co = deformed
            for key_block in key_blocks[1:]:
                key_point = key_block.data[vertex.index]
                key_point.co = key_point.co + delta
        skin.data.update()
        after_keys = skin.data.shape_keys
        if after_keys is None or len(after_keys.key_blocks) != len(key_blocks):
            raise RuntimeError("Anatomy sculpt failed to preserve Ara facial shape keys")
        for key_block in after_keys.key_blocks:
            if len(key_block.data) != len(skin.data.vertices):
                raise RuntimeError(f"Anatomy sculpt left invalid shape key vertex count: {key_block.name}")
    else:
        # Without shape keys, add local tessellation to improve the anatomical
        # folds and recesses before deforming the existing skin surface.
        bm = bmesh.new()
        bm.from_mesh(skin.data)
        bm.normal_update()
        edges = []
        for edge in bm.edges:
            mid = (edge.verts[0].co + edge.verts[1].co) * 0.5
            world = skin.matrix_world @ mid
            normal = normal_matrix @ (edge.verts[0].normal + edge.verts[1].normal)
            if normal.length:
                normal.normalize()
            if abs(world.x) < width*0.25 and abs(world.z-anatomy_z) < 0.15 and normal.y < -0.12:
                edges.append(edge)
        if edges:
            bmesh.ops.subdivide_edges(bm, edges=edges, cuts=4, use_grid_fill=True)
            bm.normal_update()
        for vertex in bm.verts:
            world = skin.matrix_world @ vertex.co
            normal = normal_matrix @ vertex.normal
            vertex.co = inv @ deform_world_point(world, normal)
        bm.normal_update()
        bm.to_mesh(skin.data)
        bm.free()
        skin.data.update()

    for poly in skin.data.polygons:
        poly.use_smooth = True
    skin["anatomy_profile"] = "adult_female_integrated_skin"
    skin["review_status"] = "integrated_mesh_blockout_for_art_review"
    skin["anatomy_deformation_scale"] = float(deformation_scale)
    skin["anatomy_detail_pass"] = "shortened_lower_cleft_paired_inner_folds_defined_clitoral_relief_v3"
    skin["anatomy_method"] = "surface_displacement_preserve_morphs" if preserve_morphs else "local_subdivision_and_surface_displacement"
    skin["anatomy_parts"] = "mons,labia_majora,labia_minora,clitoral_hood,clitoral_glans,frenulum,vestibule,urethral_meatus,vaginal_opening,posterior_fourchette,perineal_transition"
    return skin


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
    create_piercing_sockets(armature, skin, surface_tree, minimum, height, width, anatomy_z, body_front_y)
    if anatomy is not None:
        # The hood sits just above the vulvar cleft, not on the mons pubis.
        hood_hit = front_hit_data(surface_tree, 0.0, anatomy_z + 0.034)
        if hood_hit:
            location = hood_hit[0] + hood_hit[1].normalized() * 0.0015
            hip_name = next((b.name for b in armature.data.bones if b.name.lower() in ("hips", "hip", "pelvis")), "Hips")
            create_socket(armature, "SOCKET_ClitoralHood", location, hood_hit[1], hip_name)

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
