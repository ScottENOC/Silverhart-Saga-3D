extends SceneTree

const RESOLVER = preload("res://scripts/presentation/character_assembly_resolver.gd")

func _initialize() -> void:
    _run()


func _run() -> void:
    var file := FileAccess.open("res://data/characters/hollowmere_npcs.json", FileAccess.READ)
    assert(file != null, "Canonical Hollowmere character manifest must exist")
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    assert(parsed is Dictionary, "Canonical character manifest must parse")
    var profile_file := FileAccess.open("res://data/characters/body_profiles.json", FileAccess.READ)
    assert(profile_file != null, "Canonical ten-profile body catalogue must exist")
    var profile_data: Variant = JSON.parse_string(profile_file.get_as_text())
    assert(profile_data is Dictionary, "Body profile catalogue must parse")
    var profile_ids := {}
    for profile_variant in profile_data.get("body_profiles", []):
        var profile: Dictionary = profile_variant
        profile_ids[String(profile.get("id", ""))] = true
    assert(profile_ids.size() == 10, "Exactly ten canonical body profiles must be defined")
    for build in ["lean", "average", "broad", "muscular", "soft"]:
        assert(profile_ids.has("female_" + build), "Missing female body profile: " + build)
        assert(profile_ids.has("male_" + build), "Missing male body profile: " + build)

    var characters: Array = parsed.get("characters", [])
    var wren: Dictionary = {}
    var male: Dictionary = {}
    for character_variant in characters:
        var character: Dictionary = character_variant
        var gender_prefix := "male_" if float(character.get("appearance", {}).get("gender", 0.0)) >= 0.5 else "female_"
        var body_profile := String(character.get("body_profile", ""))
        assert(profile_ids.has(body_profile), "Character %s has an unknown body profile: %s" % [String(character.get("id", "")), body_profile])
        assert(body_profile.begins_with(gender_prefix), "Character %s body profile does not match its selected body model" % String(character.get("id", "")))
        if String(character.get("id", "")) == "wren_talbot":
            wren = character
        if float(character.get("appearance", {}).get("gender", 0.0)) >= 0.5 and male.is_empty():
            male = character

    assert(not wren.is_empty(), "Wren's canonical profile must exist")
    var resolved_wren := RESOLVER.resolve_npc(wren)
    assert(resolved_wren.get("profile_id", "") == "wren_talbot")
    assert(resolved_wren.get("game_id", "") == "companion_wren_talbot")
    assert(resolved_wren.get("body_variant", "") == "female")
    assert(resolved_wren.get("body_profile", "") == "female_broad")
    assert(resolved_wren.get("hair_style_id", "") == "braid01")
    assert(resolved_wren.get("hair_tint", "") == "#252b62")
    assert(resolved_wren.get("equipped_ids", {}).get("shirt", "") == "fatigue_shirt")

    var state := CharacterState.new("companion_wren_talbot", "Wren Talbot", Vector2i.ZERO)
    assert(RESOLVER.populate_npc_inventory(state, resolved_wren), "Wren's canonical inventory should resolve")
    assert(state.inventory.size() == 0, "All Wren-owned items are currently equipped")
    assert(state.equipped_item_data.size() == wren.get("equipped", {}).size())
    assert(state.equipment.get("shirt", "") == "fatigue_shirt")
    assert(state.equipment.get("weapon", "") == "sword")
    assert(state.equipment.get("offhand", "") == "wooden_shield")

    assert(not male.is_empty(), "At least one male NPC profile must exist")
    var resolved_male := RESOLVER.resolve_npc(male)
    assert(resolved_male.get("body_variant", "") == "male", "Canonical male appearance must select the male Ara base")

    var player := RESOLVER.resolve_player({
        "name": "Test Adventurer",
        "body_variant": "male",
        "body_build": "Broad",
        "height": 0.55,
        "muscle": 0.8,
        "weight": 0.4,
        "proportions": 0.6,
        "eye_colour": "Green",
        "hair_colour": "Blue",
        "hair_style_id": "short03"
    })
    assert(player.get("is_player", false))
    assert(player.get("body_variant", "") == "male")
    assert(player.get("body_profile", "") == "male_broad")
    assert(player.get("hair_style_id", "") == "short03")
    assert(player.get("appearance", {}).get("eyes", "") == "green")
    assert(player.get("appearance", {}).get("hairTint", "") == "#354d91")
    assert(player.get("player_profile", {}).get("name", "") == "Test Adventurer")

    print("[Character assembly resolver test] PASS canonical NPC profiles, inventory/equipment, gender selection and player adapter.")
    quit(0)
