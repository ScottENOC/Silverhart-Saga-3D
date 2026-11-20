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
    for mesh_instance in meshes:
        var mesh := mesh_instance.mesh
        print("ARA_SURFACE_CHANNEL asset=%s mesh=%s surfaces=%d blend_shapes=%d blend_mode=%d skin_binds=%d" % [
            asset_path, mesh_instance.name, mesh.get_surface_count(),
            mesh.get_blend_shape_count(), mesh.blend_shape_mode,
            mesh_instance.skin.get_bind_count() if mesh_instance.skin != null else 0
        ])
        _print_skin_binds(mesh_instance)
        for shape_index in range(mesh.get_blend_shape_count()):
            print("ARA_BLEND_SHAPE asset=%s index=%d name=%s weight=%.3f" % [
                asset_path, shape_index, mesh.get_blend_shape_name(shape_index),
                mesh_instance.get_blend_shape_value(shape_index)
            ])
        for surface_index in range(mesh.get_surface_count()):
            var arrays := mesh.surface_get_arrays(surface_index)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            print("ARA_SURFACE_CHANNEL surface=%d vertices=%d indices=%s normals=%s colors=%s uv1=%s uv2=%s bones=%s weights=%s custom0=%s custom1=%s custom2=%s" % [
                surface_index, vertices.size(),
                _array_summary(arrays[Mesh.ARRAY_INDEX]),
                _array_summary(arrays[Mesh.ARRAY_NORMAL]),
                _array_summary(arrays[Mesh.ARRAY_COLOR]),
                _array_summary(arrays[Mesh.ARRAY_TEX_UV]),
                _array_summary(arrays[Mesh.ARRAY_TEX_UV2]),
                _array_summary(arrays[Mesh.ARRAY_BONES]),
                _array_summary(arrays[Mesh.ARRAY_WEIGHTS]),
                _array_summary(arrays[Mesh.ARRAY_CUSTOM0]),
                _array_summary(arrays[Mesh.ARRAY_CUSTOM1]),
                _array_summary(arrays[Mesh.ARRAY_CUSTOM2])
            ])
            var blend_arrays := mesh.surface_get_blend_shape_arrays(surface_index)
            if surface_index == 0:
                print("ARA_BLEND_SURFACE surface=%d shape_arrays=%d first_shape_vertices=%s first_shape_normals=%s" % [
                    surface_index, blend_arrays.size(),
                    _array_summary(blend_arrays[0][Mesh.ARRAY_VERTEX]) if not blend_arrays.is_empty() else "none",
                    _array_summary(blend_arrays[0][Mesh.ARRAY_NORMAL]) if not blend_arrays.is_empty() else "none"
                ])
    instance.free()


func _print_skin_binds(mesh_instance: MeshInstance3D) -> void:
    var skin := mesh_instance.skin
    var skeleton := mesh_instance.get_node_or_null(mesh_instance.skeleton) as Skeleton3D
    if skin == null or skeleton == null:
        print("ARA_SKIN_BIND_AUDIT missing skin or skeleton")
        return
    for bind_index in range(skin.get_bind_count()):
        var bone_index := skin.get_bind_bone(bind_index)
        var bone_name := skin.get_bind_name(bind_index)
        if bone_name.is_empty() and bone_index >= 0 and bone_index < skeleton.get_bone_count():
            bone_name = skeleton.get_bone_name(bone_index)
        print("ARA_SKIN_BIND index=%d bone_index=%d bone_name=%s" % [
            bind_index, bone_index, bone_name
        ])


func _array_summary(value: Variant) -> String:
    if value is PackedVector2Array:
        return "PackedVector2Array(%d)" % value.size()
    if value is PackedVector3Array:
        return "PackedVector3Array(%d)" % value.size()
    if value is PackedColorArray:
        return "PackedColorArray(%d)" % value.size()
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
