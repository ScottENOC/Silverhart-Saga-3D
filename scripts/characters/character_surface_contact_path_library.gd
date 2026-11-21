class_name CharacterSurfaceContactPathLibrary
extends RefCounted

const MANIFEST_PATH := "res://data/characters/surface_contact_paths/manifest.tres"


static func load_for_body(body_asset_path: String, body_root: Node3D) -> Array[Resource]:
    var result: Array[Resource] = []
    if body_asset_path.is_empty() or body_root == null:
        return result
    var manifest := load(MANIFEST_PATH) as CharacterSurfaceContactPathManifest
    if manifest == null:
        push_warning("Surface contact path manifest could not be loaded: " + MANIFEST_PATH)
        return result
    var seen_ids := {}
    for resource in manifest.paths:
        if not resource is CharacterSurfaceContactPath:
            continue
        var path := resource as CharacterSurfaceContactPath
        if path.body_asset_path != body_asset_path:
            continue
        if seen_ids.has(path.path_id):
            push_warning("Ignoring duplicate surface contact path ID: " + path.path_id)
            continue
        var mesh := body_root.get_node_or_null(path.mesh_node_path) as MeshInstance3D
        if mesh == null:
            push_warning("Ignoring contact path %s: mesh path does not resolve" % path.path_id)
            continue
        var error := path.validate_for_mesh(mesh, body_root, body_asset_path)
        if not error.is_empty():
            push_warning("Ignoring stale contact path %s: %s" % [path.path_id, error])
            continue
        seen_ids[path.path_id] = true
        result.append(path)
    return result
