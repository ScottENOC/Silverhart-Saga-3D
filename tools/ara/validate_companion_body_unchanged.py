#!/usr/bin/env python3
"""Assert modular assembly/fitting has not changed the companion's body mesh."""
import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import assemble_modular_glb as glb

# The fitting gate compares the actual skin/anatomy surfaces. Hair, brows,
# eyes and other facial detail primitives are cosmetic assets and may be
# reindexed by Blender's glTF round-trip; the fitting code never selects them.
BODY_MATERIALS = {"skin", "skin details"}

def normalise(name):
    return str(name or "").strip().lower().replace("_", " ").replace(".001", "").replace(".002", "")

def rounded(row):
    return tuple(round(float(x), 5) for x in row)

def primitive_signature(doc, binary, primitive, target_names, joint_names):
    attrs = primitive.get("attributes", {})
    if "POSITION" not in attrs:
        raise ValueError("Body primitive has no POSITION accessor")
    positions = glb.accessor_rows(doc, binary, attrs["POSITION"])
    joints = glb.accessor_rows(doc, binary, attrs["JOINTS_0"]) if "JOINTS_0" in attrs else [()] * len(positions)
    weights = glb.accessor_rows(doc, binary, attrs["WEIGHTS_0"]) if "WEIGHTS_0" in attrs else [()] * len(positions)
    if not (len(positions) == len(joints) == len(weights)):
        raise ValueError("Body vertex attribute counts differ")
    if any(int(index) >= len(joint_names) for row in joints for index in row):
        raise ValueError("Body vertex references an invalid joint index")
    base = [
        (rounded(p), tuple(sorted((joint_names[int(index)], round(float(weight), 5)) for index, weight in zip(j, w))))
        for p, j, w in zip(positions, joints, weights)
    ]
    # Compare unique vertex attributes rather than raw vertex order/count:
    # Blender's glTF round-trip may split identical vertices at UV/material seams.
    base_set = tuple(sorted(set(base)))

    # Compare the actual triangle surface as well, using coordinates rather
    # than indices so harmless vertex reindexing does not look like a body edit.
    triangle_set = ()
    if "indices" in primitive and primitive.get("mode", 4) == 4:
        indices = [int(row[0]) for row in glb.accessor_rows(doc, binary, primitive["indices"])]
        if len(indices) % 3:
            raise ValueError("Body triangle index count is not divisible by three")
        triangles = []
        for offset in range(0, len(indices), 3):
            triangles.append(tuple(sorted(rounded(positions[i]) for i in indices[offset:offset + 3])))
        triangle_set = tuple(sorted(set(triangles)))

    targets = primitive.get("targets", [])
    if len(targets) != len(target_names):
        raise ValueError(f"Body morph target count differs: {len(targets)} vs {len(target_names)}")
    morph = {}
    for index, name in enumerate(target_names):
        target = targets[index]
        if "POSITION" not in target:
            delta = [(0.0, 0.0, 0.0)] * len(positions)
        else:
            delta = [rounded(x) for x in glb.accessor_rows(doc, binary, target["POSITION"])]
        morph[name] = tuple(sorted(set((base_row, d) for base_row, d in zip(base, delta))))
    return base_set, triangle_set, morph

def body_signature(path):
    doc, binary = glb.read(path)
    node = glb.body_node(doc)
    mesh = doc["meshes"][node["mesh"]]
    joint_names = [doc["nodes"][i].get("name", f"joint_{i}") for i in doc["skins"][0]["joints"]]
    names = mesh.get("extras", {}).get("targetNames", [])
    result = {}
    for primitive in mesh.get("primitives", []):
        mi = primitive.get("material")
        if mi is None:
            continue
        material = doc["materials"][mi].get("name", "")
        key = normalise(material)
        if key not in BODY_MATERIALS and not key.startswith("skin "):
            continue
        if key in result:
            raise ValueError(f"Duplicate body material primitive in {path}: {material}")
        result[key] = primitive_signature(doc, binary, primitive, names, joint_names)
    if "skin" not in result and not any(k.startswith("skin ") for k in result):
        raise ValueError(f"No skin primitive found in {path}")
    return result, set(joint_names)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original", type=Path)
    parser.add_argument("modular", type=Path)
    args = parser.parse_args()
    before, joints_before = body_signature(args.original)
    after, joints_after = body_signature(args.modular)
    if joints_before != joints_after:
        raise SystemExit("Body armature joint list changed during garment assembly/fitting")
    if set(before) != set(after):
        raise SystemExit(f"Body material primitives changed: before={sorted(before)} after={sorted(after)}")
    for material in sorted(before):
        if before[material] != after[material]:
            raise SystemExit(f"Approved body geometry/rig/morph data changed in material {material}")
    print(f"PASS: body geometry, skinning and morph targets unchanged for {args.original.name}")
    print(f"      checked {len(before)} body materials and {len(joints_before)} armature joints")

if __name__ == "__main__":
    main()
