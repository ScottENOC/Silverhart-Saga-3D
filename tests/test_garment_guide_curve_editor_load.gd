extends SceneTree


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var editor_script := load("res://tools/garment_guide_curve_editor.gd") as Script
    assert(editor_script != null, "Garment guide editor script failed to load")
    var guide_script := load("res://scripts/characters/character_garment_guide_curve.gd") as Script
    assert(guide_script != null, "Garment guide curve script failed to load")
    var guide_probe = guide_script.new()
    guide_probe.guide_id = "cup_perimeter_left"
    guide_probe.closed_loop = false
    assert(guide_probe.validate_loop_semantics().contains("closed loop"),
        "Runtime guide resource must reject an open bra cup perimeter")
    guide_probe.closed_loop = true
    assert(guide_probe.validate_loop_semantics().is_empty(),
        "Runtime guide resource must accept a closed bra cup perimeter")
    guide_probe.guide_id = "strap_left"
    guide_probe.closed_loop = true
    assert(guide_probe.validate_loop_semantics().contains("open path"),
        "Runtime guide resource must reject a closed bra strap")
    guide_probe.closed_loop = false
    assert(guide_probe.validate_loop_semantics().is_empty(),
        "Runtime guide resource must accept an open bra strap")
    assert(guide_probe.has_method("evaluate_surface_path"),
        "Garment guides must expose mesh-constrained dense path evaluation")
    var constants: Dictionary = editor_script.get_script_constant_map()
    var labels: Dictionary = constants.get("GUIDE_LABELS", {})
    var pairs: Dictionary = constants.get("GUIDE_PAIRS", {})
    var loop_requirements: Dictionary = constants.get("GUIDE_LOOP_REQUIREMENTS", {})
    assert(loop_requirements.get("cup_perimeter_left", false) == true,
        "Left bra cup perimeter must be a closed loop")
    assert(loop_requirements.get("cup_perimeter_right", false) == true,
        "Right bra cup perimeter must be a closed loop")
    assert(loop_requirements.get("centre_gore", false) == true,
        "Centre gore boundary must be a closed loop")
    for open_guide in ["underband_front", "underband_back", "strap_left", "strap_right"]:
        assert(loop_requirements.has(open_guide) and loop_requirements[open_guide] == false,
            "Bra edge/strap guide must be an open path: " + open_guide)
    for guide_id in CharacterGarmentGuideCurve.VALID_GUIDE_IDS:
        assert(labels.has(guide_id), "Guide editor is missing selector label " + guide_id)
    assert(labels.size() == CharacterGarmentGuideCurve.VALID_GUIDE_IDS.size(),
        "Guide editor and runtime vocabularies contain different guide counts")
    for guide_id in pairs:
        assert(CharacterGarmentGuideCurve.VALID_GUIDE_IDS.has(pairs[guide_id]),
            "Guide pair points to unsupported ID: " + String(pairs[guide_id]))
        assert(pairs.has(pairs[guide_id]) and pairs[pairs[guide_id]] == guide_id,
            "Guide pairing is not reciprocal for " + String(guide_id))
    var body_options: Dictionary = constants.get("BODY_OPTIONS", {})
    assert(body_options.get("Wren (current native build)", "") == "res://build/wren-native/Wren.glb",
        "Garment guides must target the current native Wren build")
    assert(body_options.get("Aldric (current native build)", "") == "res://build/aldric-native/Aldric.glb",
        "Garment guides must target the current native Aldric build")
    assert(body_options.size() == 2, "Generic Ara bodies must not remain garment guide targets")

    var coverage_script := load("res://scripts/characters/character_garment_coverage_definition.gd") as Script
    assert(coverage_script != null, "Garment coverage definition failed to load")
    var coverage = coverage_script.new()
    coverage.garment_id = "test_bra"
    coverage.body_asset_path = "res://build/wren-native/Wren.glb"
    var coverage_parts: Array[Dictionary] = [
        {
            "part_id": "left_cup",
            "region_ids": PackedStringArray(["breast_left", "sternum"]),
            "boundary_guide_ids": PackedStringArray(["cup_perimeter_left"]),
            "fit_mode": "support",
            "normal_offset_m": 0.003,
            "clearance_m": 0.002,
            "compression": 0.15,
            "support": 0.8
        }
    ]
    coverage.coverage_parts = coverage_parts
    assert(coverage.validate_definition().is_empty(),
        "A cup should allow overlapping breast/sternum coverage channels")
    coverage.coverage_parts[0]["boundary_guide_ids"] = PackedStringArray(["unknown_bra_seam"])
    assert(not coverage.validate_definition().is_empty(),
        "Unknown garment boundary guides must be rejected")
    coverage.coverage_parts[0]["boundary_guide_ids"] = PackedStringArray(["cup_perimeter_left"])
    coverage.coverage_parts[0]["region_ids"] = PackedStringArray(["not_an_anatomy_region"])
    assert(not coverage.validate_definition().is_empty(),
        "Unknown anatomical region IDs must be rejected")
    coverage.coverage_parts[0]["region_ids"] = PackedStringArray(["breast_left", "sternum"])
    coverage.coverage_parts.append(coverage.coverage_parts[0].duplicate(true))
    assert(not coverage.validate_definition().is_empty(),
        "Duplicate garment coverage part IDs must be rejected")

    var scene := load("res://tools/garment_guide_curve_editor.tscn") as PackedScene
    assert(scene != null, "Garment guide editor scene failed to load")
    var editor_instance := scene.instantiate() as Control
    assert(editor_instance != null, "Garment guide editor scene root is not Control")
    root.add_child(editor_instance)
    await process_frame
    await process_frame
    assert(editor_instance.get("_body_root") != null,
        "Garment guide editor did not load the current Wren native build")
    var guide_option := editor_instance.get("_guide_option") as OptionButton
    var closed_check := editor_instance.get("_closed_check") as CheckButton
    assert(guide_option != null and closed_check != null,
        "Garment guide editor did not build its guide and loop controls")
    for guide_id in loop_requirements:
        var option_index := -1
        for item_index in range(guide_option.item_count):
            if String(guide_option.get_item_metadata(item_index)) == String(guide_id):
                option_index = item_index
                break
        assert(option_index >= 0, "Guide editor selector is missing " + String(guide_id))
        guide_option.select(option_index)
        editor_instance.call("_on_guide_selected", option_index)
        assert(closed_check.disabled,
            "Bra guide loop semantics must lock the checkbox for " + String(guide_id))
        assert(closed_check.button_pressed == bool(loop_requirements[guide_id]),
            "Bra guide loop checkbox has the wrong state for " + String(guide_id))
    editor_instance.queue_free()
    await process_frame
    var manifest := load("res://data/characters/garment_guides/manifest.tres") as CharacterGarmentGuideManifest
    assert(manifest != null, "Garment guide manifest failed to load")
    for resource in manifest.guides:
        assert(resource is CharacterGarmentGuideCurve, "Guide manifest contains a non-guide resource")
    assert(CharacterGarmentGuideLibrary.load_for_body("res://missing_body.glb", null).is_empty(),
        "Unknown body should not receive garment guides")
    print("ARA_GARMENT_GUIDE_EDITOR_LOAD: PASS guide_ids=%d" % labels.size())
    quit(0)
