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
        _inspect_body_asset(asset_path)
    print("ARA_SURFACE_CHANNEL_AUDIT: COMPLETE")
    quit(0)


func _inspect_body_asset(asset_path: String) -> void:
    var packed := load(asset_path) as PackedScene
    assert(packed != null, "Could not load Ara body asset: " + asset_path)
    var instance := packed.instantiate()
    var meshes: Array[MeshInstance3D] = []
    _collect_skinned_meshes(instance, meshes)
    assert(not meshes.is_empty(), "No skinned meshes found in " + asset_path)
    var body_meshes := 0
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        body_meshes += 1
        var mesh := mesh_instance.mesh
        print("ARA_SURFACE_CHANNEL asset=%s mesh=%s surfaces=%d blend_shapes=%d skin_binds=%d" % [
            asset_path, mesh_instance.name, mesh.get_surface_count(),
            mesh.get_blend_shape_count(),
            mesh_instance.skin.get_bind_count() if mesh_instance.skin != null else 0
        ])
        for surface_index in range(mesh.get_surface_count()):
            var arrays := mesh.surface_get_arrays(surface_index)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var uv1 = arrays[Mesh.ARRAY_TEX_UV]
            var uv2 = arrays[Mesh.ARRAY_TEX_UV2]
            var bones = arrays[Mesh.ARRAY_BONES]
            var weights = arrays[Mesh.ARRAY_WEIGHTS]
            print("ARA_SURFACE_CHANNEL surface=%d vertices=%d uv1=%s uv2=%s bones=%s weights=%s" % [
                surface_index, vertices.size(),
                _array_summary(uv1), _array_summary(uv2),
                _array_summary(bones), _array_summary(weights)
            ])
    assert(body_meshes > 0, "No mesh surfaces inspected for " + asset_path)
    instance.free()


func _array_summary(value: Variant) -> String:
    if value is PackedVector2Array:
        return "PackedVector2Array(%d)" % value.size()
    if value is PackedVector3Array:
        return "PackedVector3Array(%d)" % value.size()
    if value is PackedInt32Array:
        return "PackedInt32Array(%d)" % value.size()
    if value is PackedFloat32Array:
        return "PackedFloat32Array(%d)" % value.size()
    return type_string(typeof(value))


func _collect_skinned_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.skin != null and mesh_instance.mesh != null:
            output.append(mesh_instance)
    for child in node.get_children():
        _collect_skinned_meshes(child, output)
