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
    var overlap_id := "sternum"
    var overlap_weights := PackedFloat32Array()
    overlap_weights.resize(target_vertex_count)
    overlap_weights[target_vertex] = 0.65
    mask.region_weights = {region_id: weights, overlap_id: overlap_weights}

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
    assert(regions.has_region(overlap_id, 0.5), "Overlapping fine region was not exposed for " + asset_path)
    var samples := regions.get_region_surface_samples(region_id, 0.5)
    assert(samples.size() == 1, "Expected one synthetic authored sample for %s, got %d" % [asset_path, samples.size()])
    assert(int(samples[0]["vertex_index"]) == target_vertex, "Fine mask sample lost source vertex identity")
    var overlap_samples := regions.get_region_surface_samples(overlap_id, 0.5)
    assert(overlap_samples.size() == 1 and int(overlap_samples[0]["vertex_index"]) == target_vertex,
        "A single source vertex must be queryable through two overlapping anatomical regions")

    # A triangle hit between source vertices must interpolate each independent
    # authored channel. The same point can therefore belong to overlapping regions.
    var surface_arrays := target_mesh.mesh.surface_get_arrays(target_surface)
    var triangle_indices: PackedInt32Array = surface_arrays[Mesh.ARRAY_INDEX]
    var triangle_vertices := PackedInt32Array()
    var target_corner := -1
    for triangle_start in range(0, triangle_indices.size() - 2, 3):
        var candidate := PackedInt32Array([
            triangle_indices[triangle_start],
            triangle_indices[triangle_start + 1],
            triangle_indices[triangle_start + 2]
        ])
        var candidate_corner := candidate.find(target_vertex)
        if candidate_corner >= 0:
            triangle_vertices = candidate
            target_corner = candidate_corner
            break
    assert(triangle_vertices.size() == 3, "Could not find a source triangle containing the synthetic mask vertex")
    var barycentric := PackedFloat32Array([0.25, 0.50, 0.25])
    # Put the painted vertex at a non-unit barycentric coordinate to prove
    # membership is continuous across the triangle rather than a nearest-dot lookup.
    barycentric = PackedFloat32Array([0.0, 0.0, 0.0])
    barycentric[target_corner] = 0.25
    barycentric[(target_corner + 1) % 3] = 0.50
    barycentric[(target_corner + 2) % 3] = 0.25
    var triangle_memberships := regions.get_authored_triangle_region_weights(
        mask.mesh_node_path, target_surface, triangle_vertices, barycentric, 0.10
    )
    assert(is_equal_approx(float(triangle_memberships.get(region_id, 0.0)), 0.25),
        "Fine region weight was not barycentrically interpolated")
    assert(is_equal_approx(float(triangle_memberships.get(overlap_id, 0.0)), 0.1625),
        "Overlapping fine region weight was not preserved during interpolation")
    var vertex_barycentric := PackedFloat32Array([0.0, 0.0, 0.0])
    vertex_barycentric[target_corner] = 1.0
    var conserved_forces := BodyPressureContact.submit_surface_contact(
        pressure_controller,
        regions,
        mask.mesh_node_path,
        target_surface,
        triangle_vertices,
        vertex_barycentric,
        0.10,
        0.0,
        1000.0,
        0.0,
        100.0,
        0.10
    )
    var combined_force := 0.0
    for submitted_force in conserved_forces.values():
        combined_force += float(submitted_force)
    assert(is_equal_approx(combined_force, 100.0),
        "Overlapping memberships must not amplify the physical contact force")

    var invalid_triangle := regions.get_authored_triangle_region_weights(
        mask.mesh_node_path, target_surface, PackedInt32Array([target_vertex, -1, target_vertex]), barycentric
    )
    assert(invalid_triangle.is_empty(), "Invalid source triangle indices must be rejected")

    var pressure_controller := BodyPressureController.new()
    pressure_controller.register_region(StringName(region_id), BodyRegionProfile.new())
    pressure_controller.register_region(StringName(overlap_id), BodyRegionProfile.new())
    var submitted_forces := BodyPressureContact.submit_surface_contact(
        pressure_controller,
        regions,
        mask.mesh_node_path,
        target_surface,
        triangle_vertices,
        barycentric,
        0.10,
        0.0,
        1000.0,
        0.0,
        100.0,
        0.10
    )
    assert(is_equal_approx(float(submitted_forces.get(region_id, 0.0)), 25.0),
        "Contact force was not weighted by the first interpolated region membership")
    assert(is_equal_approx(float(submitted_forces.get(overlap_id, 0.0)), 16.25),
        "Contact force did not preserve the overlapping region membership")

    # Clothing may be in light contact without compressing the body. Its
    # transient damping must still be mapped across the same overlapping regions.
    var garment_damping_regions := BodyPressureContact.submit_surface_contact(
        pressure_controller,
        regions,
        mask.mesh_node_path,
        target_surface,
        triangle_vertices,
        vertex_barycentric,
        0.0,
        0.0,
        0.0,
        0.0,
        100.0,
        0.10,
        120.0
    )
    assert(garment_damping_regions.has(region_id) and garment_damping_regions.has(overlap_id),
        "Garment-only damping must reach all overlapping registered anatomy regions")
    assert(is_equal_approx(float(garment_damping_regions[region_id]), 0.0)
        and is_equal_approx(float(garment_damping_regions[overlap_id]), 0.0),
        "Damping-only garment contact must not add compression force")

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
