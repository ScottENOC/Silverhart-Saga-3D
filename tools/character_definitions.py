#!/usr/bin/env python3
"""Canonical character-definition helpers shared by all asset generators."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ITEM_CATALOG_PATH = ROOT / "data" / "items" / "item_definitions.json"
# Modest average male body-shape defaults. These are ordinary Ara detail
# sliders, not hard-coded mesh deformation. A character's own modifiers override
# individual values, so male NPCs still retain distinct physiques.
DEFAULT_MALE_BODY_MODIFIERS = {
    "torso/torso-vshape": 0.20,
    "torso/torso-muscle-dorsi": 0.12,
    "armslegs/upperarm-muscle": 0.12,
    "armslegs/upperarm-scale-horiz": 0.12,
    "armslegs/upperarm-scale-depth": 0.10,
    "armslegs/lowerarm-muscle": 0.08,
}


ARA_SLOT_TO_FIELD = {
    "shirt": "top", "underTop": "underTop", "underBottom": "underBottom",
    "jacket": "jacket", "pants": "bottom", "shoes": "shoes", "helmet": "hat",
}
APPEARANCE_GEAR_FIELDS = {
    "outfit", "top", "underTop", "underBottom", "jacket", "bottom",
    "underwear", "shoes", "hat", "weapon", "carry",
}


def load_item_catalog(path: Path = ITEM_CATALOG_PATH) -> dict:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    items = data.get("items")
    if not isinstance(items, dict):
        raise ValueError(f"Invalid item catalogue: {path}")
    return items


def validate_character_definitions(manifest: dict, items: dict) -> None:
    if int(manifest.get("schema_version", 0)) != 2:
        raise ValueError("Character manifest must use schema_version 2")
    characters = manifest.get("characters")
    if not isinstance(characters, list) or not characters:
        raise ValueError("Character manifest has no characters")
    seen_ids, seen_game_ids = set(), set()
    for character in characters:
        character_id = str(character.get("id", ""))
        game_id = str(character.get("game_id", ""))
        if not character_id or character_id in seen_ids:
            raise ValueError(f"Missing or duplicate character id: {character_id!r}")
        if not game_id or game_id in seen_game_ids:
            raise ValueError(f"{character_id}: missing or duplicate game_id {game_id!r}")
        seen_ids.add(character_id)
        seen_game_ids.add(game_id)
        appearance = character.get("appearance")
        inventory = character.get("inventory")
        equipped = character.get("equipped")
        if not isinstance(appearance, dict):
            raise ValueError(f"{character_id}: appearance must be an object")
        if not isinstance(inventory, list) or not isinstance(equipped, dict):
            raise ValueError(f"{character_id}: inventory must be a list and equipped must be an object")
        duplicated_gear = APPEARANCE_GEAR_FIELDS.intersection(appearance)
        if duplicated_gear:
            raise ValueError(f"{character_id}: equipment duplicated in appearance: {sorted(duplicated_gear)}")
        if any(not isinstance(item_id, str) for item_id in inventory):
            raise ValueError(f"{character_id}: inventory item IDs must be strings")
        if len(inventory) != len(set(inventory)):
            raise ValueError(f"{character_id}: duplicate item IDs in inventory")
        for item_id in inventory:
            if item_id not in items:
                raise ValueError(f"{character_id}: inventory references unknown item {item_id!r}")
        for slot, item_id in equipped.items():
            if item_id not in inventory:
                raise ValueError(f"{character_id}: equipped {slot} item {item_id!r} is not owned")
            definition = items.get(item_id, {})
            actual_slot = definition.get("equipment_slot")
            if not actual_slot:
                raise ValueError(f"{character_id}: equipped item {item_id!r} has no equipment_slot")
            if actual_slot != slot:
                raise ValueError(f"{character_id}: equipped slot {slot!r} does not match {item_id!r} catalogue slot {actual_slot!r}")
        for slot in ARA_SLOT_TO_FIELD:
            item_id = equipped.get(slot)
            if not item_id:
                continue
            allowed_types = ("clothing", "helmet") if slot == "helmet" else ("clothing",)
            if items[item_id].get("type") not in allowed_types:
                raise ValueError(f"{character_id}: Ara slot {slot} requires {allowed_types}, got {item_id}")


def ara_export_params(character: dict, items: dict, *, include_equipped: bool = True,
                      name: str | None = None, detail: str | None = None) -> dict:
    """Derive the Ara export payload from one canonical character definition."""
    params = dict(character.get("appearance", {}))
    if float(params.get("gender", 0.0)) >= 0.5:
        modifiers = dict(DEFAULT_MALE_BODY_MODIFIERS)
        modifiers.update(params.get("modifiers", {}))
        params["modifiers"] = modifiers
    equipped = character.get("equipped", {}) if include_equipped else {}
    for slot, field in ARA_SLOT_TO_FIELD.items():
        item_id = equipped.get(slot, "none")
        if item_id == "none":
            params[field] = "none"
        else:
            definition = items.get(item_id, {})
            params[field] = str(definition.get("ara_garment_id", definition.get("garment_visual", item_id)))
    params.update({
        "name": name or character.get("name", character.get("id", "Ara Character")),
        "outfit": "none", "underwear": False, "weapon": "none", "carry": "none",
        "detail": detail or character.get("detail", "medium"),
        "rig": params.get("rig", "game"), "restPose": params.get("restPose", "A"),
        "animations": params.get("animations", True), "faceBones": params.get("faceBones", True),
        "faceShapes": params.get("faceShapes", True), "speechShapes": params.get("speechShapes", False),
        "expression": params.get("expression", "neutral"),
    })
    return params
