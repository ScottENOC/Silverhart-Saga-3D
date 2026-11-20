extends SceneTree

const BODY_ASSETS := [
    "res://art/characters/ara_runtime/ara_person_body_anatomy.glb",
    "res://art/characters/ara_runtime/ara_person_male_body.glb"
]
const AUDIT_REGIONS := ["chest", "abdomen", "pelvis"]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await process_frame
    for asset_path in BODY_ASSETS:
        await _audit_body(asset_path)
    print("ARA_FINE_SURFACE_GEOMETRY_AUDIT: COMPLETE")
    quit(0)


func _audit_body(asset_path: String) -> void:
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
    print("ARA_FINE_SURFACE_BODY asset=%s scale=%s" % [asset_path, body_root.global_transform.basis.get_scale()])

    for region_id in AUDIT_REGIONS:
        var samples := regions.get_region_surface_samples(region_id, 0.25, 0)
        assert(not samples.is_empty(), "%s has no samples for %s" % [asset_path, region_id])
        var minimum := Vector3(INF, INF, INF)
        var maximum := Vector3(-INF, -INF, -INF)
        var position_sum := Vector3.ZERO
        var normal_sum := Vector3.ZERO
        var positive_z := 0
        var negative_z := 0
        var positive_x := 0
        var negative_x := 0
        var surface_counts: Dictionary = {}
        for sample in samples:
            var position: Vector3 = sample["position"]
            var normal: Vector3 = sample["normal"].normalized()
            minimum.x = minf(minimum.x, position.x)
            minimum.y = minf(minimum.y, position.y)
            minimum.z = minf(minimum.z, position.z)
            maximum.x = maxf(maximum.x, position.x)
            maximum.y = maxf(maximum.y, position.y)
            maximum.z = maxf(maximum.z, position.z)
            position_sum += position
            normal_sum += normal
            positive_z += 1 if normal.z > 0.5 else 0
            negative_z += 1 if normal.z < -0.5 else 0
            positive_x += 1 if normal.x > 0.5 else 0
            negative_x += 1 if normal.x < -0.5 else 0
            var surface_key := "%s:%d" % [sample["mesh_instance"].name, sample["surface_index"]]
            surface_counts[surface_key] = int(surface_counts.get(surface_key, 0)) + 1

        var count := samples.size()
        var average_normal := (normal_sum / float(count)).normalized()
        print("ARA_FINE_SURFACE_REGION asset=%s region=%s vertices=%d min=%s max=%s centre=%s avg_normal=%s normal_z_front=%d normal_z_back=%d normal_x_pos=%d normal_x_neg=%d surfaces=%s" % [
            asset_path, region_id, count, minimum, maximum,
            position_sum / float(count), average_normal,
            positive_z, negative_z, positive_x, negative_x, JSON.stringify(surface_counts)
        ])

    actor_root.queue_free()
    await process_frame
