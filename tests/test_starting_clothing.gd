extends SceneTree

const CREATION_RULES = preload("res://scripts/simulation/character_creation_rules.gd")
const NPC_WORLD = preload("res://scripts/world/hollow_tankard.gd")
const CHARACTER_STATE = preload("res://scripts/simulation/character_state.gd")


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    _test_player_starting_clothing()
    _test_npc_clothing_inventory()
    print("STARTING_CLOTHING_TEST: PASS")
    quit(0)


func _test_player_starting_clothing() -> void:
    var female_profile := {
        "name": "Test Adventurer",
        "race": "human",
        "character_class": "fighter",
        "body_variant": "female",
        "gender_presentation": "Feminine"
    }
    var female := CREATION_RULES.create_player_state(female_profile, "test_female", Vector2i.ZERO)
    assert(female.equipped_item_data.has("underTop"), "Female player should start with a bra equipped")
    assert(female.equipped_item_data.has("underBottom"), "Player should start with briefs equipped")
    assert(female.equipped_item_data.has("shirt"), "Player should start with a shirt equipped")
    assert(female.equipped_item_data.has("pants"), "Player should start with trousers equipped")
    assert(String(female.equipped_item_data["shirt"].get("id", "")) == "long_tunic")
    assert(String(female.equipped_item_data["pants"].get("id", "")) == "trousers")

    var male_profile := female_profile.duplicate(true)
    male_profile["name"] = "Test Male Adventurer"
    male_profile["body_variant"] = "male"
    male_profile["gender_presentation"] = "Masculine"
    var male := CREATION_RULES.create_player_state(male_profile, "test_male", Vector2i.ZERO)
    assert(male.equipped_item_data.has("underBottom"), "Male player should start with briefs equipped")
    assert(male.equipped_item_data.has("shirt"), "Male player should start with a shirt equipped")
    assert(male.equipped_item_data.has("pants"), "Male player should start with trousers equipped")
    assert(not male.equipped_item_data.has("underTop"), "Do not assign a bra to a masculine body")
    assert(String(male.equipped_item_data["shirt"].get("id", "")) == "long_tunic")
    assert(String(male.equipped_item_data["pants"].get("id", "")) == "trousers")


func _test_npc_clothing_inventory() -> void:
    var world := NPC_WORLD.new()
    var npc = CHARACTER_STATE.new("test_npc", "Test NPC", Vector2i.ZERO)
    world._apply_npc_clothing_loadout(npc, {
        "params": {
            "underTop": "bra",
            "underBottom": "none",
            "top": "uniform_shirt",
            "bottom": "fatigue_pants",
            "shoes": "combat_boots"
        }
    })
    assert(npc.equipped_item_data.has("underTop"), "NPC bra should be equipped from its Ara profile")
    assert(npc.equipped_item_data.has("shirt"), "NPC shirt should be equipped from its Ara profile")
    assert(npc.equipped_item_data.has("pants"), "NPC trousers should be equipped from its Ara profile")
    assert(npc.equipped_item_data.has("shoes"), "NPC footwear should be equipped from its Ara profile")
    assert(npc.inventory.is_empty(), "Equipped NPC clothing should no longer remain in carried inventory")
    world.free()
    npc.free()
