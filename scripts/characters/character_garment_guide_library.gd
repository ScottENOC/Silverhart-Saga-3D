class_name CharacterGarmentGuideLibrary
extends RefCounted
## Loads garment construction guides for one exact canonical Ara body asset.

const MANIFEST_PATH := "res://data/characters/garment_guides/manifest.tres"


static func load_for_body(body_asset_path: String) -> Array[Resource]:
    var result: Array[Resource] = []
    if body_asset_path.is_empty():
        return result
    var manifest := load(MANIFEST_PATH) as CharacterGarmentGuideManifest
    if manifest == null:
        push_warning("Ara garment guide manifest could not be loaded: " + MANIFEST_PATH)
        return result
    for resource in manifest.guides:
        if resource is CharacterGarmentGuideCurve and resource.body_asset_path == body_asset_path:
            result.append(resource)
    return result
