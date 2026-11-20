extends SceneTree

const BODY_ASSETS := [
    "res://art/characters/ara_runtime/ara_person_body_anatomy.glb",
    "res://art/characters/ara_runtime/ara_person_male_body.glb"
]
const REQUIRED_REGIONS := [
    "head", "neck", "chest", "abdomen", "pelvis",
    "upper_arm_left", "upper_arm_right",
    "forearm_left", "forearm_right",
    "thigh_left", "thigh_right",
    "calf_left", "calf_right",
    "foot_left", "foot_right"
]
const POSITION_TOLERANCE := 0.0005
const NORMAL_DOT_TOLERANCE := 0.995


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await process_frame
    for asset_path in BODY_ASSETS:
        await _test_body(asset_path)
    print("ARA_SURFACE_REGION_POC: TEST SCRIPT FINISHED; CI log checker determines success")
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
    var skinned_meshes: Array[MeshInstance3D] = []
    _collect_skinned_meshes(body_root, skinned_meshes)
    assert(not skinned_meshes.is_empty(), "No skinned meshes in " + asset_path)

    # Godot 4.6 changed the default MeshInstance3D skeleton path to empty.
    # GLB instances may therefore have a Skin resource but no registered
    # SkinReference in a headless test. Explicitly bind every imported mesh.
    for mesh_instance in skinned_meshes:
        mesh_instance.set_skeleton_path(mesh_instance.get_path_to(skeleton))
        mesh_instance.set_skin(mesh_instance.skin)
    await process_frame
    await process_frame

    for mesh_instance in skinned_meshes:
        var skin_reference := mesh_instance.get_skin_reference()
        print("ARA_SKIN_BIND mesh=%s inside_tree=%s skeleton_path=%s resolved=%s skeleton_inside_tree=%s skin_resource=%s skin_ref=%s skin_rid_valid=%s bone_count=%d" % [mesh_instance.get_path(), mesh_instance.is_inside_tree(), mesh_instance.get_skeleton_path(), mesh_instance.get_node_or_null(mesh_instance.get_skeleton_path()), skeleton.is_inside_tree(), mesh_instance.skin, skin_reference, skin_reference.get_skeleton().is_valid() if skin_reference != null else false, skeleton.get_bone_count()])
        assert(skin_reference != null, "%s has no registered SkinReference on %s (skeleton path: %s)" % [
            asset_path, mesh_instance.name, mesh_instance.skeleton
        ])
        assert(skin_reference.get_skeleton().is_valid(), "%s SkinReference has invalid skeleton RID on %s" % [
            asset_path, mesh_instance.name
        ])

    var regions := CharacterSurfaceRegions.new()
    assert(regions.configure(actor_root, body_root), "%s: %s" % [asset_path, regions.get_configuration_error()])
    var available := regions.available_regions(0.25)
    print("ARA_SURFACE_REGIONS asset=%s available=%s" % [asset_path, ",".join(available)])
    for region_id in REQUIRED_REGIONS:
        assert(regions.has_region(region_id, 0.25), "%s missing broad region %s" % [asset_path, region_id])
        var samples := regions.get_region_surface_samples(region_id, 0.35, 24)
        assert(not samples.is_empty(), "%s returned no samples for %s" % [asset_path, region_id])
        for sample in samples:
            var position: Vector3 = sample["position"]
            var normal: Vector3 = sample["normal"]
            assert(position.is_finite(), "%s %s has non-finite position" % [asset_path, region_id])
            assert(normal.is_finite() and normal.length() > 0.5, "%s %s has invalid normal" % [asset_path, region_id])

    # The male Ara GLB currently has body morphs; the female GLB currently has
    # facial morphs only. Do not invent female body morph support in this test.
    var main_mesh := _largest_skinned_mesh(body_root)
    assert(main_mesh != null, "No skinned mesh found in " + asset_path)
    var morph_index := _find_morph(main_mesh.mesh, ["body_muscle", "body_proportions", "body_weight"])
    var morph_delta := 0.0
    if morph_index >= 0:
        var before_morph := regions.get_region_surface_samples("chest", 0.35, 32)
        assert(not before_morph.is_empty(), "No chest sample before morph")
        main_mesh.set_blend_shape_value(morph_index, 0.5)
        await process_frame
        var after_morph := regions.get_region_surface_samples("chest", 0.35, 32)
        morph_delta = _maximum_sample_delta(before_morph, after_morph)
        assert(morph_delta > 0.00001, "%s chest surface did not respond to %s" % [
            asset_path, main_mesh.mesh.get_blend_shape_name(morph_index)
        ])
        main_mesh.set_blend_shape_value(morph_index, 0.0)
        print("ARA_SURFACE_REGION_MORPH asset=%s shape=%s delta=%.6f" % [
            asset_path, main_mesh.mesh.get_blend_shape_name(morph_index), morph_delta
        ])
    else:
        assert(asset_path.contains("ara_person_body_anatomy"), "Unexpected absence of body morphs in " + asset_path)
        var before_scale := regions.get_region_surface_samples("chest", 0.35, 32)
        body_root.scale.y *= 1.05
        await process_frame
        var after_scale := regions.get_region_surface_samples("chest", 0.35, 32)
        morph_delta = _maximum_sample_delta(before_scale, after_scale)
        assert(morph_delta > 0.00001, "Female chest surface did not respond to body-root stature scaling")
        body_root.scale.y /= 1.05
        print("ARA_SURFACE_REGION_NO_BODY_MORPHS asset=%s stature_scale_delta=%.6f" % [asset_path, morph_delta])
    await process_frame

    # Change a real joint pose, then compare our evaluator against Godot's
    # RenderingServer-backed baked mesh output. The bake API ignores blend
    # shapes, so all blend-shape weights are reset before this comparison.
    var arm_bones := regions.get_region_bone_indices("upper_arm_left")
    assert(not arm_bones.is_empty(), "%s has no left upper-arm bone mapping" % asset_path)
    var arm_bone_index := arm_bones[0]
    var original_pose := skeleton.get_bone_pose(arm_bone_index)
    var changed_pose := original_pose
    changed_pose.basis = Basis(Vector3.UP, 0.35) * original_pose.basis
    skeleton.set_bone_pose(arm_bone_index, changed_pose)
    await process_frame
    for mesh_instance in skinned_meshes:
        for shape_index in range(mesh_instance.get_blend_shape_count()):
            mesh_instance.set_blend_shape_value(shape_index, 0.0)
    await process_frame

    var baked_meshes: Dictionary = {}
    for mesh_instance in skinned_meshes:
        var baked := mesh_instance.bake_mesh_from_current_skeleton_pose()
        assert(baked != null, "%s Godot bake returned null for %s" % [asset_path, mesh_instance.name])
        baked_meshes[mesh_instance.get_instance_id()] = baked

    var total_position_checks := 0
    var worst_position_error := 0.0
    var minimum_normal_dot := 1.0
    for region_id in ["head", "chest", "abdomen", "pelvis", "upper_arm_left", "forearm_left", "thigh_left"]:
        var samples := regions.get_region_surface_samples(region_id, 0.35, 12)
        for sample in samples:
            var mesh_instance: MeshInstance3D = sample["mesh_instance"]
            var surface_index: int = sample["surface_index"]
            var vertex_index: int = sample["vertex_index"]
            var baked: ArrayMesh = baked_meshes[mesh_instance.get_instance_id()]
            assert(surface_index < baked.get_surface_count(), "Baked surface missing: %s surface %d" % [mesh_instance.name, surface_index])
            var baked_arrays := baked.surface_get_arrays(surface_index)
            var baked_vertices: PackedVector3Array = baked_arrays[Mesh.ARRAY_VERTEX]
            var baked_normals: PackedVector3Array = baked_arrays[Mesh.ARRAY_NORMAL]
            assert(vertex_index < baked_vertices.size(), "Baked vertex missing: %s surface %d vertex %d" % [
                mesh_instance.name, surface_index, vertex_index
            ])
            var expected_position: Vector3 = mesh_instance.global_transform.affine_inverse() * actor_root.global_transform * sample["position"]
            var actual_position := baked_vertices[vertex_index]
            var position_error := expected_position.distance_to(actual_position)
            worst_position_error = maxf(worst_position_error, position_error)
            assert(position_error <= POSITION_TOLERANCE, "%s %s surface %d vertex %d position mismatch %.8f m" % [
                asset_path, region_id, surface_index, vertex_index, position_error
            ])

            assert(vertex_index < baked_normals.size(), "Baked normal missing: %s surface %d vertex %d" % [
                mesh_instance.name, surface_index, vertex_index
            ])
            var expected_normal: Vector3 = (
                mesh_instance.global_transform.basis.transposed()
                * actor_root.global_transform.basis
                * sample["normal"]
            ).normalized()
            var actual_normal: Vector3 = baked_normals[vertex_index].normalized()
            var normal_dot := expected_normal.dot(actual_normal)
            minimum_normal_dot = minf(minimum_normal_dot, normal_dot)
            assert(normal_dot >= NORMAL_DOT_TOLERANCE, "%s %s surface %d vertex %d normal dot %.6f" % [
                asset_path, region_id, surface_index, vertex_index, normal_dot
            ])
            total_position_checks += 1

    assert(total_position_checks >= 20, "%s had too few engine-bake comparison points: %d" % [asset_path, total_position_checks])
    baked_meshes.clear()
    skeleton.set_bone_pose(arm_bone_index, original_pose)
    await process_frame

    print("ARA_SURFACE_REGION_ENGINE_BAKE: PASS asset=%s checks=%d worst_position_error=%.8f minimum_normal_dot=%.6f" % [
        asset_path, total_position_checks, worst_position_error, minimum_normal_dot
    ])
    print("ARA_SURFACE_REGION_POC_BODY: PASS asset=%s morph_delta=%.6f" % [asset_path, morph_delta])
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


