#!/usr/bin/env python3
"""Round-trip test for Blender vertex-colour export to glTF/GLB.

Creates a tiny mesh with deliberately varied colour attributes across the
POINT/CORNER domains and FLOAT_COLOR/BYTE_COLOR storage types, exports each
case with the installed CI Blender glTF exporter, reimports it, and reports
whether COLOR_0 survived with non-default values.
"""
import json
import os
import tempfile
import bpy


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def enum_values(owner, name):
    prop = owner.get_rna_type().properties.get(name)
    if prop is None or prop.type != "ENUM":
        return []
    return [item.identifier for item in prop.enum_items]


def make_mesh(domain, colour_type):
    mesh = bpy.data.meshes.new("VertexColourRoundTripMesh")
    mesh.from_pydata(
        [(-1, 0, 0), (1, 0, 0), (1, 0, 2), (-1, 0, 2)],
        [], [(0, 1, 2, 3)]
    )
    mesh.update()
    obj = bpy.data.objects.new("VertexColourRoundTrip", mesh)
    bpy.context.collection.objects.link(obj)

    attr = mesh.color_attributes.new(name="Color", type=colour_type, domain=domain)
    values = [
        (1.0, 0.15, 0.20, 1.0),
        (0.20, 1.0, 0.25, 1.0),
        (0.25, 0.30, 1.0, 1.0),
        (0.95, 0.85, 0.15, 1.0),
    ]
    if domain == "POINT":
        for i, value in enumerate(values):
            attr.data[i].color = value
    else:
        # A quad has four loop/corner entries; make the variation unambiguous.
        for i, value in enumerate(values):
            attr.data[i].color = value
    mesh.color_attributes.active_color = attr

    material = bpy.data.materials.new("VertexColourRoundTripMaterial")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    vertex = nodes.new("ShaderNodeVertexColor")
    vertex.layer_name = "Color"
    links.new(vertex.outputs["Color"], shader.inputs["Base Color"])
    mesh.materials.append(material)
    return obj


def inspect_imported(path):
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=path)
    found = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        for attr in obj.data.color_attributes:
            channels = [component for item in attr.data for component in item.color]
            if not channels:
                continue
            found.append({
                "name": attr.name,
                "domain": attr.domain,
                "type": attr.data_type,
                "elements": len(attr.data),
                "min": min(channels),
                "max": max(channels),
                "range": max(channels) - min(channels),
                "varied": max(channels) - min(channels) > 0.2,
            })
    return found


def main():
    exporter_modes = enum_values(bpy.ops.export_scene.gltf, "export_vertex_color")
    print("BLENDER_VERSION=" + bpy.app.version_string)
    print("GLTF_VERTEX_COLOUR_MODES=" + json.dumps(exporter_modes))
    results = []
    domains = ("POINT", "CORNER")
    types = ("FLOAT_COLOR", "BYTE_COLOR")
    modes = [m for m in ("ACTIVE", "NAME", "MATERIAL") if m in exporter_modes] or [None]

    with tempfile.TemporaryDirectory(prefix="gltf-colour-test-") as temp:
        for domain in domains:
            for colour_type in types:
                for mode in modes:
                    clear_scene()
                    make_mesh(domain, colour_type)
                    path = os.path.join(temp, f"{domain.lower()}_{colour_type.lower()}_{(mode or 'default').lower()}.glb")
                    kwargs = {
                        "filepath": path,
                        "export_format": "GLB",
                        "use_selection": False,
                        "export_animations": False,
                    }
                    if mode is not None:
                        kwargs["export_vertex_color"] = mode
                    bpy.ops.export_scene.gltf(**kwargs)
                    imported = inspect_imported(path)
                    passed = any(item["varied"] for item in imported)
                    result = {
                        "source_domain": domain,
                        "source_type": colour_type,
                        "export_mode": mode or "operator_default",
                        "round_trip_pass": passed,
                        "imported_attributes": imported,
                    }
                    results.append(result)
                    print("COLOUR_CASE=" + json.dumps(result))

    summary = {
        "blender_version": bpy.app.version_string,
        "exporter_modes": exporter_modes,
        "cases": results,
        "passing_cases": sum(1 for item in results if item["round_trip_pass"]),
    }
    print("COLOUR_TEST_SUMMARY=" + json.dumps(summary, indent=2))
    if not summary["passing_cases"]:
        raise RuntimeError("No tested Blender vertex-colour representation survived GLB round-trip")


if __name__ == "__main__":
    main()
