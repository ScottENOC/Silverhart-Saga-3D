extends SceneTree

const PROFILE_FACTORY = preload("res://scripts/simulation/procedural_npc_profile_factory.gd")

func _initialize() -> void:
    var first := PROFILE_FACTORY.create_profile("tavern_test_001", "Test Patron", "tavern patron")
    var repeat := PROFILE_FACTORY.create_profile("tavern_test_001", "Test Patron", "tavern patron")
    var different := PROFILE_FACTORY.create_profile("tavern_test_002", "Other Patron", "tavern patron")
    assert(first == repeat, "A character ID must reproduce the same appearance profile")
    assert(first != different, "Different character IDs should produce distinct profiles")
    var params: Dictionary = first.get("params", {})
    for key in ["gender", "age", "muscle", "weight", "height", "proportions", "african", "asian", "caucasian", "eyes", "hair", "hairTint", "top", "bottom", "underTop", "underBottom", "shoes"]:
        assert(params.has(key), "Generated NPC is missing creator parameter: %s" % key)
    for key in ["age", "muscle", "weight", "height", "proportions", "african", "asian", "caucasian"]:
        assert(float(params[key]) >= 0.0 and float(params[key]) <= 1.0, "Generated slider outside 0..1: %s" % key)
    assert(String(params.get("top", "none")) != "none", "Generic tavern NPC should have an outer top")
    assert(String(params.get("bottom", "none")) != "none", "Generic tavern NPC should have an outer bottom")
    assert(String(params.get("underBottom", "none")) != "none", "Generic tavern NPC should have lower underwear")
    assert(String(params.get("shoes", "none")) != "none", "Generic tavern NPC should have footwear")
    print("PROCEDURAL_NPC_PROFILE_TEST: PASS (deterministic full appearance profile)")
    quit(0)
