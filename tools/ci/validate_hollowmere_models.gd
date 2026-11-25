extends SceneTree
## Loads every Ara GLB in the Hollowmere village cast and verifies imported animation tracks.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var source := _read_json("res://data/characters/hollowmere_npcs.json")
    var generated := _read_json("res://art/characters/hollowmere/profiles.json")
    if source.is_empty() or generated.is_empty():
        _fail("Source or generated Hollowmere profile manifest is missing/invalid.")
        return

    var expected: Dictionary = {}
    var source_characters: Array = source.get("characters", [])
    if source_characters.is_empty():
        _fail("Source Hollowmere character roster is empty.")
        return
    for source_profile_variant in source_characters:
        if not (source_profile_variant is Dictionary):
            _fail("Source Hollowmere character entry is not an object.")
            return
        var source_profile: Dictionary = source_profile_variant
        var source_id := str(source_profile.get("id", "")).strip_edges()
        if source_id.is_empty() or expected.has(source_id):
            _fail("Source Hollowmere character roster has a missing or duplicate ID.")
            return
        expected[source_id] = true

    var profiles: Array = generated.get("characters", [])
    if profiles.size() != expected.size():
        _fail("Expected one generated Ara profile for each of the %d source Hollowmere characters; found %d." % [expected.size(), profiles.size()])
        return
    var generated_ids: Dictionary = {}

    for profile_variant in profiles:
        if not (profile_variant is Dictionary):
            _fail("Generated character profile is not an object.")
            return
        var profile: Dictionary = profile_variant
        var character_id := str(profile.get("id", ""))
        if character_id.is_empty() or not expected.has(character_id) or generated_ids.has(character_id):
            _fail("Generated Hollowmere profile has an unknown, missing or duplicate ID: " + character_id)
            return
        generated_ids[character_id] = true
        var model_path := "res://art/characters/hollowmere/%s.glb" % character_id
        var packed := load(model_path) as PackedScene
        if packed == null:
            _fail("Godot could not import/load " + model_path)
            return
        var instance := packed.instantiate()
        if not (instance is Node3D):
            _fail("Ara model root is not Node3D: " + character_id)
            return
        var animation_player := _find_animation_player(instance)
        if animation_player == null or animation_player.get_animation_list().is_empty():
            _fail("Ara animation track is missing after import: " + character_id)
            instance.free()
            return
        instance.free()

    if generated_ids.size() != expected.size():
        _fail("Generated Ara profiles do not cover the complete source Hollowmere character roster.")
        return
    print("Godot imported all %d source-authored Hollowmere Ara models with animation tracks." % generated_ids.size())
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
