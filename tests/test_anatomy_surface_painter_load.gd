extends SceneTree


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var painter_script := load("res://tools/anatomy_surface_painter.gd") as Script
    assert(painter_script != null, "Anatomy surface painter script failed to load")
    var painter_constants: Dictionary = painter_script.get_script_constant_map()
    var painter_labels: Dictionary = painter_constants.get("REGION_LABELS", {})
    for region_id in CharacterSurfaceRegionMask.REGION_IDS:
        assert(painter_labels.has(region_id), "Mask region %s is missing from the painter selector" % region_id)
    assert(painter_labels.size() == CharacterSurfaceRegionMask.REGION_IDS.size(),
        "Painter and runtime mask vocabularies contain different region counts")
    var painter_scene := load("res://tools/anatomy_surface_painter.tscn") as PackedScene
    assert(painter_scene != null, "Anatomy surface painter scene failed to load")
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
    print("ARA_ANATOMY_SURFACE_PAINTER_LOAD: PASS female_masks=%d male_masks=%d" % [
        female_masks.size(), male_masks.size()
    ])
    quit(0)
