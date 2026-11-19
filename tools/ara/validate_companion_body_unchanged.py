#!/usr/bin/env python3
"""Assert modular assembly/fitting has not changed the companion's body mesh."""
import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import assemble_modular_glb as glb

BODY_MATERIALS = {
    "skin", "mouth", "skin details", "eyes", "eyebrows",
    "eyelashes", "teeth", "tongue", "hair",
}

def normalise(name):
    return str(name or "").strip().lower().replace(".001", "").replace(".002", "")

def rounded(row):
    return tuple(round(float(x), 6) for x in row)

def primitive_signature(doc, binary, primitive, target_names):
    attrs = primitive.get("attributes", {})
    if "POSITION" not in attrs:
        raise ValueError("Body primitive has no POSITION accessor")
    positions = glb.accessor_rows(doc, binary, attrs["POSITION"])
    joints = glb.accessor_rows(doc, binary, attrs["JOINTS_0"]) if "JOINTS_0" in attrs else [()] * len(positions)
    weights = glb.accessor_rows(doc, binary, attrs["WEIGHTS_0"]) if "WEIGHTS_0" in attrs else [()] * len(positions)
    if not (len(positions) == len(joints) == len(weights)):
        raise ValueError("Body vertex attribute counts differ")
    base = [(rounded(p), tuple(int(x) for x in j), rounded(w)) for p, j, w in zip(positions, joints, weights)]
    base_sorted = tuple(sorted(base))

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
        morph[name] = tuple(sorted((rounded(p), d) for p, d in zip(positions, delta)))
    return len(positions), base_sorted, morph

def body_signature(path):
    doc, binary = glb.read(path)
    node = glb.body_node(doc)
    mesh = doc["meshes"][node["mesh"]]
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
        result[key] = primitive_signature(doc, binary, primitive, names)
    if "skin" not in result and not any(k.startswith("skin ") for k in result):
        raise ValueError(f"No skin primitive found in {path}")
    return result, [doc["nodes"][i].get("name") for i in doc["skins"][0]["joints"]]

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
