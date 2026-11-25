"""Bake project-specific tattoos and piercings into an Ara GLB.

Ara-native earrings are generated during the character build from its own
morphed earlobe landmarks. This script handles only project-specific piercings
and tattoo tubes that need to deform with the skin mesh.
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--profile", required=True)
    return parser.parse_args(raw)


def material_name(obj):
    return " ".join(slot.material.name.lower() for slot in obj.material_slots if slot.material)


def world_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (Vector(tuple(min(p[i] for p in points) for i in range(3))),
            Vector(tuple(max(p[i] for p in points) for i in range(3))))


def find_skin():
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    skin = max((o for o in meshes if "skin" in material_name(o)),
               key=lambda o: len(o.data.polygons), default=None)
    if skin is None:
        raise RuntimeError("Could not identify Ara skin mesh for character details")
    return skin


def skin_material_indices(skin):
    """Return only material slots explicitly named as skin.

    Ara can combine skin, hair and other surfaces into one mesh object. Object
    selection alone is not a skin-only guarantee: every projection BVH must
    filter polygons by their assigned skin material.
    """
    indices = {
        index for index, slot in enumerate(skin.material_slots)
        if slot.material and "skin" in slot.material.name.lower()
    }
    if not indices:
        raise RuntimeError(
            f"No skin material slots found on {skin.name!r}; refusing to project details"
        )
    return indices


def make_material(name, hex_colour, metallic=0.0, roughness=0.8):
    colour = hex_colour.lstrip("#")
    srgb = tuple(int(colour[i:i+2], 16) / 255.0 for i in (0, 2, 4))
    def linear(channel):
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4
    rgb = tuple(linear(channel) for channel in srgb)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
    return mat


def make_projection_trees(skin):
    """Build front/back BVHs from actual skin triangles, in world coordinates.

    The old vertex KD-tree snapped each tattoo sample to an isolated nearest
    vertex in the X/Z plane. That produced visibly kinked or detached strokes
    on curved surfaces. Ray casting now intersects the continuous skin surface.
    """
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = skin.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    world = skin.matrix_world
    normal_matrix = world.to_3x3().inverted().transposed()
    vertices = [world @ vertex.co for vertex in mesh.vertices]
    front_faces, back_faces = [], []
    front_sources, back_sources = [], []
    allowed_materials = skin_material_indices(skin)
    for polygon in mesh.polygons:
        # Critical: a combined Ara mesh may contain hair/clothing polygons.
        # Never let those surfaces participate in tattoo projection.
        if polygon.material_index not in allowed_materials:
            continue
        normal = (normal_matrix @ polygon.normal).normalized()
        face = tuple(polygon.vertices)
        if normal.y < -0.12:
            front_faces.append(face)
            front_sources.append(face)
        if normal.y > 0.12:
            back_faces.append(face)
            back_sources.append(face)
    evaluated.to_mesh_clear()

    if not front_faces or not back_faces:
        raise RuntimeError("Could not build front/back skin surface for tattoo projection")
    front_tree = BVHTree.FromPolygons(vertices, front_faces, all_triangles=False)
    back_tree = BVHTree.FromPolygons(vertices, back_faces, all_triangles=False)
    lo, hi = world_bounds(skin)
    return {
        "front": (front_tree, front_sources, vertices, lo.y - 0.25, Vector((0.0, 1.0, 0.0))),
        "back": (back_tree, back_sources, vertices, hi.y + 0.25, Vector((0.0, -1.0, 0.0))),
    }


def project_path(points, back, trees, offset=0.0020, max_surface_drift=0.025):
    """Project a tattoo stroke onto skin, tolerating tiny landmark/outline errors.

    A fixed X/Z ray can miss at the edge of a character's silhouette even when
    the authored stroke is only a few millimetres outside the skin. Search a
    small, bounded X/Z neighbourhood before declaring that sample unprojectable.
    The bound prevents a stroke from being pulled around an arm/torso onto an
    unrelated surface.
    """
    label = "back" if back else "front"
    tree, faces, vertices, ray_y, direction = trees[label]

    def cast_near(point):
        origin = Vector((point.x, ray_y, point.z))
        location, normal, face_index, distance = tree.ray_cast(origin, direction, 5.0)
        if location is not None and face_index is not None:
            return location, normal, face_index, 0.0

        # Search concentric X/Z offsets, preferring the smallest displacement.
        # 5 mm increments are fine enough to follow the skin silhouette without
        # allowing a tattoo stroke to jump to a neighbouring body region.
        step = 0.005
        rings = int(max_surface_drift / step)
        candidates = []
        for ring in range(1, rings + 1):
            radius = ring * step
            count = max(8, int(math.ceil(math.tau * ring * 4)))
            for sample in range(count):
                angle = math.tau * sample / count
                x = point.x + math.cos(angle) * radius
                z = point.z + math.sin(angle) * radius
                origin = Vector((x, ray_y, z))
                hit, hit_normal, hit_face, hit_distance = tree.ray_cast(
                    origin, direction, 5.0
                )
                if hit is not None and hit_face is not None:
                    drift = math.hypot(x - point.x, z - point.z)
                    candidates.append((drift, hit, hit_normal, hit_face))
            if candidates:
                break
        if not candidates:
            return None
        candidates.sort(key=lambda item: item[0])
        drift, hit, hit_normal, hit_face = candidates[0]
        return hit, hit_normal, hit_face, drift

    projected = []
    samples = []
    for segment in range(len(points) - 1):
        a, b = points[segment], points[segment + 1]
        steps = max(2, int(math.ceil((b - a).length / 0.008)))
        samples.extend(a.lerp(b, step / steps) for step in range(steps))
    samples.append(points[-1])

    max_drift_used = 0.0
    for sample_index, point in enumerate(samples):
        result = cast_near(point)
        if result is None:
            print(
                f"WARNING: skipping {label} tattoo stroke; no skin within "
                f"{max_surface_drift:.3f}m of x={point.x:.3f}, z={point.z:.3f}"
            )
            return None
        location, normal, face_index, drift = result
        max_drift_used = max(max_drift_used, drift)
        face_vertices = faces[face_index]
        source_index = min(
            face_vertices,
            key=lambda index: (vertices[index] - location).length_squared,
        )
        projected.append((location + normal * offset, normal, source_index))

    if max_drift_used > 0:
        print(
            f"TATTOO_SURFACE_EDGE_ADJUST {label} "
            f"max_xz_drift={max_drift_used:.3f}m"
        )
    return projected


def append_tube(path, radius, back, trees, vertices, faces, sources, skin_inverse):
    if len(path) < 2 or radius <= 0:
        return
    projected = project_path(path, back, trees)
    if projected is None:
        # A single decorative stroke outside the skin silhouette should not
        # abort the entire character export or suppress otherwise valid tattoos.
        return
    sides = 8
    first = len(vertices)
    for index, (point, surface_normal, source_index) in enumerate(projected):
        before = projected[max(0, index - 1)][0]
        after = projected[min(len(projected) - 1, index + 1)][0]
        tangent = (after - before).normalized()
        axis = tangent.cross(surface_normal)
        if axis.length_squared < 1e-8:
            axis = tangent.cross(Vector((0, 1, 0)))
        if axis.length_squared < 1e-8:
            axis = tangent.cross(Vector((1, 0, 0)))
        axis.normalize()
        other = tangent.cross(axis).normalized()
        for side in range(sides):
            angle = math.tau * side / sides
            world_point = point + (axis * math.cos(angle) + other * math.sin(angle)) * radius
            vertices.append(skin_inverse @ world_point)
            sources.append(source_index)
    for ring in range(len(projected) - 1):
        a = first + ring * sides
        b = a + sides
        for side in range(sides):
            nxt = (side + 1) % sides
            faces.append((a + side, a + nxt, b + nxt, b + side))


def star_points(centre, radius):
    points = []
    for index in range(9):
        angle = math.tau * index / 8
        r = radius if index % 2 == 0 else radius * 0.28
        points.append(centre + Vector((math.cos(angle) * r, 0, math.sin(angle) * r)))
    points.append(points[0])
    return points


def add_tattoo_mesh(skin, tattoo_paths, ink_hex):
    if not tattoo_paths:
        return 0
    lo, hi = world_bounds(skin)
    height, width = hi.z - lo.z, hi.x - lo.x
    centre = (lo + hi) * 0.5
    # Blender's imported Ara scene is Z-up, facing -Y. Use the body's
    # mid-depth only as a side hint; projection is performed in X/Z.
    front_y, back_y = centre.y - 0.003, centre.y + 0.003
    trees = make_projection_trees(skin)
    vertices, faces, sources = [], [], []
    inverse = skin.matrix_world.inverted()

    def path(points, radius, back=False):
        append_tube(points, radius, back, trees, vertices, faces, sources, inverse)

    for design in tattoo_paths:
        name = str(design.get("design", "")) if isinstance(design, dict) else str(design)
        if name == "mirabel_arcane":
            back = back_y
            front = front_y
            # Keep the back sigil below the long-hair curtain and add a matching
            # chest-side mark where it is visibly on skin rather than hair.
            shoulder_z = centre.z + height * 0.17
            mid_z = centre.z + height * 0.05
            chest_z = centre.z + height * 0.20
            path([Vector((centre.x, front, chest_z + height * .035)),
                  Vector((centre.x - width * .045, front, chest_z)),
                  Vector((centre.x, front, chest_z - height * .040)),
                  Vector((centre.x + width * .045, front, chest_z)),
                  Vector((centre.x, front, chest_z + height * .035))],
                 height * .0038, False)
            for side in (-1.0, 1.0):
                path([Vector((centre.x + side * width * .045, front, chest_z)),
                      Vector((centre.x + side * width * .075, front, chest_z + height * .020)),
                      Vector((centre.x + side * width * .095, front, chest_z - height * .015))],
                     height * .0030, False)
            path([Vector((centre.x, back, shoulder_z)),
                  Vector((centre.x - width * .08, back, shoulder_z - height * .035)),
                  Vector((centre.x, back, mid_z)),
                  Vector((centre.x + width * .08, back, shoulder_z - height * .035)),
                  Vector((centre.x, back, shoulder_z))], height * .0040, True)
            # Keep the back sigil on the shoulder-blade region; the old long
            # spine stroke descended into the lower-back silhouette and read
            # as a dangling string rather than part of the arcane motif.
            for side in (-1.0, 1.0):
                sx = centre.x + side * width * .07
                path([Vector((centre.x + side * width * .035, back, shoulder_z)),
                      Vector((sx, back, shoulder_z - height * .018)),
                      Vector((sx + side * width * .009, back, shoulder_z - height * .07))],
                     height * .0038, True)
                star = Vector((centre.x + side * width * .13, back, shoulder_z - height * .018))
                path(star_points(star, height * .012), height * .012 * .11, True)
                # The fixed-coordinate front-arm strokes also fall outside
                # Mirabel's exported front-skin footprint (0.098 m in the
                # latest native build). Keep this motif on the verified back
                # surface until arm paths can be authored from actual landmarks.
            # Omit the lower-thigh strokes from this motif. Their fixed
            # X/Z coordinates fall outside Mirabel's actual front-skin footprint;
            # the upper-body, back and arm sigils remain surface-projected.

        elif name == "reyna_shoulder_back":
            shoulder_z, back = centre.z + height * .29, back_y
            path([Vector((centre.x, back, shoulder_z + height * .025)),
                  Vector((centre.x, back, shoulder_z - height * .055)),
                  Vector((centre.x, back, shoulder_z - height * .16))], height * .0028, True)
            for side in (-1.0, 1.0):
                path([Vector((centre.x, back, shoulder_z - height * .015)),
                      Vector((centre.x + side * width * .045, back, shoulder_z + height * .025)),
                      Vector((centre.x + side * width * .075, back, shoulder_z + height * .005)),
                      Vector((centre.x + side * width * .085, back, shoulder_z - height * .055))],
                     height * .0045, True)
                for feather in range(3):
                    x = centre.x + side * width * (0.035 + feather * 0.020)
                    zz = shoulder_z + height * (0.012 - feather * 0.012)
                    path([Vector((x, back, zz)),
                          Vector((x + side * width * .008, back, zz - height * .045)),
                          Vector((x + side * width * .012, back, zz - height * .065))],
                         height * .0035, True)
            star = Vector((centre.x, back, shoulder_z + height * .035))
            path(star_points(star, height * .014), height * .014 * .11, True)
        else:
            print(f"WARNING: Unknown tattoo design {name!r}; skipping")

    if not vertices or not faces:
        return 0
    mesh = bpy.data.meshes.new("Ara_Tattoo_Details_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Ara_Tattoo_Details", mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = skin.parent
    obj.matrix_world = skin.matrix_world.copy()
    mesh.materials.append(make_material("Ara_Tattoo_Ink", ink_hex, 0.0, 1.0))

    # Transfer nearest-skin-vertex weights for armature deformation.
    group_map = {g.index: obj.vertex_groups.new(name=g.name) for g in skin.vertex_groups}
    for new_index, source_index in enumerate(sources):
        for assignment in skin.data.vertices[source_index].groups:
            group = group_map.get(assignment.group)
            if group is not None and assignment.weight > 0:
                group.add([new_index], assignment.weight, "REPLACE")

    armature = next((m.object for m in skin.modifiers if m.type == "ARMATURE" and m.object), None)
    if armature is None:
        armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    if armature:
        modifier = obj.modifiers.new("Ara Tattoo Armature", "ARMATURE")
        modifier.object = armature
        source_modifier = next((m for m in skin.modifiers if m.type == "ARMATURE"), None)
        if source_modifier:
            modifier.use_vertex_groups = source_modifier.use_vertex_groups
            modifier.use_bone_envelopes = source_modifier.use_bone_envelopes
            modifier.use_deform_preserve_volume = source_modifier.use_deform_preserve_volume
    obj["character_detail_type"] = "tattoo"
    obj["tattoo_designs"] = ",".join(str(d.get("design", "")) if isinstance(d, dict) else str(d)
                                      for d in tattoo_paths)
    print(f"BAKED_TATTOOS vertices={len(vertices)} faces={len(faces)} weighted={bool(armature)}")
    return len(vertices)


def parent_preserve(obj, parent, world_matrix):
    obj.parent = parent
    obj.matrix_world = world_matrix


def make_skin_surface_tree(skin):
    """Build a world-space BVH of the final sculpted skin for surface-anchored piercings."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = skin.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    vertices = [skin.matrix_world @ vertex.co for vertex in mesh.vertices]
    allowed_materials = skin_material_indices(skin)
    polygons = [
        list(poly.vertices) for poly in mesh.polygons
        if poly.material_index in allowed_materials
    ]
    if not polygons:
        evaluated.to_mesh_clear()
        raise RuntimeError(
            f"No skin-material polygons available for surface anchoring on {skin.name!r}"
        )
    tree = BVHTree.FromPolygons(vertices, polygons, all_triangles=False)
    evaluated.to_mesh_clear()
    return tree