func _largest_skinned_mesh(node: Node) -> MeshInstance3D:
    var candidates: Array[MeshInstance3D] = []
    _collect_skinned_meshes(node, candidates)
    var best: MeshInstance3D
    var best_vertices := -1
    for candidate in candidates:
        var count: int = candidate.mesh.surface_get_array_len(0) if candidate.mesh.get_surface_count() > 0 else 0
        if count > best_vertices:
            best_vertices = count
            best = candidate
    return best


func _find_morph(mesh: Mesh, preferred: Array[String]) -> int:
    for requested in preferred:
        for index in range(mesh.get_blend_shape_count()):
            if String(mesh.get_blend_shape_name(index)).to_lower() == requested:
                return index
    return -1


func _collect_skinned_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null and mesh_instance.skin != null:
            output.append(mesh_instance)
    for child in node.get_children():
        _collect_skinned_meshes(child, output)


func _maximum_sample_delta(before: Array[Dictionary], after: Array[Dictionary]) -> float:
    var after_by_vertex: Dictionary = {}
    for sample in after:
        var key := "%d:%d:%d" % [sample["mesh_instance"].get_instance_id(), sample["surface_index"], sample["vertex_index"]]
        after_by_vertex[key] = sample["position"]
    var maximum := 0.0
    for sample in before:
        var key := "%d:%d:%d" % [sample["mesh_instance"].get_instance_id(), sample["surface_index"], sample["vertex_index"]]
        if not after_by_vertex.has(key):
            continue
        var before_position: Vector3 = sample["position"]
        var after_position: Vector3 = after_by_vertex[key]
        maximum = maxf(maximum, before_position.distance_to(after_position))
    return maximum
