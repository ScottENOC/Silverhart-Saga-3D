extends SceneTree
## Verifies that split Ara hair exports retain a compatible skinned rig.

const ROOT := "res://art/characters/ara_runtime/hair"

func _initialize() -> void:
    var manifest_path := ROOT + "/manifest.json"
    assert(FileAccess.file_exists(manifest_path), "Missing Ara hair manifest")
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    assert(parsed is Dictionary, "Ara hair manifest is invalid JSON")
    var characters: Dictionary = parsed.get("characters", {})
    for sex in ["female", "male"]:
        assert(characters.has(sex), "Missing %s character bundle" % sex)
        var entry: Dictionary = characters[sex]
        _check_scene(ROOT + "/" + str(entry.get("base", "")), false)
        var styles: Dictionary = entry.get("hairstyles", {})
        assert(not styles.is_empty(), "No hairstyles exported for %s" % sex)
        for style in styles.keys():
            var style_entry: Dictionary = styles[style]
            _check_scene(ROOT + "/" + str(style_entry.get("file", "")), true)
    print("ARA_HAIR_ASSET_TEST: PASS")
    quit(0)

func _check_scene(path: String, require_skinned_hair: bool) -> void:
    assert(FileAccess.file_exists(path), "Missing hair asset: %s" % path)
    var packed := load(path) as PackedScene
    assert(packed != null, "GLB failed to import as PackedScene: %s" % path)
    var instance := packed.instantiate()
    var skeletons: Array[Skeleton3D] = []
    var meshes: Array[MeshInstance3D] = []
    _collect(instance, skeletons, meshes)
    assert(not skeletons.is_empty(), "GLB has no Skeleton3D: %s" % path)
    assert(skeletons[0].get_bone_count() > 0, "GLB skeleton is empty: %s" % path)
    if require_skinned_hair:
        assert(not meshes.is_empty(), "Hair GLB has no MeshInstance3D: %s" % path)
        var skinned := false
        for mesh in meshes:
            if mesh.skin != null and mesh.mesh != null:
                skinned = true
                break
        assert(skinned, "Hair mesh lost skin weights: %s" % path)
    instance.free()

func _collect(node: Node, skeletons: Array[Skeleton3D], meshes: Array[MeshInstance3D]) -> void:
    if node is Skeleton3D:
        skeletons.append(node as Skeleton3D)
    if node is MeshInstance3D:
        meshes.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect(child, skeletons, meshes)
