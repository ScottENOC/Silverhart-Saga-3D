extends SceneTree
## Verifies split Ara hair exports retain skinning and can bind to the matching base skeleton.

const ROOT := "res://art/characters/ara_runtime/hair"
const ACTOR_SCRIPT := preload("res://scripts/presentation/ara_character_actor.gd")

func _initialize() -> void:
    _test_bind_pose_conversion()
    var manifest_path := ROOT + "/manifest.json"
    assert(FileAccess.file_exists(manifest_path), "Missing Ara hair manifest")
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    assert(parsed is Dictionary, "Ara hair manifest is invalid JSON")
    var characters: Dictionary = parsed.get("characters", {})
    for sex in ["female", "male"]:
        assert(characters.has(sex), "Missing %s character bundle" % sex)
        var entry: Dictionary = characters[sex]
        var base_path := ROOT + "/" + str(entry.get("base", ""))
        _check_scene(base_path, false)
        var actor := ACTOR_SCRIPT.new() as AraCharacterActor
        root.add_child(actor)
        assert(actor.configure(base_path), "Actor could not load %s base" % sex)
        var styles: Dictionary = entry.get("hairstyles", {})
        assert(not styles.is_empty(), "No hairstyles exported for %s" % sex)
        for style in styles.keys():
            var style_entry: Dictionary = styles[style]
            var hair_path := ROOT + "/" + str(style_entry.get("file", ""))
            _check_scene(hair_path, true)
            assert(actor.set_hairstyle(hair_path), "Actor rejected %s/%s hair" % [sex, style])
            assert(not actor.hair_instances.is_empty(), "Actor attached no meshes for %s/%s" % [sex, style])
            var target := _find_skeleton(actor.model_root)
            assert(target != null, "Base actor skeleton disappeared")
            for hair_mesh in actor.hair_instances:
                assert(hair_mesh.get_node_or_null(hair_mesh.skeleton) == target,
                    "Hair mesh was not rebound to the base skeleton: %s/%s" % [sex, style])
        actor.clear_hairstyle()
        actor.queue_free()
    print("ARA_HAIR_ASSET_TEST: PASS (skinning and runtime skeleton attachment)")
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

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _collect(node: Node, skeletons: Array[Skeleton3D], meshes: Array[MeshInstance3D]) -> void:
    if node is Skeleton3D:
        skeletons.append(node as Skeleton3D)
    if node is MeshInstance3D:
        meshes.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect(child, skeletons, meshes)

 
func _test_bind_pose_conversion() -> void:
    # The source GLB may encode a mesh-space offset in its inverse bind matrix.
    # Retargeting to a body with a different Head rest transform must preserve
    # the complete source rest-pose transform, not discard that offset.
    var source_skeleton := Skeleton3D.new()
    source_skeleton.add_bone("Head")
    var source_rest := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.6, 0.0))
    source_skeleton.set_bone_rest(0, source_rest)

    var target_skeleton := Skeleton3D.new()
    target_skeleton.add_bone("Head")
    var target_rest := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.75, 0.0))
    target_skeleton.set_bone_rest(0, target_rest)

    var mesh_space_offset := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.15, 0.0))
    var original_bind := source_rest.affine_inverse() * mesh_space_offset
    var skin := Skin.new()
    skin.set_bind_count(1)
    skin.set_bind_bone(0, 0)
    skin.set_bind_pose(0, original_bind)
    var hair_mesh := MeshInstance3D.new()
    hair_mesh.skin = skin

    var actor := ACTOR_SCRIPT.new() as AraCharacterActor
    assert(actor._remap_hair_skin_to_skeleton(hair_mesh, source_skeleton, target_skeleton),
        "Hair bind pose could not be converted to the target skeleton")
    var expected := source_rest * original_bind
    var actual := target_rest * hair_mesh.skin.get_bind_pose(0)
    assert(actual.is_equal_approx(expected),
        "Hair retargeting discarded the source mesh-space bind offset")
    actor.free()
    hair_mesh.free()
    source_skeleton.free()
    target_skeleton.free()