def add_barbell(socket, material, surface_tree):
    """Place the clitoral barbell on the visible front skin, not inside the sculpt."""
    socket_position = socket.matrix_world.translation.copy()
    hit, _normal, _face_index, distance = surface_tree.ray_cast(
        Vector((socket_position.x, -2.0, socket_position.z)),
        Vector((0.0, 1.0, 0.0)),
        4.0,
    )
    if hit is None:
        raise RuntimeError(
            "Clitoral piercing socket did not intersect the front skin surface: "
            f"socket={tuple(round(v, 4) for v in socket_position)}"
        )
    # Ara's imported Blender scene faces -Y. Place the bar just clear of the
    # actual sculpted surface, with its shaft running horizontally across X.
    front = Vector((0.0, -1.0, 0.0))
    tangent = Vector((1.0, 0.0, 0.0))
    location = hit + front * 0.003
    # As with the nipple barbell, use an X-stretched sphere for the shaft.
    # A rotated cylinder exported with Ara's rig axes appeared vertical despite
    # its two end beads being horizontally aligned.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12,
                                         radius=0.0018, location=location)
    bar = bpy.context.object
    bar.name = "Piercing_SOCKET_ClitoralHood_Bar"
    bar.scale = (6.0, 1.0, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bar.data.materials.append(material)
    parent_preserve(bar, socket, bar.matrix_world.copy())
    bar["character_detail_type"] = "piercing"
    for side in (-1.0, 1.0):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8,
                                             radius=0.0038,
                                             location=location + tangent * side * 0.009)
        bead = bpy.context.object
        bead.name = "Piercing_SOCKET_ClitoralHood_Bead"
        bead.data.materials.append(material)
        parent_preserve(bead, socket, bead.matrix_world.copy())
        bead["character_detail_type"] = "piercing"
    print(
        "BAKED_PIERCING clitoral barbell on front skin "
        f"socket={socket.name} surface_distance={distance:.4f}"
    )


