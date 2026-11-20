extends SceneTree

const PROFILE_FACTORY = preload("res://scripts/simulation/procedural_npc_profile_factory.gd")

func _initialize() -> void:
    var first := PROFILE_FACTORY.create_profile("tavern_test_001", "Test Patron", "tavern patron")
    var repeat := PROFILE_FACTORY.create_profile("tavern_test_001", "Test Patron", "tavern patron")
    var different := PROFILE_FACTORY.create_profile("tavern_test_002", "Other Patron", "tavern patron")
    var first_params: Dictionary = first.get("params", {})
    var repeat_params: Dictionary = repeat.get("params", {})
    var other_params: Dictionary = different.get("params", {})
    var stable_keys := ["gender", "age", "muscle", "weight", "height", "proportions", "african", "asian", "caucasian", "eyes", "hair", "hairTint", "top", "bottom", "underTop", "underBottom", "shoes", "tattoos", "piercings"]
    for key in stable_keys:
        if first_params.get(key) != repeat_params.get(key):
            _fail("Same character ID did not reproduce parameter: %s" % key)
            return
    var differs := false
    for key in stable_keys:
        if first_params.get(key) != other_params.get(key):
            differs = true
            break
    if not differs:
        _fail("Different character IDs produced identical appearance parameters")
        return
    for key in ["gender", "age", "muscle", "weight", "height", "proportions", "african", "asian", "caucasian"]:
        var value := float(first_params.get(key, -1.0))
        if value < 0.0 or value > 1.0:
            _fail("Generated slider outside 0..1: %s=%s" % [key, value])
            return
    for key in ["top", "bottom", "underBottom", "shoes"]:
        if String(first_params.get(key, "none")) == "none":
            _fail("Generic tavern NPC is missing required clothing: %s" % key)
            return
    print("PROCEDURAL_NPC_PROFILE_TEST: PASS (deterministic full appearance profile)")
    quit(0)


func _fail(message: String) -> void:
    push_error("PROCEDURAL_NPC_PROFILE_TEST: " + message)
    quit(1)
