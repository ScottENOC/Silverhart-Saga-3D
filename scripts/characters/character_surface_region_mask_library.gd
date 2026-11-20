class_name CharacterSurfaceRegionMaskLibrary
extends RefCounted
## Loads authored fine-region masks for an exact canonical body asset.
## The manifest explicitly references every mask so exported builds retain them.

const MANIFEST_PATH := "res://data/characters/anatomy_masks/manifest.tres"


static func load_for_body(body_asset_path: String) -> Array[Resource]:
    var result: Array[Resource] = []
    if body_asset_path.is_empty():
        return result
    var manifest := load(MANIFEST_PATH) as CharacterSurfaceRegionMaskManifest
    if manifest == null:
        push_warning("Ara anatomy mask manifest could not be loaded: " + MANIFEST_PATH)
        return result
    for resource in manifest.masks:
        if resource is CharacterSurfaceRegionMask and resource.body_asset_path == body_asset_path:
            result.append(resource)
    return result