def add_nipple_barbell(socket, material):
    """Horizontal two-ball barbell, anchored at Ara's original nipple socket.

    Build the connecting shaft as a sphere stretched along world X rather than
    a rotated cylinder. This avoids the Blender/glTF axis conversion that made
    the exported shaft appear vertical while its end beads stayed horizontal.
    """
    matrix = socket.matrix_world.copy()
    anchor = matrix.translation.copy()
    normal = (matrix.to_3x3() @ Vector((0, 0, 1))).normalized()
    centre = anchor + normal * 0.0012

    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12,
                                         radius=0.0018, location=centre)
    bar = bpy.context.object
    bar.name = "Piercing_SOCKET_Nipple_L_Bar"
    bar.scale = (6.0, 1.0, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bar.data.materials.append(material)
    parent_preserve(bar, socket, bar.matrix_world.copy())
    bar["character_detail_type"] = "piercing"

    for side in (-1.0, 1.0):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10,
                                             radius=0.0035,
                                             location=centre + Vector((side * 0.0105, 0.0, 0.0)))
        bead = bpy.context.object
        bead.name = "Piercing_SOCKET_Nipple_L_Bead"
        bead.data.materials.append(material)
        parent_preserve(bead, socket, bead.matrix_world.copy())
        bead["character_detail_type"] = "piercing"
    print(f"BAKED_PIERCING Piercing_SOCKET_Nipple_L horizontal barbell socket={socket.name}")

