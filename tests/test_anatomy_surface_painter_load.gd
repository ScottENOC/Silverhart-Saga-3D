extends SceneTree


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var painter_script := load("res://tools/anatomy_surface_painter.gd") as Script
    assert(painter_script != null, "Anatomy surface painter script failed to load")
    var painter_constants: Dictionary = painter_script.get_script_constant_map()
    var painter_labels: Dictionary = painter_constants.get("REGION_LABELS", {})
    var body_options: Dictionary = painter_constants.get("BODY_OPTIONS", {})
    assert(body_options.get("Wren (current native build)", "") == "res://build/wren-native/Wren.glb",
        "Painter must target the current native Wren build")
    assert(body_options.get("Aldric (current native build)", "") == "res://build/aldric-native/Aldric.glb",
        "Painter must target the current native Aldric build")
    assert(body_options.size() == 2, "Painter must not offer the obsolete generic Ara bodies")
    # REGION_LABELS is intentionally a partial override map: newly added IDs use
    # the painter's readable fallback (underscores replaced and title-cased).
    # Verify every runtime ID has either an explicit label or a non-empty fallback.
    for region_id in CharacterSurfaceRegionMask.REGION_IDS:
        var display_label := String(painter_labels.get(region_id, region_id.replace("_", " ").capitalize()))
        assert(not display_label.strip_edges().is_empty(),
            "Mask region %s has no usable painter label" % region_id)
    var grouped_regions: Array = painter_constants.get("REGION_GROUPS", [])
    var grouped_ids := PackedStringArray()
    for group in grouped_regions:
        for region_id in group["ids"]:
            assert(not grouped_ids.has(String(region_id)), "Painter region appears in multiple groups: " + String(region_id))
            grouped_ids.append(String(region_id))
    assert(grouped_ids.size() == CharacterSurfaceRegionMask.REGION_IDS.size(),
        "Painter selector groups do not cover every runtime region")
    for region_id in CharacterSurfaceRegionMask.REGION_IDS:
        assert(grouped_ids.has(region_id), "Painter selector group is missing " + region_id)
    # A broad rig channel must never be counted as an authored fine mask.
    # This catches name collisions such as calf_left and forearm_left.
    var region_queries = load("res://scripts/characters/character_surface_regions.gd").new()
    var mixed_channels := {
        "region_weights": {"calf_left": PackedFloat32Array([1.0])},
        "fine_region_weights": {}
    }
    assert(region_queries._get_region_weights(mixed_channels, "calf_left").size() == 1,
        "General region queries should retain the broad rig fallback")
    assert(region_queries._get_authored_region_weights(mixed_channels, "calf_left").is_empty(),
        "Authored-only queries must not mistake broad rig weights for fine masks")
    mixed_channels["fine_region_weights"] = {"calf_left": PackedFloat32Array([0.6])}
    assert(is_equal_approx(region_queries._get_region_weights(mixed_channels, "calf_left")[0], 0.6),
        "Authored fine weights must take precedence over broad rig weights")
    assert(painter_script.get_script_method_list().any(func(method: Dictionary): return method["name"] == "_inspect_at"),
        "Painter must expose barycentric multi-region point inspection")
    assert(painter_script.get_script_method_list().any(func(method: Dictionary): return method["name"] == "_barycentric_weights"),
        "Painter must interpolate region memberships at triangle surface points")
    var painter_scene := load("res://tools/anatomy_surface_painter.tscn") as PackedScene
    assert(painter_scene != null, "Anatomy surface painter scene failed to load")
    var painter_instance := painter_scene.instantiate() as Control
    assert(painter_instance != null, "Anatomy painter scene root is not Control")
    root.add_child(painter_instance)
    await process_frame
    await process_frame
    assert(painter_instance.get("_body_root") != null, "Anatomy painter did not load the current Wren native build")
    assert(painter_instance.get("_inspect_check") != null, "Anatomy painter did not build its membership inspection toggle")
    assert(painter_instance.get("_inspected_point_marker") != null, "Anatomy painter did not build its inspected-point marker")
    # The exclusive primary partition is a separate authoring mode. Verify
    # that it exposes the 15 broad regions without replacing the overlapping
    # feature-mask selector or enabling mirror painting.
    var partition_ids: Array = painter_constants.get("PARTITION_REGION_IDS", [])
    var partition_labels: Array = painter_constants.get("PARTITION_REGION_LABELS", [])
    assert(partition_ids.size() == 15, "Primary partition must expose the 15 broad body regions")
    assert(partition_labels.size() == partition_ids.size(), "Every primary partition region needs a display label")
    var partition_check := painter_instance.get("_partition_mode_check") as CheckButton
    var partition_option := painter_instance.get("_partition_region_option") as OptionButton
    var feature_option := painter_instance.get("_region_option") as OptionButton
    var mirror_check := painter_instance.get("_mirror_check") as CheckButton
    var save_path_edit := painter_instance.get("_save_path_edit") as LineEdit
    assert(partition_check != null and partition_option != null and feature_option != null,
        "Painter did not build the separate primary partition controls")
    painter_instance.call("_on_partition_mode_toggled", true)
    assert(partition_option.visible, "Primary partition selector should be visible in partition mode")
    assert(not feature_option.visible, "Overlapping feature selector should be hidden in partition mode")
    assert(mirror_check.disabled, "Mirror painting must be disabled for exclusive partition ownership")
    assert(save_path_edit.text.ends_with("_primary.tres"),
        "Primary partition saves must use a distinct _primary resource path")
    painter_instance.call("_on_partition_mode_toggled", false)
    assert(feature_option.visible and not partition_option.visible,
        "Returning to feature mode must restore the overlapping feature selector")
    assert(not mirror_check.disabled, "Returning to feature mode must restore mirror painting")
    painter_instance.queue_free()
    await process_frame
    var input_router := load("res://tools/anatomy_surface_painter_input.gd") as Script
    assert(input_router != null, "Anatomy surface painter input router failed to load")
    var manifest := load("res://data/characters/anatomy_masks/manifest.tres") as CharacterSurfaceRegionMaskManifest
    assert(manifest != null, "Authored anatomy mask manifest failed to load")
    for resource in manifest.masks:
        assert(resource is CharacterSurfaceRegionMask, "Manifest contains a non-mask resource")
    var female_masks: Array[Resource] = CharacterSurfaceRegionMaskLibrary.load_for_body(
        "res://art/characters/ara_runtime/ara_person_body_anatomy.glb"
    )
    var male_masks: Array[Resource] = CharacterSurfaceRegionMaskLibrary.load_for_body(
        "res://art/characters/ara_runtime/ara_person_male_body.glb"
    )
    for mask in female_masks:
        assert(mask.body_asset_path == "res://art/characters/ara_runtime/ara_person_body_anatomy.glb",
            "Female mask library returned a mask for another body")
    for mask in male_masks:
        assert(mask.body_asset_path == "res://art/characters/ara_runtime/ara_person_male_body.glb",
            "Male mask library returned a mask for another body")
    assert(CharacterSurfaceRegionMaskLibrary.load_for_body("res://missing_body.glb").is_empty(),
        "Unknown body should not receive any fine masks")
    print("WREN_ALDRIC_ANATOMY_SURFACE_PAINTER_LOAD: PASS legacy_library_masks=%d/%d" % [
        female_masks.size(), male_masks.size()
    ])
    quit(0)
