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
import sys
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
    "combat boots": ("combat_boots",),
    "combat boot": ("combat_boots",),
    "sandals": ("sandals",),
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
    source_bones = list(source.data.bones)
    target_bones = list(target.data.bones)
    source_names = [bone.name for bone in source_bones]
    target_names = [bone.name for bone in target_bones]
    if source_names != target_names:
        missing = sorted(set(target_names) - set(source_names))
        extra = sorted(set(source_names) - set(target_names))
        raise RuntimeError(
            f"{path.name}: Ara skeleton bone names/order differ from canonical base; "
            f"missing={missing[:12]}, extra={extra[:12]}, "
            f"source_count={len(source_names)}, target_count={len(target_names)}"
        )

    armature_delta = max(
        abs(source.matrix_world[row][column] - target.matrix_world[row][column])
        for row in range(4) for column in range(4)
    )
    if armature_delta > 1e-4:
        raise RuntimeError(
            f"{path.name}: armature object transform differs from the target body "
            f"(maximum matrix delta {armature_delta:.7g})"
        )

    differences = []
    for source_bone, target_bone in zip(source_bones, target_bones):
        source_matrix = source_bone.matrix_local
        target_matrix = target_bone.matrix_local
        max_element_delta = max(
            abs(source_matrix[row][column] - target_matrix[row][column])
            for row in range(4) for column in range(4)
        )
        if max_element_delta <= 1e-4:
            continue
        source_rotation = source_matrix.to_3x3().to_quaternion()
        target_rotation = target_matrix.to_3x3().to_quaternion()
        rotation_delta = source_rotation.rotation_difference(target_rotation).angle
        translation_delta = source_matrix.translation - target_matrix.translation
        differences.append({
            "bone": source_bone.name,
            "max_matrix_element_delta": max_element_delta,
            "translation_delta": [round(value, 7) for value in translation_delta],
            "translation_distance": translation_delta.length,
            "rotation_delta_degrees": rotation_delta * 57.295779513,
            "source_matrix": [[round(value, 7) for value in row] for row in source_matrix],
            "target_matrix": [[round(value, 7) for value in row] for row in target_matrix],
        })

    if differences:
        differences.sort(key=lambda item: item["max_matrix_element_delta"], reverse=True)
        log(f"{path.name}: {len(differences)} bone rest transforms differ from the target Ara body rig")
        log(
            f"{path.name}: armature object transform delta="
            f"{max(abs(source.matrix_world[r][c] - target.matrix_world[r][c]) for r in range(4) for c in range(4)):.7g}"
        )
        for item in differences[:20]:
            log(
                f"{path.name}: bone={item['bone']} "
                f"matrix_delta={item['max_matrix_element_delta']:.7g} "
                f"translation={item['translation_delta']} "
                f"translation_distance={item['translation_distance']:.7g} "
                f"rotation_delta={item['rotation_delta_degrees']:.5f}deg"
            )
            log(f"{path.name}:   source_matrix={item['source_matrix']}")
            log(f"{path.name}:   target_matrix={item['target_matrix']}")
        raise RuntimeError(
            f"{path.name}: rest transforms differ for {len(differences)} bone(s); "
            "refusing unsafe garment retarget. Full per-bone matrices are logged above "
            "for the 20 largest differences."
        )


