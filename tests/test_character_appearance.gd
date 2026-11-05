extends SceneTree

func _initialize() -> void:
    var appearance := CharacterAppearance.new()
    appearance.body_variant = "ara_female_athletic"
    appearance.hair_id = "ponytail01"
    appearance.hair_tint = Color("#6f3428")
    appearance.tattoos = ["forearm_left"]
    appearance.accessories = {"ear.left": "silver_hoop", "nose.ring": "small_silver"}
    appearance.equipment["shirt"] = "fatigue_shirt"
    appearance.equipment["main_hand"] = "sword"
    appearance.materials["shirt"] = {
        "colour": "#9c2632",
        "secondary": "#d9b7a4",
        "fabric": "linen",
        "opacity": 1.0
    }
    var save_error := CharacterAppearanceStore.save_appearance("npc_test_01", appearance)
    assert(save_error == OK, "Appearance save failed: %s" % error_string(save_error))
    var loaded := CharacterAppearanceStore.load_appearance("npc_test_01")
    assert(loaded.body_variant == appearance.body_variant)
    assert(loaded.hair_id == appearance.hair_id)
    assert(loaded.hair_tint.is_equal_approx(appearance.hair_tint))
    assert(loaded.equipment["shirt"] == "fatigue_shirt")
    assert(loaded.materials["shirt"]["colour"] == "#9c2632")
    assert(loaded.accessories["nose.ring"] == "small_silver")
    print("Character appearance save/reload test passed.")
    quit(0)
