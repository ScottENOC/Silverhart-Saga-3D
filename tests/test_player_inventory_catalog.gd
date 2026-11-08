extends SceneTree
## Verifies the temporary campaign starter inventory contains one instance of
## every migrated item definition and preserves the normal equip/unequip path.

const RULES = preload("res://scripts/simulation/character_creation_rules.gd")
const ITEM_CATALOG = preload("res://scripts/simulation/item_catalog.gd")

func _initialize() -> void:
    var profile := {
        "name": "Inventory Test",
        "race": "human",
        "character_class": "fighter",
        "game_mode": "campaign",
        "campaign_id": "2",
        "difficulty_mode": "normal"
    }
    var state := RULES.create_player_state(profile, "inventory_test", Vector2i.ZERO)
    var owned: Dictionary = {}
    for item in state.inventory:
        var item_id := String(item.get("id", ""))
        assert(not owned.has(item_id), "Duplicate seeded item: %s" % item_id)
        owned[item_id] = true
    for item in state.equipped_item_data.values():
        var item_id := String(item.get("id", ""))
        assert(not owned.has(item_id), "Duplicate equipped item: %s" % item_id)
        owned[item_id] = true

    for item_id in ITEM_CATALOG.get_item_ids():
        assert(owned.has(item_id), "Campaign character is missing catalogue item: %s" % item_id)
    assert(owned.has("sword"), "Sword item should be owned by the campaign character")

    var sword_instance := ""
    for item in state.inventory:
        if String(item.get("id", "")) == "sword":
            sword_instance = String(item.get("instance_id", ""))
            break
    assert(not sword_instance.is_empty(), "Sword should be available in inventory for the test")
    assert(state.equip_inventory_item(sword_instance), "Sword should equip through CharacterState")
    assert(String(state.equipment.get("weapon", "")) == "sword")
    assert(state.equipped_item_data.has("weapon"))
    assert(state.unequip_equipment_slot("weapon"), "Sword should unequip back into inventory")
    print("PLAYER_INVENTORY_CATALOG_TEST: PASS (%d catalogue items)" % ITEM_CATALOG.get_item_ids().size())
    quit(0)
