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


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await process_frame
    for asset_path in BODY_ASSETS:
        await _test_body(asset_path)
    print("ARA_SURFACE_REGION_POC: PASS")
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

    # Prove that samples follow a changed joint pose, not a static rest-pose cache.
    var arm_bones := regions.get_region_bone_indices("upper_arm_left")
    assert(not arm_bones.is_empty(), "%s has no left upper-arm bone mapping" % asset_path)
    var skeleton := regions.get_skeleton()
    var arm_bone_index := arm_bones[0]
    var original_pose := skeleton.get_bone_pose(arm_bone_index)
    var before_pose := regions.get_region_surface_samples("upper_arm_left", 0.55, 1)
    assert(not before_pose.is_empty(), "No upper-arm sample before pose")
    var before_arm_position: Vector3 = before_pose[0]["position"]
    var changed_pose := original_pose
    changed_pose.basis = Basis(Vector3.UP, 0.35) * original_pose.basis
    skeleton.set_bone_pose(arm_bone_index, changed_pose)
    await process_frame
    var after_pose := regions.get_region_surface_samples("upper_arm_left", 0.55, 1)
    assert(not after_pose.is_empty(), "No upper-arm sample after pose")
    var pose_delta: float = before_arm_position.distance_to(after_pose[0]["position"])
    assert(pose_delta > 0.00001, "%s upper-arm surface did not respond to a joint pose change" % asset_path)
    skeleton.set_bone_pose(arm_bone_index, original_pose)
    await process_frame

    print("ARA_SURFACE_REGION_POC_BODY: PASS asset=%s morph_delta=%.6f pose_delta=%.6f" % [
        asset_path, morph_delta, pose_delta
    ])
    actor_root.queue_free()
    await process_frame


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
