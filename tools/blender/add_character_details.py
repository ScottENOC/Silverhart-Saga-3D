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
from mathutils.kdtree import KDTree


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
    world = skin.matrix_world
    normal_matrix = world.to_3x3().inverted().transposed()
    front_items, back_items = [], []
    for vertex in skin.data.vertices:
        point = world @ vertex.co
        normal = (normal_matrix @ vertex.normal).normalized()
        # Ara GLBs are Y-up on disk, but Blender's glTF importer converts
        # them to Z-up with the character facing -Y. Front/back therefore use
        # the Y normal, while tattoo paths live in the X/Z body plane.
        if normal.y < -0.12:
            front_items.append((point, normal, vertex.index))
        if normal.y > 0.12:
            back_items.append((point, normal, vertex.index))
    trees = {}
    for label, items in (("front", front_items), ("back", back_items)):
        if not items:
            raise RuntimeError(f"No {label}-facing skin vertices found for tattoo projection")
        tree = KDTree(len(items))
        for item_index, (point, _normal, _vertex_index) in enumerate(items):
            # Tattoo design paths are authored in the body's X/Z plane.
            # The front/back candidates are already separated by their Y normals,
            # so the nearest-point query follows the projected skin footprint.
            tree.insert(Vector((point.x, point.z, 0.0)), item_index)
        tree.balance()
        trees[label] = (tree, items)
    return trees


def project_path(points, back, trees, offset=0.0020):
    label = "back" if back else "front"
    tree, items = trees[label]
    projected = []
    for segment in range(len(points) - 1):
        a, b = points[segment], points[segment + 1]
        steps = max(2, int(math.ceil((b - a).length / 0.018)))
        for step in range(steps):
            p = a.lerp(b, step / steps)
            _co, item_index, distance = tree.find(Vector((p.x, p.z, 0.0)))
            if distance > 0.06:
                raise RuntimeError(
                    f"tattoo path is {distance:.3f}m outside the {label} skin footprint"
                )
            surface, normal, source_index = items[item_index]
            projected.append((surface + normal * offset, normal, source_index))
    p = points[-1]
    _co, item_index, distance = tree.find(Vector((p.x, p.z, 0.0)))
    if distance > 0.06:
        raise RuntimeError(
            f"tattoo endpoint is {distance:.3f}m outside the {label} skin footprint"
        )
    surface, normal, source_index = items[item_index]
    projected.append((surface + normal * offset, normal, source_index))
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
                sx = centre.x + side * width * .14
                path([Vector((centre.x + side * width * .05, back, shoulder_z)),
                      Vector((sx, back, shoulder_z - height * .018)),
                      Vector((sx + side * width * .012, back, shoulder_z - height * .07))],
                     height * .0038, True)
                star = Vector((centre.x + side * width * .18, back, shoulder_z - height * .018))
                path(star_points(star, height * .012), height * .012 * .11, True)
                arm_x, arm_z = centre.x + side * width * .255, centre.z - height * .015
                path([Vector((arm_x, front, arm_z)),
                      Vector((arm_x - side * width * .018, front, arm_z - height * .035)),
                      Vector((arm_x, front, arm_z - height * .07))], height * .0015, False)
                star = Vector((arm_x, front, arm_z - height * .09))
                path(star_points(star, height * .012), height * .012 * .11, False)
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
                      Vector((centre.x + side * width * .11, back, shoulder_z + height * .025)),
                      Vector((centre.x + side * width * .22, back, shoulder_z + height * .005)),
                      Vector((centre.x + side * width * .27, back, shoulder_z - height * .055))],
                     height * .0045, True)
                for feather in range(3):
                    x = centre.x + side * width * (0.10 + feather * 0.055)
                    zz = shoulder_z + height * (0.012 - feather * 0.012)
                    path([Vector((x, back, zz)),
                          Vector((x + side * width * .025, back, zz - height * .045)),
                          Vector((x + side * width * .055, back, zz - height * .065))],
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
    """Straight horizontal nipple bar, anchored at the original skin socket."""
    matrix = socket.matrix_world.copy()
    anchor = matrix.translation.copy()
    normal = (matrix.to_3x3() @ Vector((0, 0, 1))).normalized()
    tangent = Vector((1, 0, 0))
    tangent -= normal * tangent.dot(normal)
    if tangent.length_squared < 1e-8:
        tangent = Vector((0, 1, 0))
        tangent -= normal * tangent.dot(normal)
    tangent.normalize()
    # Keep the attachment at the socket; only a tiny outward clearance avoids
    # z-fighting. Do not translate the bar along the chest or rotate the socket.
    centre = anchor + normal * 0.0012
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.0018, depth=0.020,
                                        location=centre)
    bar = bpy.context.object
    bar.name = "Piercing_SOCKET_Nipple_L_Bar"
    bar.rotation_mode = "QUATERNION"
    bar.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(tangent)
    bar.data.materials.append(material)
    parent_preserve(bar, socket, bar.matrix_world.copy())
    bar["character_detail_type"] = "piercing"
    for side in (-1.0, 1.0):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8,
                                             radius=0.0032,
                                             location=centre + tangent * side * 0.010)
        bead = bpy.context.object
        bead.name = "Piercing_SOCKET_Nipple_L_Bead"
        bead.data.materials.append(material)
        parent_preserve(bead, socket, bead.matrix_world.copy())
        bead["character_detail_type"] = "piercing"
    print(f"BAKED_PIERCING Piercing_SOCKET_Nipple_L straight bar socket={socket.name}")


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
                    yn = (pos.y - lo.y) / max(size.y, 1e-6)
                    xn = abs(pos.x - centre.x) / max(size.x, 1e-6)
                    print(f"SOCKET_DIAGNOSTIC {name} world={tuple(round(v,4) for v in pos)} normalized_y={yn:.3f} normalized_x={xn:.3f}")
                    # Ear sockets should be on the head, not down at shoulder height.
                    if yn < 0.76 or yn > 0.99 or xn < 0.18 or xn > 0.48:
                        side = -1.0 if name.endswith("_L") else 1.0
                        fallback = Vector((centre.x + side * size.x * 0.34,
                                           lo.y + size.y * 0.865,
                                           centre.z + size.z * 0.02))
                        print(f"WARNING: {name} outside head envelope; fallback={tuple(round(v,4) for v in fallback)}")
                        socket.location = socket.parent.matrix_world.inverted() @ fallback if socket.parent else fallback
                    add_hoop(socket, 0.010, material, "Piercing_" + name)
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
