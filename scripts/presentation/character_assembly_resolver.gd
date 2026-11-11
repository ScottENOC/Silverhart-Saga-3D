class_name CharacterAssemblyResolver
extends RefCounted
## Resolves player and NPC inputs into one runtime character specification.
## Canonical NPC definitions use appearance/inventory/equipped; the player
## creator's saved profile is adapted into the same resolved shape.

const ITEM_CATALOG = preload("res://scripts/simulation/item_catalog.gd")
const PLAYER_FEMALE_ASSET := "res://art/characters/ara_runtime/ara_person_body.glb"
const PLAYER_MALE_ASSET := "res://art/characters/ara_runtime/ara_person_male_body.glb"

static func resolve_npc(definition: Dictionary) -> Dictionary:
    var appearance_value: Variant = definition.get("appearance", {})
    var inventory_value: Variant = definition.get("inventory", [])
    var equipped_value: Variant = definition.get("equipped", {})
    if not appearance_value is Dictionary or not inventory_value is Array or not equipped_value is Dictionary:
        push_error("Character '%s' has an invalid canonical appearance/inventory/equipped definition." % String(definition.get("id", "")))
        return {}

    var appearance: Dictionary = appearance_value.duplicate(true)
    var gender := float(appearance.get("gender", 0.0))
    var resolved := {
        "profile_id": String(definition.get("id", "")),
        "game_id": String(definition.get("game_id", definition.get("id", ""))),
        "display_name": String(definition.get("name", definition.get("id", "Unknown"))),
        "body_variant": "male" if gender >= 0.5 else "female",
        "body_profile": String(definition.get("body_profile", ("male_" if gender >= 0.5 else "female_") + "average")),
        "appearance": appearance,
        "player_profile": {},
        "hair_style_id": String(appearance.get("hair", "none")),
        "hair_tint": String(appearance.get("hairTint", appearance.get("hairColor", "#49372a"))),
        "garment_styles": appearance.get("garmentStyles", {}).duplicate(true),
        "inventory_ids": inventory_value.duplicate(),
        "equipped_ids": equipped_value.duplicate(true),
        "is_player": false
    }
    resolved.merge(_resolve_body_asset(resolved), true)
    return resolved


static func resolve_player(profile: Dictionary) -> Dictionary:
    var body_variant := String(profile.get("body_variant", "female")).to_lower()
    if body_variant not in ["male", "female"]:
        body_variant = "female"
    var hair_id := String(profile.get("hair_style_id", "short02"))
    var player_visual_profile := profile.duplicate(true)
    player_visual_profile["body_variant"] = body_variant
    var ara_appearance := {
        "gender": 1 if body_variant == "male" else 0,
        "muscle": float(profile.get("muscle", 0.5)),
        "weight": float(profile.get("weight", 0.5)),
        "height": float(profile.get("height", 0.5)),
        "proportions": float(profile.get("proportions", 0.5)),
        "eyes": _player_eye_id(String(profile.get("eye_colour", "Brown"))),
        "hair": hair_id,
        "hairTint": _player_hair_colour(String(profile.get("hair_colour", "Dark brown"))),
        "african": 0.0,
        "asian": 0.0,
        "caucasian": 1.0,
        "garmentStyles": {}
    }
    var resolved := {
        "profile_id": "player",
        "game_id": "player",
        "display_name": String(profile.get("name", "Adventurer")),
        "body_variant": body_variant,
        "appearance": ara_appearance,
        "player_profile": player_visual_profile,
        "hair_style_id": hair_id,
        "hair_tint": String(ara_appearance["hairTint"]),
        "garment_styles": {},
        "inventory_ids": [],
        "equipped_ids": {},
        "is_player": true
    }
    resolved.merge(_resolve_body_asset(resolved), true)
    return resolved


static func _resolve_body_asset(resolved: Dictionary) -> Dictionary:
    var body_variant := String(resolved.get("body_variant", "female"))
    if not bool(resolved.get("is_player", false)):
        var profile_id := String(resolved.get("profile_id", ""))
        var profile_body_path := "res://art/characters/ara_runtime/bodies/%s.glb" % profile_id
        if not profile_id.is_empty() and ResourceLoader.exists(profile_body_path):
            return {"body_asset_path": profile_body_path, "legacy_visual_fallback": false}
        for legacy_id in [profile_id, String(resolved.get("game_id", ""))]:
            if legacy_id.is_empty():
                continue
            var legacy_path := "res://art/characters/hollowmere/%s.glb" % legacy_id
            if ResourceLoader.exists(legacy_path):
                return {"body_asset_path": legacy_path, "legacy_visual_fallback": true}
    return {
        "body_asset_path": PLAYER_MALE_ASSET if body_variant == "male" else PLAYER_FEMALE_ASSET,
        "legacy_visual_fallback": false
    }


static func populate_npc_inventory(state: CharacterState, resolved: Dictionary) -> bool:
    var instances_by_item: Dictionary = {}
    var inventory_ids: Array = resolved.get("inventory_ids", [])
    for item_variant in inventory_ids:
        var item_id := String(item_variant)
        var instance_id := "canonical_%s_%s" % [state.id, item_id]
        var item := ITEM_CATALOG.create_instance(item_id, instance_id)
        if item.is_empty():
            push_error("Canonical character '%s' references unknown inventory item '%s'." % [state.id, item_id])
            return false
        if not state.add_inventory_item(item):
            push_error("Could not add canonical inventory item '%s' to '%s'." % [item_id, state.id])
            return false
        instances_by_item[item_id] = instance_id

    var equipped_ids: Dictionary = resolved.get("equipped_ids", {})
    for slot_variant in equipped_ids:
        var slot := String(slot_variant)
        var item_id := String(equipped_ids[slot_variant])
        if not instances_by_item.has(item_id):
            push_error("Canonical character '%s' equips '%s' in '%s' but does not own it." % [state.id, item_id, slot])
            return false
        var definition := ITEM_CATALOG.get_definition(item_id)
        if String(definition.get("equipment_slot", "")) != slot:
            push_error("Canonical character '%s' equips '%s' in incompatible slot '%s'." % [state.id, item_id, slot])
            return false
        if not state.equip_inventory_item(String(instances_by_item[item_id])):
            push_error("Could not equip canonical item '%s' in slot '%s' for '%s'." % [item_id, slot, state.id])
            return false
    return true


static func _player_eye_id(value: String) -> String:
    match value:
        "Light brown": return "brownlight"
        "Dark brown": return "darkbrown"
        "Brown": return "brown"
        "Green": return "green"
        "Blue": return "blue"
        "Grey": return "grey"
        "Ice blue": return "blue"
        _: return "brown"


static func _player_hair_colour(value: String) -> String:
    var colours := {
        "Black": "#171513", "Dark brown": "#49372a", "Chestnut": "#75452d",
        "Blonde": "#c6a45e", "Red": "#9a422e", "Silver": "#aaa9a3",
        "White": "#e4dfd2", "Blue": "#354d91", "Green": "#426b49"
    }
    return String(colours.get(value, "#49372a"))
