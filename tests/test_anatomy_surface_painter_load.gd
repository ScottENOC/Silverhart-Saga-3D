extends SceneTree


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var painter_script := load("res://tools/anatomy_surface_painter.gd") as Script
    assert(painter_script != null, "Anatomy surface painter script failed to load")
    var painter_scene := load("res://tools/anatomy_surface_painter.tscn") as PackedScene
    assert(painter_scene != null, "Anatomy surface painter scene failed to load")
    var input_router := load("res://tools/anatomy_surface_painter_input.gd") as Script
    assert(input_router != null, "Anatomy surface painter input router failed to load")
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
