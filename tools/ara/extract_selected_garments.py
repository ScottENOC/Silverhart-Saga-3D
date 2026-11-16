#!/usr/bin/env python3
"""Extract a deliberately small Ara garment set from already-generated GLBs.

This uses the existing generated files in build/local-cache/ara/generated. It
does not run Blender, download assets, or regenerate body/anatomy exports.
"""
import argparse
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import assemble_modular_glb as assembler
import extract_garment_glb as extractor


ASSETS = {
    "lace_briefs": "ara_person_lace_briefs.glb",
    "fishnet_briefs": "ara_person_fishnet_briefs.glb",
    "lace_pants": "ara_person_lace_pants.glb",
    "fishnet_pants": "ara_person_fishnet_pants.glb",
    "lace_shirt": "ara_person_lace_shirt.glb",
    "fishnet_shirt": "ara_person_fishnet_shirt.glb",
    "halter_bra_lace": "ara_person_halter_bra_lace.glb",
    "halter_bra_fishnet": "ara_person_halter_bra_fishnet.glb",
    "leather_armor": "ara_person_leather_armor.glb",
}

BODY_MATERIALS = {
    "skin", "skin details", "eyes", "eyebrows", "eyelashes",
    "teeth", "tongue", "hair", "nails",
}


def normalise_material(name):
    value = " ".join(str(name).strip().lower().replace("_", " ").split())
    return re.sub(r"\.\d+$", "", value)


def is_body_material(name):
    value = normalise_material(name)
    return any(value == base or value.startswith(base + " ") for base in BODY_MATERIALS)


def primitive_material_name(doc, primitive):
    index = primitive.get("material")
    if index is None:
        return ""
    materials = doc.get("materials", [])
    if index < 0 or index >= len(materials):
        raise ValueError("Primitive references an invalid material index: %s" % index)
    return str(materials[index].get("name", ""))


def extract_one(source_path, output_path, dry_run=False):
    doc, binary = assembler.read(source_path)
    candidates = []
    for node in doc.get("nodes", []):
        if "mesh" not in node or "skin" not in node:
            continue
        mesh = doc["meshes"][node["mesh"]]
        names = [primitive_material_name(doc, primitive) for primitive in mesh.get("primitives", [])]
        has_body = any(is_body_material(name) for name in names)
        has_garment = any(name and not is_body_material(name) for name in names)
        if has_body and has_garment:
            candidates.append((node, names))
    if len(candidates) != 1:
        raise ValueError(
            "%s: expected one skinned body/garment mesh, found %d"
            % (source_path, len(candidates))
        )

    node, names = candidates[0]
    selected = sorted({name for name in names if name and not is_body_material(name)})
    if not selected:
        raise ValueError("%s: no non-body garment materials found; materials=%s" % (source_path, names))

    print("%s -> %s" % (source_path.name, output_path))
    print("  keeping: " + ", ".join(selected))
    if dry_run:
        return

    body_node = extractor.strip_body_mesh(doc, selected)
    compact_doc, compact_binary = extractor.compact(doc, binary, body_node)
    assembler.validate_morph_targets(compact_doc)
    kept_names = {
        primitive_material_name(compact_doc, primitive)
        for primitive in compact_doc["meshes"][0]["primitives"]
    }
    if not kept_names or any(is_body_material(name) for name in kept_names):
        raise ValueError("%s: extracted output still contains body materials: %s" % (source_path, kept_names))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    assembler.write(output_path, compact_doc, compact_binary)
    check, _ = assembler.read(output_path)
    if len(check.get("meshes", [])) != 1 or not check["meshes"][0].get("primitives"):
        raise ValueError("%s: output is not one non-empty skinned garment mesh" % output_path)
    print("  wrote %s bytes (%d primitives)" % (
        output_path.stat().st_size, len(check["meshes"][0]["primitives"])
    ))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        default="build/local-cache/ara/generated",
        help="directory containing the existing generated Ara GLBs",
    )
    parser.add_argument(
        "--output-dir",
        default="art/characters/ara_runtime/garments",
        help="runtime destination for extracted standalone garments",
    )
    parser.add_argument(
        "--only",
        nargs="*",
        choices=sorted(ASSETS),
        help="optional subset; defaults to the nine selected garments",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="inspect source materials and report planned outputs without writing files",
    )
    args = parser.parse_args()

    source_dir = Path(args.source_dir)
    output_dir = Path(args.output_dir)
    selected_ids = args.only if args.only else list(ASSETS)
    failures = []
    for garment_id in selected_ids:
        source_path = source_dir / ASSETS[garment_id]
        output_path = output_dir / ("female_%s.glb" % garment_id)
        if not source_path.is_file():
            failures.append("Missing existing source: %s" % source_path)
            continue
        try:
            extract_one(source_path, output_path, args.dry_run)
        except Exception as exc:
            failures.append("%s: %s" % (garment_id, exc))

    if failures:
        for failure in failures:
            print("ERROR: " + failure, file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
