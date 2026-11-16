#!/usr/bin/env python3
"""Extract rigged Ara garment primitives as compact standalone GLBs.

The anatomy-integrated body supplies the canonical skeleton. A garment export
is appended to that body, fitted against its existing anatomy, then stripped
of the body surface before being written as a standalone skinned mesh.
"""
import argparse
import copy
from pathlib import Path

import assemble_modular_glb as assembler


def material_name(doc, primitive):
    index = primitive.get("material")
    if index is None:
        return ""
    return str(doc.get("materials", [])[index].get("name", ""))


def strip_body_mesh(doc, keep_materials):
    body = assembler.body_node(doc)
    mesh = doc["meshes"][body["mesh"]]
    tokens = [str(value).strip().lower() for value in keep_materials if str(value).strip()]
    if not tokens:
        raise ValueError("At least one --keep-material token is required")
    mesh["primitives"] = [
        primitive for primitive in mesh["primitives"]
        if any(material_name(doc, primitive).strip().lower().startswith(token) for token in tokens)
    ]
    if not mesh["primitives"]:
        available = [_material_name for _material_name in (
            material_name(doc, primitive) for primitive in doc["meshes"][body["mesh"]]["primitives"]
        )]
        raise ValueError("No selected garment primitives remain; requested=%s available=%s" % (tokens, available))
    return body


def collect_texture_indices(value, output):
    if isinstance(value, dict):
        if isinstance(value.get("index"), int):
            output.add(value["index"])
        for child in value.values():
            collect_texture_indices(child, output)
    elif isinstance(value, list):
        for child in value:
            collect_texture_indices(child, output)


