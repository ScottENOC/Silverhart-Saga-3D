"""Bake profile tattoos and socket-mounted piercings into an Ara GLB.

Tattoo tubes are projected onto the skin surface and receive the skin mesh's
vertex-group weights, so they deform with the same armature. Piercings are
real mesh objects parented to Ara's exported socket nodes.
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector
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
    for polygon in mesh.polygons:
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


def project_path(points, back, trees, offset=0.0020):
    label = "back" if back else "front"
    tree, faces, vertices, ray_y, direction = trees[label]
    projected = []
    for segment in range(len(points) - 1):
        a, b = points[segment], points[segment + 1]
        steps = max(2, int(math.ceil((b - a).length / 0.008)))
        for step in range(steps):
            p = a.lerp(b, step / steps)
            origin = Vector((p.x, ray_y, p.z))
            location, normal, face_index, distance = tree.ray_cast(origin, direction, 5.0)
            if location is None or face_index is None:
                raise RuntimeError(
                    f"tattoo path has no {label} skin-surface intersection "
                    f"at x={p.x:.3f}, z={p.z:.3f}"
                )
            face_vertices = faces[face_index]
            source_index = min(
                face_vertices,
                key=lambda index: (vertices[index] - location).length_squared,
            )
            projected.append((location + normal * offset, normal, source_index))
    p = points[-1]
    origin = Vector((p.x, ray_y, p.z))
    location, normal, face_index, distance = tree.ray_cast(origin, direction, 5.0)
    if location is None or face_index is None:
        raise RuntimeError(
            f"tattoo endpoint has no {label} skin-surface intersection "
            f"at x={p.x:.3f}, z={p.z:.3f}"
        )
    face_vertices = faces[face_index]
    source_index = min(
        face_vertices,
        key=lambda index: (vertices[index] - location).length_squared,
    )
    projected.append((location + normal * offset, normal, source_index))
    return projected


def append_tube(path, radius, back, trees, vertices, faces, sources, skin_inverse):
    if len(path) < 2 or radius <= 0:
        return
    projected = project_path(path, back, trees)
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
            shoulder_z = centre.z + height * 0.29
            mid_z = centre.z + height * 0.12
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


def add_hoop(socket, radius, material, name, hang_down=False):
    socket_matrix = socket.matrix_world.copy()
    normal = (socket_matrix.to_3x3() @ Vector((0, 0, 1))).normalized()
    world = socket_matrix.copy()
    centre = socket_matrix.translation + normal * 0.0008
    if hang_down:
        # Blender scene coordinates are Z-up. Ara's source GLB is Y-up, but the glTF
        # importer converts it into Blender's Z-up world. Use world -Z here;
        # using -Y makes the hoop tilt along the wrong axis.
        down = Vector((0, 0, -1))
        down -= normal * down.dot(normal)
        if down.length_squared < 1e-8:
            down = Vector((0, 0, -1))
        down.normalize()
        outward = normal.normalized()
        # The hoop's plane must be tangent to the chest and vertical: its
        # local X axis runs sideways, local Y hangs down, and its normal faces
        # outward. The previous basis used outward as an in-plane axis, which
        # made the ring project away from the body instead of hanging flat.
        tangent = down.cross(outward)
        if tangent.length_squared < 1e-8:
            tangent = Vector((1, 0, 0))
            tangent -= outward * tangent.dot(outward)
        tangent.normalize()
        plane_normal = tangent.cross(down).normalized()
        orientation = Matrix((tangent, down, plane_normal)).transposed().to_quaternion()
        centre += down * radius * 0.89 + outward * 0.0005
    else:
        orientation = socket_matrix.to_quaternion()
        centre += normal * 0.0012
    # Ara long hair can cover the ear socket from the front. Place the hoop
    # slightly forward (the imported Blender scene faces -Y) so it remains
    # visible without moving the attachment away from the earlobe.
    if name.startswith("Piercing_SOCKET_Earring_"):
        side = -1.0 if name.endswith("_L") else 1.0
        centre += Vector((side * 0.022, -0.035, -0.006))
    world.translation = centre
    bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=12,
                                     location=world.translation,
                                     major_radius=radius * 0.89,
                                     minor_radius=radius * 0.11)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = orientation
    obj.data.materials.append(material)
    parent_preserve(obj, socket, obj.matrix_world.copy())
    obj["character_detail_type"] = "piercing"
    print(f"BAKED_PIERCING {name} socket={socket.name}")


def add_barbell(socket, material):
    matrix = socket.matrix_world.copy()
    centre = matrix.translation
    normal = (matrix.to_3x3() @ Vector((0, 0, 1))).normalized()
    tangent = (matrix.to_3x3() @ Vector((1, 0, 0))).normalized()
    location = centre + normal * 0.007
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.0022, depth=0.016,
                                        location=location)
    bar = bpy.context.object
    bar.name = "Piercing_SOCKET_ClitoralHood_Bar"
    bar.rotation_mode = "QUATERNION"
    bar.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(tangent)
    bar.data.materials.append(material)
    parent_preserve(bar, socket, bar.matrix_world.copy())
    bar["character_detail_type"] = "piercing"
    for side in (-1.0, 1.0):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8,
                                             radius=0.0038, location=location + tangent * side * 0.009)
        bead = bpy.context.object
        bead.name = "Piercing_SOCKET_ClitoralHood_Bead"
        bead.data.materials.append(material)
        parent_preserve(bead, socket, bead.matrix_world.copy())
        bead["character_detail_type"] = "piercing"
    print(f"BAKED_PIERCING clitoral barbell socket={socket.name}")


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

def add_piercings(entries):
    material = make_material("Ara_Piercing_Silver", "#C6CBD0", 0.82, 0.24)
    sockets = {obj.name: obj for obj in bpy.context.scene.objects}
    count = 0
    for entry in entries:
        if entry == "earrings":
            for name in ("SOCKET_Earring_L", "SOCKET_Earring_R"):
                socket = sockets.get(name)
                if socket:
                    lo, hi = world_bounds(find_skin())
                    size = hi - lo
                    centre = (lo + hi) * 0.5
                    pos = socket.matrix_world.translation.copy()
                    # Ara's imported Blender scene is Z-up and faces -Y.
                    # The old check used Y (depth) as height and consequently
                    # classified valid ear sockets as shoulder-level.
                    zn = (pos.z - lo.z) / max(size.z, 1e-6)
                    xn = abs(pos.x - centre.x) / max(size.x, 1e-6)
                    print(f"SOCKET_DIAGNOSTIC {name} world={tuple(round(v,4) for v in pos)} normalized_z={zn:.3f} normalized_x={xn:.3f}")
                    # Ear sockets belong high on the head, lateral to the face.
                    # The exported Ara ear sockets are misplaced at shoulder height
                    # in this profile (the old envelope test accepted them because
                    # their normalised height happened to look plausible). Always
                    # anchor the hoops to the visible ear-lobe envelope instead.
                    side = -1.0 if name.endswith("_L") else 1.0
                    fallback = Vector((centre.x + side * size.x * 0.10,
                                       lo.y + size.y * 0.10,
                                       lo.z + size.z * 0.88))
                    print(f"EAR_SOCKET_REPOSITION {name} from={tuple(round(v,4) for v in pos)} to={tuple(round(v,4) for v in fallback)}")
                    socket_world = socket.matrix_world.copy()
                    socket_world.translation = fallback
                    socket.matrix_world = socket_world
                    add_hoop(socket, 0.016, material, "Piercing_" + name, hang_down=True)
                    count += 1
                else:
                    print(f"WARNING: Ara socket {name} not found; piercing omitted")
        elif entry == "nipple_left":
            socket = sockets.get("SOCKET_Nipple_L")
            if socket:
                add_nipple_barbell(socket, material)
                count += 1
            else:
                print("WARNING: Ara socket SOCKET_Nipple_L not found; piercing omitted")
        elif entry == "clit":
            socket = sockets.get("SOCKET_ClitoralHood")
            if socket:
                add_barbell(socket, material)
                count += 1
            else:
                print("WARNING: Ara socket SOCKET_ClitoralHood not found; piercing omitted")
        else:
            print(f"WARNING: Unknown piercing profile entry {entry!r}")
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
    piercing_count = add_piercings(piercings)
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