def validate_mesh_skinning(obj: bpy.types.Object, source_armature: bpy.types.Object, path: Path) -> dict:
    if obj.type != "MESH" or not obj.data.vertices:
        raise RuntimeError(f"{path.name}/{obj.name}: garment mesh has no vertices")
    modifiers = [m for m in obj.modifiers if m.type == "ARMATURE"]
    if not modifiers or not any(m.object == source_armature for m in modifiers):
        raise RuntimeError(f"{path.name}/{obj.name}: no Armature modifier bound to its imported skeleton")
    bone_names = {bone.name for bone in source_armature.data.bones}
    group_names = {group.name for group in obj.vertex_groups}
    unknown = sorted(group_names - bone_names)
    if unknown:
        raise RuntimeError(f"{path.name}/{obj.name}: vertex groups do not match skeleton bones: {unknown[:8]}")
    if not group_names:
        raise RuntimeError(f"{path.name}/{obj.name}: garment has no skin-weight vertex groups")
    weighted_vertices = 0
    total_weighted = 0.0
    for vertex in obj.data.vertices:
        weight = sum(entry.weight for entry in vertex.groups)
        if weight > 1e-6:
            weighted_vertices += 1
            total_weighted += weight
    coverage = weighted_vertices / len(obj.data.vertices)
    if coverage < 0.95:
        raise RuntimeError(
            f"{path.name}/{obj.name}: only {coverage:.1%} of vertices have skin weights; "
            "refusing to export a rigid or partially unskinned garment"
        )
    return {
        "vertices": len(obj.data.vertices),
        "weighted_vertices": weighted_vertices,
        "weight_coverage": round(coverage, 5),
        "mean_vertex_weight_sum": round(total_weighted / max(weighted_vertices, 1), 5),
        "vertex_groups": len(group_names),
    }


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
    parser.add_argument("--profile-source", type=Path, required=True, help="Ara export generated from the same profile and rig settings as the bare body")
    parser.add_argument("--npc-manifest", type=Path, required=True)
    parser.add_argument("--profile-id", default="wren_talbot", help="NPC profile whose required inventory visuals this pilot build must satisfy")
    parser.add_argument("--output", type=Path, required=True)
    # Blender processes its own CLI options; pass only arguments after `--`
    # to argparse. Calling parse_args() directly sees Blender's argv instead.
    blender_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = parser.parse_args(blender_args)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    base_objects, target_armature = import_glb(args.base_body)
    for obj in base_objects:
        if obj != target_armature:
            bpy.data.objects.remove(obj, do_unlink=True)
    target_armature.name = "Ara_Garment_Skeleton"
    target_armature.parent = None

    manifest = json.loads(args.npc_manifest.read_text(encoding="utf-8"))
    profiles = manifest.get("characters", [])
    if args.profile_id:
        profiles = [profile for profile in profiles if str(profile.get("id", "")) == args.profile_id]
    if not profiles:
        raise RuntimeError(f"No NPC appearance profile found for pilot id {args.profile_id!r}")
    expected_by_variant: dict[str, set[str]] = {"female": set(), "male": set()}
    for profile in profiles:
        params = profile.get("params", {})
        variant = "male" if int(params.get("gender", 0)) == 1 else "female"
        expected_by_variant[variant].update(expected_from_profile(profile))

    seen: set[str] = set()
    piece_counts: dict[str, int] = {}
    kept: list[bpy.types.Object] = []
    extraction_report: dict[str, dict] = {}

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
            skin_report = validate_mesh_skinning(obj, source_armature, path)
            selected.setdefault(item_id, []).append(obj)
            extraction_report.setdefault(item_key, {
                "source": str(path.name),
                "variant": variant,
                "pieces": [],
            })["pieces"].append({
                "object": obj.name,
                "material": names[0],
                **skin_report,
            })

        for item_id, objects in selected.items():
            item_key = f"{item_id}:{variant}"
            for obj in objects:
                piece_counts[item_key] = piece_counts.get(item_key, 0) + 1
                attach_piece(obj, source_armature, target_armature, item_id, variant, piece_counts[item_key])
                kept.append(obj)
            seen.add(item_key)
            log(f"{label}: extracted {item_id} ({len(objects)} independently skinned piece(s))")

        for obj in list(set(imported) | set(pieces)):
            if obj not in kept and obj.name in bpy.data.objects:
                bpy.data.objects.remove(obj, do_unlink=True)

    # Use a second Ara export generated from the exact same body parameters,
    # rig and rest-pose settings as the bare character body. This ensures the
    # garment weights and profile-specific rest transforms match the target.
    variant = "male" if int(profiles[0].get("params", {}).get("gender", 0)) == 1 else "female"
    process_source(args.profile_source, expected_by_variant[variant], variant, "Ara profile export")

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
    report_path = args.output.with_suffix(".report.json")
    report = {
        "schema_version": 3,
        "output": str(args.output),
        "mesh_object_count": len(kept),
        "available_visual_variants": sorted(seen),
        "extractions": extraction_report,
        "profile_scope": args.profile_id,
        "source_policy": "Same-profile Ara export only; legacy NPC GLBs are not imported",
        "validation": {
            "skeleton_bone_names_and_order": "passed",
            "skeleton_rest_transforms": "passed",
            "armature_modifiers": "passed for every extracted piece",
            "vertex_groups": "matched to skeleton bones",
            "skin_weight_coverage_minimum": 0.95,
        },
    }
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    log(f"Wrote {args.output} with {len(kept)} independently skinned garment mesh object(s)")
    log("Inventory visuals available: " + ", ".join(sorted(seen)))
    log(f"Validation report: {report_path}")


if __name__ == "__main__":
    main()
