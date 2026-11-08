extends SceneTree
## Loads the separate Ara medieval prop GLBs produced by the optional asset build.
## The assets are grip-origin props; runtime attachment is validated separately.

const PROP_IDS := ["sword", "knife", "axe", "spear", "bow", "mace", "club"]

func _initialize() -> void:
    for prop_id in PROP_IDS:
        var path := "res://art/characters/ara_runtime/props/%s.glb" % prop_id
        assert(ResourceLoader.exists(path), "Missing Ara equipment prop: %s" % path)
        var packed := load(path) as PackedScene
        assert(packed != null, "Ara equipment GLB did not import as a PackedScene: %s" % path)
        var instance := packed.instantiate()
        assert(instance != null, "Ara equipment scene could not be instantiated: %s" % prop_id)
        var meshes: Array[MeshInstance3D] = []
        _collect_meshes(instance, meshes)
        assert(not meshes.is_empty(), "Ara equipment prop contains no visible meshes: %s" % prop_id)
        instance.free()
    print("ARA_EQUIPMENT_ASSET_TEST: PASS (%d separate props)" % PROP_IDS.size())
    quit(0)

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)
