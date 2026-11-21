extends SceneTree

const BODY_ASSETS := [
    "res://build/wren-native/Wren.glb",
    "res://build/aldric-native/Aldric.glb"
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await process_frame
    for asset_path in BODY_ASSETS:
        await _test_mask_contract(asset_path)
    print("WREN_ALDRIC_FINE_SURFACE_MASK_CONTRACT: PASS")
    quit(0)


func _test_mask_contract(asset_path: String) -> void:
    var packed := load(asset_path) as PackedScene
    assert(packed != null, "Could not load " + asset_path)
    var actor_root := Node3D.new()
    root.add_child(actor_root)
    var body_root := packed.instantiate() as Node3D
    assert(body_root != null, "Ara scene root is not Node3D: " + asset_path)
    actor_root.add_child(body_root)
    await process_frame

    var target_mesh: MeshInstance3D
    var target_surface := -1
    var target_vertex_count := 0
    var target_vertex := -1
    var meshes: Array[MeshInstance3D] = []
    _collect_skinned_meshes(body_root, meshes)
    for mesh_instance in meshes:
        var array_mesh := mesh_instance.mesh as ArrayMesh
        for surface_index in range(array_mesh.get_surface_count()):
            var arrays := array_mesh.surface_get_arrays(surface_index)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
            var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
            if vertices.is_empty() or bones.is_empty() or weights.is_empty():
                continue
            var influences_per_vertex := bones.size() / vertices.size()
            for vertex_index in range(vertices.size()):
                var total_weight := 0.0
                for influence_index in range(influences_per_vertex):
                    total_weight += weights[vertex_index * influences_per_vertex + influence_index]
                if total_weight > 0.0:
                    target_mesh = mesh_instance
                    target_surface = surface_index
                    target_vertex_count = vertices.size()
                    target_vertex = vertex_index
                    break
            if target_mesh != null:
                break
        if target_mesh != null:
            break

    assert(target_mesh != null and target_vertex >= 0, "No weighted source vertex found in " + asset_path)
    var region_id := "breast_left" if asset_path.ends_with("/Wren.glb") else "pectoral_left"
    var mask := CharacterSurfaceRegionMask.new()
    mask.body_asset_path = asset_path
    mask.mesh_node_path = body_root.get_path_to(target_mesh)
    mask.surface_index = target_surface
    mask.surface_name = target_mesh.mesh.surface_get_name(target_surface)
    mask.vertex_count = target_vertex_count
    mask.surface_signature = CharacterSurfaceRegionMask.build_surface_signature(target_mesh.mesh, target_surface)
    var weights := PackedFloat32Array()
    weights.resize(target_vertex_count)
    weights[target_vertex] = 1.0
    mask.region_weights = {region_id: weights}

    assert(mask.validate_for_mesh(target_mesh, body_root, asset_path).is_empty(),
        "Valid synthetic mask was rejected for " + asset_path)

    var stale_count := mask.duplicate() as CharacterSurfaceRegionMask
    stale_count.vertex_count += 1
    assert(stale_count.validate_for_mesh(target_mesh, body_root, asset_path).contains("vertex count mismatch"),
        "Stale vertex count was not rejected for " + asset_path)

    var stale_signature := mask.duplicate() as CharacterSurfaceRegionMask
    stale_signature.surface_signature = "stale-topology"
    assert(stale_signature.validate_for_mesh(target_mesh, body_root, asset_path).contains("signature mismatch"),
        "Stale topology signature was not rejected for " + asset_path)

    var wrong_body := mask.duplicate() as CharacterSurfaceRegionMask
    wrong_body.body_asset_path = "res://wrong_body.glb"
    assert(wrong_body.validate_for_mesh(target_mesh, body_root, asset_path).contains("body asset mismatch"),
        "Wrong body asset was not rejected for " + asset_path)

    var regions := CharacterSurfaceRegions.new()
    assert(regions.configure(actor_root, body_root, [mask], asset_path),
        "Fine mask configuration failed for %s: %s" % [asset_path, regions.get_configuration_error()])
    assert(regions.has_region(region_id, 0.5), "Authored fine region was not exposed for " + asset_path)
    var samples := regions.get_region_surface_samples(region_id, 0.5)
    assert(samples.size() == 1, "Expected one synthetic authored sample for %s, got %d" % [asset_path, samples.size()])
    assert(int(samples[0]["vertex_index"]) == target_vertex, "Fine mask sample lost source vertex identity")

    var invalid_regions := CharacterSurfaceRegions.new()
    assert(not invalid_regions.configure(actor_root, body_root, [stale_signature], asset_path),
        "Runtime accepted stale fine mask for " + asset_path)
    assert(invalid_regions.get_configuration_error().contains("signature mismatch"),
        "Runtime did not report stale fine mask reason")
    print("COMPANION_FINE_SURFACE_MASK_BODY: PASS asset=%s region=%s mesh=%s surface=%d vertices=%d sample_vertex=%d" % [
        asset_path, region_id, target_mesh.name, target_surface, target_vertex_count, target_vertex
    ])
    actor_root.queue_free()
    await process_frame


func _collect_skinned_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null and mesh_instance.skin != null:
            output.append(mesh_instance)
    for child in node.get_children():
        _collect_skinned_meshes(child, output)
