extends SceneTree

var _failures: int = 0

func _initialize() -> void:
    _test_item_catalog_and_hollowmere_loadouts()
    _test_equipped_item_combat_effects()
    if _failures > 0:
        push_error("%d test assertion(s) failed." % _failures)
        quit(1)
        return
    print("Items and equipment tests passed.")
    quit(0)

func _check(condition: bool, message: String = "Assertion failed") -> void:
    if not condition:
        _failures += 1
        push_error(message)
func _test_item_catalog_and_hollowmere_loadouts() -> void:
    var sword := ItemCatalog.create_instance("sword", "catalog_sword_001")
    _check(not sword.is_empty(), "Original sword definition should load")
    _check(int(sword.get("damage", 0)) == 3, "Sword damage should match Hex-crpg")
    _check(String(sword.get("equipment_slot", "")) == "weapon", "Sword should map to the weapon slot")
    _check(int(sword.get("icon_index", -1)) >= 0, "Sword should have a 2D inventory icon")

    var medium_armour := ItemCatalog.create_instance("medium_armor", "catalog_armour_001")
    _check(int(medium_armour.get("reduction", 0)) == 2, "Medium armour reduction should match Hex-crpg")
    _check(String(medium_armour.get("weight_class", "")) == "medium", "Medium armour should retain its movement class")
    var shield := ItemCatalog.create_instance("wooden_shield", "catalog_shield_001")
    _check(String(shield.get("type", "")) == "shield", "Offhand shield must retain shield type for Shield Other")
    _check(String(shield.get("equipment_slot", "")) == "offhand", "Shield should map to the offhand slot")

    var loadout_file := FileAccess.open("res://data/characters/hollowmere_loadouts.json", FileAccess.READ)
    _check(loadout_file != null, "Hollowmere loadout data should exist")
    if loadout_file == null:
        return
    var parsed: Variant = JSON.parse_string(loadout_file.get_as_text())
    _check(parsed is Dictionary, "Hollowmere loadout data should parse")
    if not parsed is Dictionary:
        return
    var loadouts: Dictionary = parsed.get("characters", {})
    _check(loadouts.get("dray_coltayne", []) == ["sword", "medium_armor", "wooden_shield"], "Dray's loadout should match the original campaign")
    _check(loadouts.get("tomlin_brask", []) == ["spear", "light_armor"], "Tomlin's loadout should match the original campaign")
    _check(loadouts.get("hask_greel", []) == ["axe", "light_armor"], "Hask's loadout should match the original campaign")
    _check(loadouts.get("companion_wren_talbot", []) == ["sword", "reinforced_leather_armor", "wooden_shield"], "Wren should retain the sword shown in the Ara profile")
    _check(not loadouts.has("player"), "Do not invent a player class kit before class selection exists")

    var dray := CharacterState.new("dray_coltayne", "Dray Coltayne", Vector2i.ZERO)
    var dray_items: Array = loadouts.get("dray_coltayne", [])
    for index in range(dray_items.size()):
        var item_id := String(dray_items[index])
        var instance_id := "test_dray_%s_%02d" % [item_id, index]
        var item := ItemCatalog.create_instance(item_id, instance_id)
        _check(dray.add_inventory_item(item), "Dray should accept source item %s" % item_id)
        _check(dray.equip_inventory_item(instance_id), "Dray should equip source item %s" % item_id)
    _check(String(dray.equipment.get("weapon", "")) == "sword", "Dray's sword should be equipped")
    _check(String(dray.equipment.get("armour", "")) == "medium_armor", "Dray's medium armour should be equipped")
    _check(String(dray.equipment.get("offhand", "")) == "wooden_shield", "Dray's shield should be equipped")
    _check(CombatRules.damage_reduction(dray) == 3, "Dray's armour and shield should affect damage reduction")
    _check(dray.inventory.is_empty(), "Starting equipment should be equipped, not duplicated in carried items")

