extends SceneTree


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var editor_script := load("res://tools/garment_guide_curve_editor.gd") as Script
    assert(editor_script != null, "Garment guide editor script failed to load")
    var constants: Dictionary = editor_script.get_script_constant_map()
    var labels: Dictionary = constants.get("GUIDE_LABELS", {})
    var pairs: Dictionary = constants.get("GUIDE_PAIRS", {})
    for guide_id in CharacterGarmentGuideCurve.VALID_GUIDE_IDS:
        assert(labels.has(guide_id), "Guide editor is missing selector label " + guide_id)
    assert(labels.size() == CharacterGarmentGuideCurve.VALID_GUIDE_IDS.size(),
        "Guide editor and runtime vocabularies contain different guide counts")
    for guide_id in pairs:
        assert(CharacterGarmentGuideCurve.VALID_GUIDE_IDS.has(pairs[guide_id]),
            "Guide pair points to unsupported ID: " + String(pairs[guide_id]))
        assert(pairs.has(pairs[guide_id]) and pairs[pairs[guide_id]] == guide_id,
            "Guide pairing is not reciprocal for " + String(guide_id))
    var scene := load("res://tools/garment_guide_curve_editor.tscn") as PackedScene
    assert(scene != null, "Garment guide editor scene failed to load")
    var manifest := load("res://data/characters/garment_guides/manifest.tres") as CharacterGarmentGuideManifest
    assert(manifest != null, "Garment guide manifest failed to load")
    for resource in manifest.guides:
        assert(resource is CharacterGarmentGuideCurve, "Guide manifest contains a non-guide resource")
    assert(CharacterGarmentGuideLibrary.load_for_body("res://missing_body.glb").is_empty(),
        "Unknown body should not receive garment guides")
    print("ARA_GARMENT_GUIDE_EDITOR_LOAD: PASS guide_ids=%d" % labels.size())
    quit(0)
