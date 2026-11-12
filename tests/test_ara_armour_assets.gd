extends SceneTree
## Import smoke test for the first-pass standalone shield and helmet GLBs.
## These are not approved fit assets and are not attached to characters yet.

const PROP_IDS := [
    "round_shield", "kite_shield", "heater_shield",
    "nasal_helm", "kettle_hat", "great_helm", "bascinet"
]

func _initialize() -> void:
    for prop_id in PROP_IDS:
        var path := "res://art/characters/ara_runtime/props/%s.glb" % prop_id
        assert(ResourceLoader.exists(path), "Missing medieval armour prop: %s" % path)
        var packed := load(path) as PackedScene
        assert(packed != null, "Armour GLB did not import as a PackedScene: %s" % path)
        var instance := packed.instantiate()
        var meshes: Array[MeshInstance3D] = []
        _collect_meshes(instance, meshes)
        assert(not meshes.is_empty(), "Armour prop has no meshes: %s" % prop_id)
        if prop_id.ends_with("_shield"):
            var has_heraldry_face := false
            for mesh_instance in meshes:
                if mesh_instance.mesh == null:
                    continue
                for surface in range(mesh_instance.mesh.get_surface_count()):
                    var surface_material := mesh_instance.get_active_material(surface)
                    if surface_material != null and surface_material.resource_name.to_lower().replace(" ", "").contains("heraldryface"):
                        has_heraldry_face = true
                        var arrays := mesh_instance.mesh.surface_get_arrays(surface)
                        var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
                        assert(not uvs.is_empty(), "Shield heraldry face has no UV coordinates: %s" % prop_id)
            assert(has_heraldry_face, "Shield has no dedicated HeraldryFace surface: %s" % prop_id)
        instance.free()
    print("ARA_ARMOUR_ASSET_TEST: PASS (%d blockout props)" % PROP_IDS.size())
    quit(0)

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)
