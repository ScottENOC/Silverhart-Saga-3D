extends SceneTree

const PROFILE_FACTORY = preload("res://scripts/simulation/procedural_npc_profile_factory.gd")

func _initialize() -> void:
    var first := PROFILE_FACTORY.create_profile("tavern_test_001", "Test Patron", "tavern patron")
    var repeat := PROFILE_FACTORY.create_profile("tavern_test_001", "Test Patron", "tavern patron")
    var different := PROFILE_FACTORY.create_profile("tavern_test_002", "Other Patron", "tavern patron")
    var named_female := PROFILE_FACTORY.create_profile("mira_ashbrook", "Mira Ashbrook", "villager")
    var named_male := PROFILE_FACTORY.create_profile("garrick_holt", "Garrick Holt", "tavern keeper")
    var first_params: Dictionary = first.get("params", {})
    var repeat_params: Dictionary = repeat.get("params", {})
    var other_params: Dictionary = different.get("params", {})
    var named_female_params: Dictionary = named_female.get("params", {})
    var named_male_params: Dictionary = named_male.get("params", {})
    if int(named_female_params.get("gender", -1)) != 0:
        _fail("Authored female NPC identity was not respected")
        return
    if int(named_male_params.get("gender", -1)) != 1:
        _fail("Authored male NPC identity was not respected")
        return
    var authored_checks := {
        "hair": "bob01",
        "eyes": "brown",
        "hairTint": "#38251D",
        "skinTint": "#C99A75",
        "height": 0.44,
        "muscle": 0.38,
        "weight": 0.34,
        "proportions": 0.46,
        "breasts": 0.43,
        "legs": 0.43
    }
    for key in authored_checks:
        if named_female_params.get(key) != authored_checks[key]:
            _fail("Mira's authored appearance field was not reused: %s (got %s)" % [key, named_female_params.get(key)])
            return
    if named_male_params.get("hair") != "buzz" or named_male_params.get("eyes") != "green" or named_male_params.get("hairTint") != "#87452D" or named_male_params.get("skinTint") != "#DDAE8D":
        _fail("Garrick's authored appearance was not reused")
        return
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
