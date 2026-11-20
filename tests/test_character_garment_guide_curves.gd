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
    print("ARA_GARMENT_GUIDE_CURVE_CONTRACT: PASS")
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
            var influences_per_vertex := bones.size() / vertices.size()
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
                    for influence in range(influences_per_vertex):
                        total_weight += weights[vertex_index * influences_per_vertex + influence]
                    if total_weight <= 0.00001:
                        valid = false
                        break
                if not valid:
                    continue
                var area := (vertices[candidate[1]] - vertices[candidate[0]]).cross(vertices[candidate[2]] - vertices[candidate[0]]).length()
                if area <= 0.000001:
                    continue
                triangle = candidate
                target_mesh = mesh
                target_surface = surface_index
                break
            if target_mesh != null:
                break
        if target_mesh != null:
            break
    assert(target_mesh != null, "No triangle surface found in " + asset_path)

    var curve := CharacterGarmentGuideCurve.new()
    curve.body_asset_path = asset_path
    curve.mesh_node_path = body_root.get_path_to(target_mesh)
    curve.surface_index = target_surface
    curve.surface_name = target_mesh.mesh.surface_get_name(target_surface)
    curve.vertex_count = target_mesh.mesh.surface_get_arrays(target_surface)[Mesh.ARRAY_VERTEX].size()
    curve.surface_signature = CharacterSurfaceRegionMask.build_surface_signature(target_mesh.mesh, target_surface)
    curve.guide_id = "neckline"
    curve.closed_loop = true
    curve.points = [
        {"triangle_indices": triangle, "barycentric": PackedFloat32Array([1.0, 0.0, 0.0])},
        {"triangle_indices": triangle, "barycentric": PackedFloat32Array([0.0, 1.0, 0.0])},
        {"triangle_indices": triangle, "barycentric": PackedFloat32Array([0.0, 0.0, 1.0])}
    ]
    assert(curve.validate_for_mesh(target_mesh, body_root, asset_path).is_empty(),
        "Valid guide curve was rejected for %s" % asset_path)

    var regions := CharacterSurfaceRegions.new()
    assert(regions.configure(actor_root, body_root), "Surface region setup failed: " + regions.get_configuration_error())
    var evaluated := curve.evaluate(regions)
    assert(evaluated.size() == 3, "Expected three evaluated guide points for " + asset_path)
    for point in evaluated:
        var position: Vector3 = point["position"]
        var normal: Vector3 = point["normal"]
        var tangent: Vector3 = point["tangent"]
        var binormal: Vector3 = point["binormal"]
        assert(position.is_finite(), "Guide point position is non-finite")
        assert(normal.is_finite() and normal.length() > 0.5, "Guide point normal is invalid")
        assert(tangent.is_finite() and tangent.length() > 0.5, "Guide point tangent is invalid")
        assert(binormal.is_finite() and binormal.length() > 0.5, "Guide point binormal is invalid")
        var frame: Transform3D = point["frame"]
        assert(frame.origin.is_finite(), "Guide frame origin is non-finite")
        assert(frame.basis.x.is_finite() and frame.basis.y.is_finite() and frame.basis.z.is_finite(),
            "Guide frame basis is non-finite")

    var stale := curve.duplicate() as CharacterGarmentGuideCurve
    stale.surface_signature = "stale-topology"
    assert(stale.validate_for_mesh(target_mesh, body_root, asset_path).contains("signature mismatch"),
        "Stale guide topology was not rejected")
    var invalid_barycentric := curve.duplicate() as CharacterGarmentGuideCurve
    invalid_barycentric.points = curve.points.duplicate(true)
    invalid_barycentric.points[0]["barycentric"] = PackedFloat32Array([0.5, 0.5, 0.5])
    assert(invalid_barycentric.validate_for_mesh(target_mesh, body_root, asset_path).contains("sum to 1"),
        "Invalid barycentric weights were not rejected")

    print("ARA_GARMENT_GUIDE_BODY: PASS asset=%s mesh=%s surface=%d vertices=%d" % [
        asset_path, target_mesh.name, target_surface, curve.vertex_count
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
