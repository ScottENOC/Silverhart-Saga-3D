extends SceneTree
## Loads every Ara GLB through Godot's importer and verifies that its rig animations survive import.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var source := _read_json("res://data/characters/hollowmere_npcs.json")
    var generated := _read_json("res://art/characters/hollowmere/profiles.json")
    if source.is_empty() or generated.is_empty():
        _fail("Source or generated Hollowmere profile manifest is missing/invalid.")
        return

    var expected: Dictionary = {}
    for profile in source.get("characters", []):
        expected[str(profile.get("id", ""))] = true

    var profiles: Array = generated.get("characters", [])
    if expected.size() != 13 or profiles.size() != expected.size():
        _fail("Expected exactly 13 generated Ara character profiles.")
        return

    for profile_variant in profiles:
        if not profile_variant is Dictionary:
            _fail("Generated character profile is not an object.")
            return
        var profile: Dictionary = profile_variant
        var character_id := str(profile.get("id", ""))
        if not expected.has(character_id):
            _fail("Unexpected generated character: " + character_id)
            return
        var model_path := "res://art/characters/hollowmere/%s.glb" % character_id
        var packed := load(model_path) as PackedScene
        if packed == null:
            _fail("Godot could not import/load " + model_path)
            return
        var instance := packed.instantiate()
        if not instance is Node3D:
            _fail("Ara model root is not Node3D: " + character_id)
            return
        var animation_player := _find_animation_player(instance)
        if animation_player == null or animation_player.get_animation_list().is_empty():
            _fail("Ara animation track is missing after import: " + character_id)
            instance.free()
            return
        instance.free()

    print("Godot imported all 13 Hollowmere Ara models with animation tracks.")
    quit(0)

func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func _fail(message: String) -> void:
    push_error("Hollowmere Ara import validation failed: " + message)
    quit(1)
