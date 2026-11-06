import importlib.util
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "ara" / "assemble_modular_glb.py"
SPEC = importlib.util.spec_from_file_location("assemble_modular_glb", SCRIPT)
ASSEMBLER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ASSEMBLER)


def make_glb(path, source=False):
    binary = bytearray()
    views = []
    accessors = []

    def accessor(values, component_type, value_type, target):
        formats = {5123: "H", 5126: "f"}
        fmt = formats[component_type]
        binary.extend(b"\0" * (-len(binary) % 4))
        offset = len(binary)
        packed = struct.pack("<" + fmt * len(values), *values)
        binary.extend(packed)
        view_index = len(views)
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(packed), "target": target})
        count = len(values) // {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[value_type]
        index = len(accessors)
        accessors.append({
            "bufferView": view_index,
            "componentType": component_type,
            "count": count,
            "type": value_type,
        })
        return index

    position = accessor([0, 0, 0, 1, 0, 0, 0, 1, 0], 5126, "VEC3", 34962)
    joints = accessor([0, 0, 0, 0] * 3, 5123, "VEC4", 34962)
    weights = accessor([1, 0, 0, 0] * 3, 5126, "VEC4", 34962)
    indices = accessor([0, 1, 2], 5123, "SCALAR", 34963)
    targets = []
    for delta in (0.1, 0.2):
        pos = accessor([delta, 0, 0] * 3, 5126, "VEC3", 34962)
        normal = accessor([0, delta, 0] * 3, 5126, "VEC3", 34962)
        targets.append({"POSITION": pos, "NORMAL": normal})

    materials = [{"name": "Skin"}]
    primitives = [{
        "attributes": {
            "POSITION": position,
            "JOINTS_0": joints,
            "WEIGHTS_0": weights,
        },
        "indices": indices,
        "material": 0,
        "targets": targets,
    }]
    if source:
        materials.append({"name": "Garment"})
        primitives.append({
            "attributes": {
                "POSITION": position,
                "JOINTS_0": joints,
                "WEIGHTS_0": weights,
            },
            "indices": indices,
            "material": 1,
            "targets": targets,
        })

    doc = {
        "asset": {"version": "2.0"},
        "scene": 0,
        "scenes": [{"nodes": [0, 1]}],
        "nodes": [{"name": "BodyMesh", "mesh": 0, "skin": 0}, {"name": "Hips"}],
        "skins": [{"joints": [1]}],
        "meshes": [{
            "name": "Fixture",
            "weights": [0, 0],
            "extras": {"targetNames": ["smile", "blink"]},
            "primitives": primitives,
        }],
        "materials": materials,
        "textures": [],
        "images": [],
        "samplers": [],
        "bufferViews": views,
        "accessors": accessors,
        "buffers": [{"byteLength": len(binary)}],
    }
    encoded = json.dumps(doc, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    binary.extend(b"\0" * (-len(binary) % 4))
    total = 12 + 8 + len(encoded) + 8 + len(binary)
    glb = (
        struct.pack("<4sII", b"glTF", 2, total)
        + struct.pack("<I4s", len(encoded), b"JSON") + encoded
        + struct.pack("<I4s", len(binary), b"BIN\0") + binary
    )
    path.write_bytes(glb)


class ModularGlbMorphTargetTests(unittest.TestCase):
    def test_garment_morph_accessors_are_remapped_into_destination(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            target_path = tmp / "body.glb"
            source_path = tmp / "source.glb"
            output_path = tmp / "modular.glb"
            make_glb(target_path, source=False)
            make_glb(source_path, source=True)

            target, target_binary = ASSEMBLER.read(target_path)
            source, _ = ASSEMBLER.read(source_path)
            destination_accessor_count = len(target["accessors"])
            target, target_binary = ASSEMBLER.add(
                target, target_binary, str(source_path), "Garment"
            )

            garment = target["meshes"][0]["primitives"][-1]
            self.assertEqual(len(garment["targets"]), 2)
            for morph_target in garment["targets"]:
                for semantic, accessor_index in morph_target.items():
                    self.assertGreaterEqual(accessor_index, destination_accessor_count)
                    accessor = target["accessors"][accessor_index]
                    self.assertEqual(accessor["type"], "VEC3")
                    self.assertEqual(accessor["count"], 3)

            ASSEMBLER.validate_morph_targets(target)
            ASSEMBLER.write(output_path, target, target_binary)
            round_trip, _ = ASSEMBLER.read(output_path)
            ASSEMBLER.validate_morph_targets(round_trip)

    def test_rejects_incompatible_morph_target_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            target_path = tmp / "body.glb"
            source_path = tmp / "source.glb"
            make_glb(target_path, source=False)
            make_glb(source_path, source=True)
            target, target_binary = ASSEMBLER.read(target_path)
            source, _ = ASSEMBLER.read(source_path)
            source["meshes"][0]["extras"]["targetNames"] = ["different", "blink"]
            ASSEMBLER.write(source_path, source, _)
            with self.assertRaisesRegex(ValueError, "Morph target names differ"):
                ASSEMBLER.add(target, target_binary, str(source_path), "Garment")


if __name__ == "__main__":
    unittest.main()