func _test_equipped_item_combat_effects() -> void:
    var attacker := CharacterState.new("attacker", "Attacker", Vector2i.ZERO)
    attacker.base_damage = 1
    var sword := {
        "instance_id": "weapon_001",
        "id": "sword",
        "name": "Short sword",
        "type": "weapon",
        "equipment_slot": "weapon",
        "damage": 5,
        "quantity": 1
    }
    _check(attacker.add_inventory_item(sword))
    _check(attacker.equip_inventory_item("weapon_001"))
    _check(CombatRules.raw_damage(attacker) == 6, "Equipped weapon instance damage must affect combat")

    var armour := {
        "instance_id": "armour_001",
        "id": "leather_armour",
        "name": "Leather armour",
        "type": "armour",
        "equipment_slot": "armour",
        "weight_class": "light",
        "reduction": 3,
        "quantity": 1
    }
    var shield := {
        "instance_id": "shield_001",
        "id": "round_shield",
        "name": "Round shield",
        "type": "shield",
        "equipment_slot": "offhand",
        "reduction": 2,
        "quantity": 1
    }
    var defender := CharacterState.new("defender", "Defender", Vector2i(1, 0))
    _check(defender.add_inventory_item(armour))
    _check(defender.add_inventory_item(shield))
    _check(defender.equip_inventory_item("armour_001"))
    _check(defender.equip_inventory_item("shield_001"))
    _check(CombatRules.damage_reduction(defender) == 5, "Equipped armour and shield instance reductions must affect defence")
    _check(is_equal_approx(MovementRules.base_cost_for(defender), 5.0), "Light armour should not apply a heavy-armour movement penalty")
    var restored := CharacterState.from_dict(defender.to_dict())
    _check(restored.equipped_item_data.has("armour") and restored.equipped_item_data.has("offhand"), "Equipped item instances must survive save/load")
    _check(CombatRules.damage_reduction(restored) == 5)

    var helmet := ItemCatalog.create_instance("nasal_helm", "helmet_001")
    _check(defender.add_inventory_item(helmet), "Helmet should be carried as an item instance")
    _check(defender.equip_inventory_item("helmet_001"), "A helmet should equip to the helmet slot")
    _check(CombatRules.damage_reduction(defender) == 6, "Equipped helmet reduction must contribute to incoming damage mitigation")
    var restored_with_helmet := CharacterState.from_dict(defender.to_dict())
    _check(CombatRules.damage_reduction(restored_with_helmet) == 6, "Helmet reduction must survive save/load")

    var invalid_slot_item := {
        "instance_id": "wrong_slot_001", "id": "bad_helmet", "type": "helmet",
        "equipment_slot": "armour", "reduction": 4, "quantity": 1
    }
    _check(defender.add_inventory_item(invalid_slot_item))
    _check(not defender.equip_inventory_item("wrong_slot_001"), "A helmet must not equip into the body-armour slot")
    _check(defender.inventory.size() == 1, "Rejected equipment must remain in inventory")

    var two_hander := {
        "instance_id": "spear_001", "id": "spear", "type": "weapon",
        "equipment_slot": "weapon", "hands": 2, "damage": 4, "quantity": 1
    }
    _check(defender.add_inventory_item(two_hander))
    _check(not defender.equip_inventory_item("spear_001"), "A two-handed weapon must not equip while an offhand shield is equipped")
    _check(defender.inventory.size() == 2, "Rejected two-handed weapon must remain in inventory")

    var empty_handed := CharacterState.new("empty_handed", "Empty handed")
    _check(empty_handed.add_inventory_item(two_hander.duplicate(true)))
    _check(empty_handed.equip_inventory_item("spear_001"), "A two-handed weapon should equip when both hands are free")
    var conflicting_shield := {
        "instance_id": "shield_002", "id": "wooden_shield", "type": "shield",
        "equipment_slot": "offhand", "reduction": 1, "quantity": 1
    }
    _check(empty_handed.add_inventory_item(conflicting_shield))
    _check(not empty_handed.equip_inventory_item("shield_002"), "An offhand shield must not equip alongside a two-handed weapon")
    _check(empty_handed.inventory.size() == 1, "Rejected shield must remain in inventory")
