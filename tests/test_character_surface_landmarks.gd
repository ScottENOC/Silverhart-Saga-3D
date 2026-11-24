extends SceneTree

const BODY_ASSETS := [
    "res://art/characters/ara_runtime/ara_person_body_anatomy.glb",
    "res://art/characters/ara_runtime/ara_person_male_body.glb"
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await process_frame
    for asset_path in BODY_ASSETS:
        await _test_body(asset_path)
    print("ARA_SURFACE_LANDMARK_CONTRACT: PASS")
    quit(0)


func _test_body(asset_path: String) -> void:
    var packed := load(asset_path) as PackedScene
    assert(packed != null, "Could not load " + asset_path)
    var actor_root := Node3D.new()
    root.add_child(actor_root)
    var body_root := packed.instantiate() as Node3D
    assert(body_root != null, "Ara scene root is not Node3D: " + asset_path)
    actor_root.add_child(body_root)
    await process_frame

    var skeleton := _find_skeleton(body_root)
    assert(skeleton != null, "No Skeleton3D in " + asset_path)
    var meshes: Array[MeshInstance3D] = []
    _collect_skinned_meshes(body_root, meshes)
    assert(not meshes.is_empty(), "No skinned mesh in " + asset_path)
    for mesh in meshes:
        mesh.set_skeleton_path(mesh.get_path_to(skeleton))
        mesh.set_skin(mesh.skin)
    await process_frame
    await process_frame

    var target_mesh: MeshInstance3D
    var target_surface := -1
    var triangle := PackedInt32Array()
    for mesh in meshes:
        for surface_index in range(mesh.mesh.get_surface_count()):
            var arrays := mesh.mesh.surface_get_arrays(surface_index)
            var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
            var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
            if bones.is_empty() or weights.is_empty() or vertices.is_empty():
                continue
            var candidates: Array[PackedInt32Array] = []
            if indices.size() >= 3:
                for offset in range(0, indices.size() - 2, 3):
                    candidates.append(PackedInt32Array([indices[offset], indices[offset + 1], indices[offset + 2]]))
            else:
                for offset in range(0, vertices.size() - 2, 3):
                    candidates.append(PackedInt32Array([offset, offset + 1, offset + 2]))
            for candidate in candidates:
                var valid := true
                for vertex_index in candidate:
                    if vertex_index < 0 or vertex_index >= vertices.size():
                        valid = false
                        break
                    var total_weight := 0.0
                    var influences := bones.size() / vertices.size()
                    for influence in range(influences):
                        total_weight += weights[vertex_index * influences + influence]
                    if total_weight <= 0.00001:
                        valid = false
                        break
                if not valid:
                    continue
                var area := (vertices[candidate[1]] - vertices[candidate[0]]).cross(vertices[candidate[2]] - vertices[candidate[0]]).length()
                if area <= 0.000001:
                    continue
                target_mesh = mesh
                target_surface = surface_index
                triangle = candidate
                break
            if target_mesh != null:
                break
        if target_mesh != null:
            break
    assert(target_mesh != null, "No valid skinned triangle found in " + asset_path)

    var landmark := CharacterSurfaceLandmark.new()
    landmark.body_asset_path = asset_path
    landmark.mesh_node_path = body_root.get_path_to(target_mesh)
    landmark.surface_index = target_surface
    landmark.surface_name = target_mesh.mesh.surface_get_name(target_surface)
    landmark.vertex_count = target_mesh.mesh.surface_get_arrays(target_surface)[Mesh.ARRAY_VERTEX].size()
    landmark.surface_signature = CharacterSurfaceRegionMask.build_surface_signature(target_mesh.mesh, target_surface)
    landmark.landmark_id = "sternum"
    landmark.triangle_indices = triangle
    landmark.barycentric = PackedFloat32Array([0.2, 0.3, 0.5])
    landmark.tangent_edge = 0

    assert(landmark.validate_for_mesh(target_mesh, body_root, asset_path).is_empty(),
        "Valid surface landmark rejected for " + asset_path)
    var regions := CharacterSurfaceRegions.new()
    assert(regions.configure(actor_root, body_root), "Surface-region setup failed: " + regions.get_configuration_error())
    var evaluated := landmark.evaluate(regions)
    assert(not evaluated.is_empty(), "Surface landmark failed to evaluate for " + asset_path)
    # The kiss solver uses these three independent points rather than a head-bone
    # midpoint. This synthetic contract verifies ID support and surface evaluation;
    # real upper/lower lip points must still be authored on each native face.
    for lip_id in ["upper_lip", "lower_lip", "mouth_centre"]:
        var lip_landmark := landmark.duplicate() as CharacterSurfaceLandmark
        lip_landmark.landmark_id = lip_id
        assert(lip_landmark.validate_for_mesh(target_mesh, body_root, asset_path).is_empty(),
            "Lip landmark ID rejected: " + lip_id)
        var lip_sample := lip_landmark.evaluate(regions)
        assert(not lip_sample.is_empty() and lip_sample["position"].is_finite(),
            "Lip landmark surface evaluation failed: " + lip_id)
    for key in ["position", "normal", "tangent", "binormal"]:
        var vector: Vector3 = evaluated[key]
        assert(vector.is_finite(), "Non-finite landmark " + key)
    assert(evaluated["normal"].length() > 0.99, "Landmark normal is not normalised")
    assert(evaluated["tangent"].length() > 0.99, "Landmark tangent is not normalised")
    assert(evaluated["binormal"].length() > 0.99, "Landmark binormal is not normalised")
    var frame: Transform3D = evaluated["frame"]
    assert(frame.origin.is_finite() and frame.basis.x.is_finite() and frame.basis.y.is_finite() and frame.basis.z.is_finite(),
        "Landmark frame is invalid")

    var contact_path := CharacterSurfaceContactPath.new()
    contact_path.body_asset_path = asset_path
    contact_path.mesh_node_path = body_root.get_path_to(target_mesh)
    contact_path.surface_index = target_surface
    contact_path.surface_name = target_mesh.mesh.surface_get_name(target_surface)
    contact_path.vertex_count = target_mesh.mesh.surface_get_arrays(target_surface)[Mesh.ARRAY_VERTEX].size()
    contact_path.surface_signature = CharacterSurfaceRegionMask.build_surface_signature(target_mesh.mesh, target_surface)
    contact_path.path_id = "test_fingertip_trace"
    contact_path.points = [
        {"triangle_indices": triangle, "barycentric": PackedFloat32Array([0.8, 0.1, 0.1])},
        {"triangle_indices": triangle, "barycentric": PackedFloat32Array([0.1, 0.8, 0.1])},
        {"triangle_indices": triangle, "barycentric": PackedFloat32Array([0.1, 0.1, 0.8])}
    ]
    assert(contact_path.validate_for_mesh(target_mesh, body_root, asset_path).is_empty(),
        "Valid contact path rejected for " + asset_path)
    var evaluated_path := contact_path.evaluate(regions)
    assert(evaluated_path.size() == 3, "Contact path did not evaluate all control points: " + contact_path.last_evaluation_error)
    for path_point in evaluated_path:
        assert(path_point["position"].is_finite() and path_point["normal"].is_finite(),
            "Contact path returned a non-finite surface sample")
        var path_frame: Transform3D = path_point["frame"]
        assert(path_frame.basis.x.is_finite() and path_frame.basis.y.is_finite() and path_frame.basis.z.is_finite(),
            "Contact path returned a non-finite local frame")

    var dense_path := contact_path.evaluate_surface_path(regions)
    assert(dense_path.size() >= 3,
        "Surface-following contact route did not include a dense route: " + contact_path.last_evaluation_error)
    var dense_control_points := 0
    for path_sample in dense_path:
        assert(path_sample["position"].is_finite() and path_sample["normal"].is_finite(),
            "Dense contact route returned a non-finite surface sample")
        var dense_frame: Transform3D = path_sample["frame"]
        assert(dense_frame.basis.x.is_finite() and dense_frame.basis.y.is_finite() and dense_frame.basis.z.is_finite(),
            "Dense contact route returned a non-finite local frame")
        if path_sample.get("is_control_point", false):
            dense_control_points += 1
    assert(dense_control_points == 3, "Dense contact route lost authored control points")

    var closed_path := contact_path.duplicate(true) as CharacterSurfaceContactPath
    closed_path.closed_loop = true
    var closed_samples := closed_path.evaluate_surface_path(regions)
    assert(closed_samples.size() >= 4,
        "Closed surface contact route failed: " + closed_path.last_evaluation_error)
    var first_closed_position: Vector3 = closed_samples[0]["position"]
    var last_closed_position: Vector3 = closed_samples[-1]["position"]
    assert(first_closed_position.distance_to(last_closed_position) < 0.0001,
        "Closed surface contact route did not return to its exact starting anchor")

    var stale := landmark.duplicate() as CharacterSurfaceLandmark
    stale.surface_signature = "stale-topology"
    assert(stale.validate_for_mesh(target_mesh, body_root, asset_path).contains("signature mismatch"),
        "Stale surface landmark topology was not rejected")
    var invalid := landmark.duplicate() as CharacterSurfaceLandmark
    invalid.barycentric = PackedFloat32Array([0.2, 0.3, 0.6])
    assert(invalid.validate_for_mesh(target_mesh, body_root, asset_path).contains("sum to 1"),
        "Invalid barycentric weights were not rejected")

    print("ARA_SURFACE_LANDMARK_BODY: PASS asset=%s mesh=%s surface=%d vertices=%d" % [
        asset_path, target_mesh.name, target_surface, landmark.vertex_count
    ])
    actor_root.queue_free()
    await process_frame


func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null


func _collect_skinned_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        var mesh := node as MeshInstance3D
        if mesh.mesh != null and mesh.skin != null:
            output.append(mesh)
    for child in node.get_children():
        _collect_skinned_meshes(child, output)