def compact(doc, binary, body_node):
    """Keep only the garment mesh, its skinning, animation, and material data."""
    mesh = copy.deepcopy(doc["meshes"][body_node["mesh"]])
    used_accessors = set()
    for primitive in mesh["primitives"]:
        used_accessors.update(primitive.get("attributes", {}).values())
        if "indices" in primitive:
            used_accessors.add(primitive["indices"])
        for target in primitive.get("targets", []):
            used_accessors.update(target.values())

    for skin in doc.get("skins", []):
        if "inverseBindMatrices" in skin:
            used_accessors.add(skin["inverseBindMatrices"])
    for animation in doc.get("animations", []):
        for sampler in animation.get("samplers", []):
            used_accessors.add(sampler["input"])
            used_accessors.add(sampler["output"])

    used_materials = sorted({
        primitive["material"] for primitive in mesh["primitives"]
        if "material" in primitive
    })
    material_map = {old: new for new, old in enumerate(used_materials)}
    for primitive in mesh["primitives"]:
        if "material" in primitive:
            primitive["material"] = material_map[primitive["material"]]

    used_textures = set()
    for material_index in used_materials:
        collect_texture_indices(doc["materials"][material_index], used_textures)
    used_textures = {i for i in used_textures if i < len(doc.get("textures", []))}
    used_images, used_samplers = set(), set()
    for texture_index in used_textures:
        texture = doc["textures"][texture_index]
        if "source" in texture:
            used_images.add(texture["source"])
        if "sampler" in texture:
            used_samplers.add(texture["sampler"])

    used_views = set()
    for accessor_index in used_accessors:
        accessor = doc["accessors"][accessor_index]
        if "bufferView" in accessor:
            used_views.add(accessor["bufferView"])
        sparse = accessor.get("sparse")
        if sparse:
            used_views.add(sparse["indices"]["bufferView"])
            used_views.add(sparse["values"]["bufferView"])
    for image_index in used_images:
        image = doc["images"][image_index]
        if "bufferView" in image:
            used_views.add(image["bufferView"])

    new_binary = bytearray()
    view_map, new_views = {}, []
    for old_view in sorted(used_views):
        view = copy.deepcopy(doc["bufferViews"][old_view])
        offset, length = int(view.get("byteOffset", 0)), int(view["byteLength"])
        payload = binary[offset:offset + length]
        if len(payload) != length:
            raise ValueError("Buffer view extends beyond the source GLB binary chunk")
        new_binary.extend(b"\0" * (-len(new_binary) % 4))
        view["byteOffset"] = len(new_binary)
        view_map[old_view] = len(new_views)
        new_views.append(view)
        new_binary.extend(payload)

    accessor_map, new_accessors = {}, []
    for old_accessor in sorted(used_accessors):
        accessor = copy.deepcopy(doc["accessors"][old_accessor])
        if "bufferView" in accessor:
            accessor["bufferView"] = view_map[accessor["bufferView"]]
        sparse = accessor.get("sparse")
        if sparse:
            sparse["indices"]["bufferView"] = view_map[sparse["indices"]["bufferView"]]
            sparse["values"]["bufferView"] = view_map[sparse["values"]["bufferView"]]
        accessor_map[old_accessor] = len(new_accessors)
        new_accessors.append(accessor)

    for primitive in mesh["primitives"]:
        primitive["attributes"] = {
            key: accessor_map[value]
            for key, value in primitive.get("attributes", {}).items()
        }
        if "indices" in primitive:
            primitive["indices"] = accessor_map[primitive["indices"]]
        for target in primitive.get("targets", []):
            for key in list(target):
                target[key] = accessor_map[target[key]]

    for skin in doc.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = accessor_map[skin["inverseBindMatrices"]]
    for animation in doc.get("animations", []):
        for sampler in animation.get("samplers", []):
            sampler["input"] = accessor_map[sampler["input"]]
            sampler["output"] = accessor_map[sampler["output"]]

    image_map = {old: new for new, old in enumerate(sorted(used_images))}
    sampler_map = {old: new for new, old in enumerate(sorted(used_samplers))}
    texture_map = {old: new for new, old in enumerate(sorted(used_textures))}
    new_images = [copy.deepcopy(doc["images"][i]) for i in sorted(used_images)]
    for image in new_images:
        if "bufferView" in image:
            image["bufferView"] = view_map[image["bufferView"]]
    new_samplers = [copy.deepcopy(doc["samplers"][i]) for i in sorted(used_samplers)]
    new_textures = [copy.deepcopy(doc["textures"][i]) for i in sorted(used_textures)]
    for texture in new_textures:
        if "source" in texture:
            texture["source"] = image_map[texture["source"]]
        if "sampler" in texture:
            texture["sampler"] = sampler_map[texture["sampler"]]

    def remap_material_textures(value):
        if isinstance(value, dict):
            if isinstance(value.get("index"), int) and value["index"] in texture_map:
                value["index"] = texture_map[value["index"]]
            for child in value.values():
                remap_material_textures(child)
        elif isinstance(value, list):
            for child in value:
                remap_material_textures(child)

    new_materials = [copy.deepcopy(doc["materials"][i]) for i in used_materials]
    for material in new_materials:
        remap_material_textures(material)

    new_nodes = copy.deepcopy(doc["nodes"])
    target_node_index = doc["nodes"].index(body_node)
    for index, node in enumerate(new_nodes):
        if index == target_node_index:
            node["mesh"] = 0
        else:
            node.pop("mesh", None)
            node.pop("weights", None)

    result = copy.deepcopy(doc)
    result["nodes"] = new_nodes
    result["meshes"] = [mesh]
    result["accessors"] = new_accessors
    result["bufferViews"] = new_views
    result["materials"] = new_materials
    result["textures"] = new_textures
    result["images"] = new_images
    result["samplers"] = new_samplers
    result["buffers"] = [{"byteLength": len(new_binary)}]
    return result, bytes(new_binary)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--body", default="")
    parser.add_argument("--source", default="")
    parser.add_argument("--selector", action="append", default=[])
    parser.add_argument("--strip-input", default="")
    parser.add_argument("--keep-material", action="append", default=[])
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    if args.strip_input:
        doc, binary = assembler.read(args.strip_input)
        body_node = strip_body_mesh(doc, args.keep_material)
        compact_doc, compact_binary = compact(doc, binary, body_node)
        assembler.validate_morph_targets(compact_doc)
        assembler.write(args.output, compact_doc, compact_binary)
        check, _ = assembler.read(args.output)
        if len(check.get("meshes", [])) != 1:
            raise ValueError("Standalone garment GLB must contain exactly one mesh")
        print("Wrote %s (%s bytes, %s garment primitives)" % (
            args.output, Path(args.output).stat().st_size,
            len(check["meshes"][0]["primitives"])
        ))
        return

    if not args.body or not args.source or not args.selector:
        parser.error("provide --body, --source and at least one --selector, or use --strip-input")
    doc, binary = assembler.read(args.body)
    binary = binary[:doc["buffers"][0]["byteLength"]]
    for selector in args.selector:
        doc, binary = assembler.add(doc, binary, args.source, selector)
    assembler.validate_morph_targets(doc)
    assembler.write(args.output, doc, binary)
    print("Wrote fitted-body assembly %s (%s bytes)" % (
        args.output, Path(args.output).stat().st_size
    ))


if __name__ == "__main__":
    main()
