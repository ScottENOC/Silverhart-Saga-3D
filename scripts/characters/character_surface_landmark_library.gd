class_name CharacterSurfaceLandmarkLibrary
extends RefCounted
## Loads topology-validated semantic skin-surface landmarks for one Ara body.

const MANIFEST_PATH := "res://data/characters/surface_landmarks/manifest.tres"


static func load_for_body(body_asset_path: String, body_root: Node3D) -> Array[Resource]:
    var result: Array[Resource] = []
    if body_asset_path.is_empty() or body_root == null:
        return result
    var manifest := load(MANIFEST_PATH) as CharacterSurfaceLandmarkManifest
    if manifest == null:
        push_warning("Ara surface landmark manifest could not be loaded: " + MANIFEST_PATH)
        return result
    var seen_ids := {}
    for resource in manifest.landmarks:
        if not resource is CharacterSurfaceLandmark:
            push_warning("Ignoring non-landmark resource in Ara surface landmark manifest")
            continue
        var landmark := resource as CharacterSurfaceLandmark
        if landmark.body_asset_path != body_asset_path:
            continue
        if seen_ids.has(landmark.landmark_id):
            push_warning("Ignoring duplicate Ara surface landmark ID: " + landmark.landmark_id)
            continue
        var mesh_instance := body_root.get_node_or_null(landmark.mesh_node_path) as MeshInstance3D
        if mesh_instance == null:
            push_warning("Ignoring Ara surface landmark %s: mesh path does not resolve" % landmark.landmark_id)
            continue
        var validation := landmark.validate_for_mesh(mesh_instance, body_root, body_asset_path)
        if not validation.is_empty():
            push_warning("Ignoring stale Ara surface landmark %s: %s" % [landmark.landmark_id, validation])
            continue
        seen_ids[landmark.landmark_id] = true
        result.append(landmark)
    return result
