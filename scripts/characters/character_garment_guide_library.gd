class_name CharacterGarmentGuideLibrary
extends RefCounted
## Loads and validates garment construction guides for one exact canonical Ara body.

const MANIFEST_PATH := "res://data/characters/garment_guides/manifest.tres"


static func load_for_body(body_asset_path: String, body_root: Node3D) -> Array[Resource]:
    var result: Array[Resource] = []
    if body_asset_path.is_empty() or body_root == null:
        return result
    var manifest := load(MANIFEST_PATH) as CharacterGarmentGuideManifest
    if manifest == null:
        push_warning("Ara garment guide manifest could not be loaded: " + MANIFEST_PATH)
        return result
    for resource in manifest.guides:
        if not resource is CharacterGarmentGuideCurve or resource.body_asset_path != body_asset_path:
            continue
        var guide := resource as CharacterGarmentGuideCurve
        var mesh_instance := body_root.get_node_or_null(guide.mesh_node_path) as MeshInstance3D
        if mesh_instance == null:
            push_warning("Ignoring Ara garment guide %s: mesh path does not resolve" % guide.guide_id)
            continue
        var validation := guide.validate_for_mesh(mesh_instance, body_root, body_asset_path)
        if not validation.is_empty():
            push_warning("Ignoring stale Ara garment guide %s: %s" % [guide.guide_id, validation])
            continue
        result.append(guide)
    return result
