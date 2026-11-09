#!/usr/bin/env python3
"""Build a shared library of independently skinned Ara garment objects.

The female anatomy-integrated Ara body supplies the canonical skeleton. Garment
geometry is extracted from the existing Hollowmere character exports first,
then the modular Ara exports fill generic items not represented by an NPC.
Every output mesh is retargeted to the canonical skeleton and named
Garment__<garment_visual>__<body_variant>__<piece>, which Godot uses as the inventory binding.
Run locally through build_ara_runtime_local.py; this requires Blender.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import bpy
from mathutils import Matrix


MATERIAL_TO_ITEMS = {
    "fatigue shirt": ("fatigue_shirt",),
    "woven tunic": ("long_tunic",),
    "long tunic": ("long_tunic",),
    "tunic": ("tunic",),
    "uniform shirt": ("uniform_shirt",),
    "tattered shirt": ("tattered_shirt",),
    "fatigue pants": ("fatigue_pants",),
    "trousers": ("trousers",),
    "wrapper": ("wrapper_long", "wrapper_knee"),
    "bra": ("bra",),
    "briefs": ("briefs",),
    "shoes": ("combat_boots",),
    "boot shafts": ("combat_boots",),
    "sandal soles": ("sandals",),
    "sandal straps": ("sandals",),
    "tank top": ("tank_top",),
    "backless slit dress": ("backless_slit_dress",),
    "pencil skirt": ("pencil_skirt",),
    "leather armor": ("leather_armor",),
    "halter lace bra cups": ("bra",),
    "halter lace bra piping": ("bra",),
    "halter lace bra straps": ("bra",),
    "halter fishnet bra cups": ("bra",),
    "halter fishnet bra straps": ("bra",),
    "triangle bikini top": ("bra",),
    "triangle bikini strings": ("bra",),
    "string bikini bottom": ("briefs",),
    "string bikini strings": ("briefs",),
    "lace briefs": ("briefs",),
    "lace briefs ties": ("briefs",),
    "fishnet briefs": ("briefs",),
    "fishnet briefs ties": ("briefs",),
    "lace shirt": ("fatigue_shirt",),
    "fishnet shirt": ("fatigue_shirt",),
    "lace pants": ("fatigue_pants",),
    "fishnet pants": ("fatigue_pants",),
}


def log(message: str) -> None:
    print(f"[Ara garment library] {message}", flush=True)


def material_key(name: str) -> str:
    value = name.strip().lower()
    value = re.sub(r"\.\d{3}$", "", value)
    value = re.sub(r"[_-]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def import_glb(path: Path) -> tuple[list[bpy.types.Object], bpy.types.Object]:
    if not path.is_file():
        raise FileNotFoundError(path)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = list(set(bpy.data.objects) - before)
    armatures = [obj for obj in imported if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"{path.name}: expected one armature, found {len(armatures)}")
    return imported, armatures[0]


def split_materials(mesh: bpy.types.Object) -> list[bpy.types.Object]:
    """Return mesh pieces split by material, preserving their armature modifiers."""
    if mesh.type != "MESH" or not mesh.data.polygons:
        return []
    before = set(bpy.data.objects)
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    created = [obj for obj in set(bpy.data.objects) - before if obj.type == "MESH"]
    return [mesh] + created


def used_material_names(obj: bpy.types.Object) -> list[str]:
    indices = {poly.material_index for poly in obj.data.polygons}
    names = []
    for index in sorted(indices):
        if index < len(obj.material_slots):
            material = obj.material_slots[index].material
            if material is not None and material.name not in names:
                names.append(material.name)
    return names


def choose_item(material_name: str, expected: set[str] | None) -> str:
    candidates = MATERIAL_TO_ITEMS.get(material_key(material_name), ())
    for item_id in candidates:
        if expected is None or item_id in expected:
            return item_id
    return ""


def expected_from_profile(profile: dict) -> set[str]:
    params = profile.get("params", {})
    return {
        str(params.get(key, ""))
        for key in ("top", "underTop", "underBottom", "bottom", "shoes", "jacket", "hat")
        if str(params.get(key, "")) not in ("", "none")
    }


def validate_rig(source: bpy.types.Object, target: bpy.types.Object, path: Path) -> None:
    source_names = [bone.name for bone in source.data.bones]
    target_names = [bone.name for bone in target.data.bones]
    if source_names != target_names:
        raise RuntimeError(f"{path.name}: Ara skeleton bone names/order differ from canonical base")


def attach_piece(
    obj: bpy.types.Object,
    source_armature: bpy.types.Object,
    target_armature: bpy.types.Object,
    item_id: str,
    variant: str,
    piece_index: int,
) -> None:
    local_transform = source_armature.matrix_world.inverted_safe() @ obj.matrix_world
    armature_modifiers = [modifier for modifier in obj.modifiers if modifier.type == "ARMATURE"]
    if not armature_modifiers:
        armature_modifiers = [obj.modifiers.new(name="AraArmature", type="ARMATURE")]
    for modifier in armature_modifiers:
        modifier.object = target_armature
    obj.parent = target_armature
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_world = target_armature.matrix_world @ local_transform
    safe_piece = re.sub(r"[^A-Za-z0-9_]+", "_", obj.name).strip("_") or "piece"
    obj.name = f"Garment__{item_id}__{variant}__{safe_piece}_{piece_index:02d}"
    obj["garment_visual"] = item_id
    obj["body_variant"] = variant


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-body", type=Path, required=True)
    parser.add_argument("--modular", type=Path, required=True)
    parser.add_argument("--underwear", type=Path, required=True)
    parser.add_argument("--armor", type=Path, required=True)
    parser.add_argument("--wrapper-knee", type=Path, required=True)
    parser.add_argument("--npc-manifest", type=Path, required=True)
    parser.add_argument("--npc-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    bpy.ops.wm.read_factory_settings(use_empty=True)
    base_objects, target_armature = import_glb(args.base_body)
    for obj in base_objects:
        if obj != target_armature:
            bpy.data.objects.remove(obj, do_unlink=True)
    target_armature.name = "Ara_Garment_Skeleton"
    target_armature.parent = None

    manifest = json.loads(args.npc_manifest.read_text(encoding="utf-8"))
    profiles = manifest.get("characters", [])
    expected_by_variant: dict[str, set[str]] = {"female": set(), "male": set()}
    for profile in profiles:
        params = profile.get("params", {})
        variant = "male" if int(params.get("gender", 0)) == 1 else "female"
        expected_by_variant[variant].update(expected_from_profile(profile))

    seen: set[str] = set()
    piece_counts: dict[str, int] = {}
    kept: list[bpy.types.Object] = []

    def process_source(path: Path, expected: set[str] | None, variant: str, label: str) -> None:
        imported, source_armature = import_glb(path)
        validate_rig(source_armature, target_armature, path)
        pieces: list[bpy.types.Object] = []
        for obj in [value for value in imported if value.type == "MESH"]:
            pieces.extend(split_materials(obj))
        selected: dict[str, list[bpy.types.Object]] = {}
        for obj in pieces:
            names = used_material_names(obj)
            if len(names) != 1:
                continue
            item_id = choose_item(names[0], expected)
            item_key = f"{item_id}:{variant}"
            if not item_id or item_key in seen:
                continue
            selected.setdefault(item_id, []).append(obj)

        for item_id, objects in selected.items():
            item_key = f"{item_id}:{variant}"
            for obj in objects:
                piece_key = f"{item_key}"
                piece_counts[piece_key] = piece_counts.get(piece_key, 0) + 1
                attach_piece(obj, source_armature, target_armature, item_id, variant, piece_counts[piece_key])
                kept.append(obj)
            seen.add(item_key)
            log(f"{label}: extracted {item_id} ({len(objects)} mesh piece(s))")

        for obj in list(set(imported) | set(pieces)):
            if obj not in kept and obj.name in bpy.data.objects:
                bpy.data.objects.remove(obj, do_unlink=True)

    # Prefer the actual NPC garment geometry and its material assignment. The
    # profile restricts extraction to the clothing item that person wears.
    for profile in profiles:
        character_id = str(profile.get("id", ""))
        if not character_id:
            continue
        source = args.npc_dir / f"{character_id}.glb"
        if source.is_file():
            variant = "male" if int(profile.get("params", {}).get("gender", 0)) == 1 else "female"
            process_source(source, expected_from_profile(profile), variant, character_id)

    # Fill generic underwear, Workshop-only garments and armour not worn by an NPC.
    process_source(args.modular, None, "any", "Ara modular")
    process_source(args.underwear, None, "any", "Ara underwear")
    process_source(args.armor, None, "any", "Ara armour")
    process_source(args.wrapper_knee, {"wrapper_knee"}, "any", "Ara knee wrapper")

    missing = sorted(
        f"{variant}:{item_id}"
        for variant, item_ids in expected_by_variant.items()
        for item_id in item_ids
        if f"{item_id}:{variant}" not in seen and f"{item_id}:any" not in seen
    )
    if missing:
        raise RuntimeError("No independent garment geometry found for NPC inventory item(s): " + ", ".join(missing))
    if not kept:
        raise RuntimeError("No garment objects were extracted")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    target_armature.select_set(True)
    for obj in kept:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = target_armature
    bpy.ops.export_scene.gltf(
        filepath=str(args.output),
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_animations=False,
        export_apply=False,
    )
    log(f"Wrote {args.output} with {len(kept)} independent garment mesh object(s)")
    log("Inventory visuals available: " + ", ".join(sorted(seen)))


if __name__ == "__main__":
    main()