def add_piercings(entries, skin):
    """Bake project-specific piercings Ara does not provide natively.

    Earrings are deliberately absent here: Ara generates and skins them from
    its own morphed earlobe landmarks via the character params (earrings and
    earringMetal). Keeping a second Blender earring path caused the old
    shoulder-placement/socket/BVH failures.
    """
    custom_entries = [entry for entry in entries if entry != "earrings"]
    material = make_material("Ara_Piercing_Silver", "#C6CBD0", 0.82, 0.24)
    sockets = {obj.name: obj for obj in bpy.context.scene.objects}
    surface_tree = make_skin_surface_tree(skin) if "clit" in custom_entries else None
    count = 0
    for entry in custom_entries:
        if entry == "nipple_left":
            socket = sockets.get("SOCKET_Nipple_L")
            if socket:
                add_nipple_barbell(socket, material)
                count += 1
            else:
                print("WARNING: Ara socket SOCKET_Nipple_L not found; piercing omitted")
        elif entry == "clit":
            socket = sockets.get("SOCKET_ClitoralHood")
            if socket:
                add_barbell(socket, material, surface_tree)
                count += 1
            else:
                print("WARNING: Ara socket SOCKET_ClitoralHood not found; piercing omitted")
        else:
            print(f"WARNING: Unknown custom piercing profile entry {entry!r}")
    if "earrings" in entries:
        print("NATIVE_ARA_EARRINGS: generated by Ara from params; no Blender socket pass")
    return count

def main():
    args = arguments()
    with open(args.profile, "r", encoding="utf-8") as handle:
        profile = json.load(handle)
    details = profile.get("character_details", {})
    params = profile.get("params", {})
    piercings = details.get("piercings", params.get("piercings", []))
    tattoos = details.get("tattoos", [])
    ink = details.get("tattoo_ink", params.get("tattoo_ink", "#28252D"))

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    skin = find_skin()
    piercing_count = add_piercings(piercings, skin)
    tattoo_vertices = add_tattoo_mesh(skin, tattoos, ink)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"}:
            obj.select_set(True)
    armature = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    if armature:
        bpy.context.view_layer.objects.active = armature
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB",
                              use_selection=True, export_apply=False, export_animations=True)
    print(f"EXPORTED_CHARACTER_DETAILS piercings={piercing_count} tattoo_vertices={tattoo_vertices}")


if __name__ == "__main__":
    main()
