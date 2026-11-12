extends SceneTree

const ACTOR_SCRIPT = preload("res://scripts/presentation/ara_character_actor.gd")

func _initialize() -> void:
    var actor := ACTOR_SCRIPT.new()
    var player := AnimationPlayer.new()
    var library := AnimationLibrary.new()
    library.add_animation("Idle", Animation.new())
    library.add_animation("Talk with gestures", Animation.new())
    player.add_animation_library("test", library)
    actor.add_child(player)
    actor.animation_player = player

    assert(actor.available_animation_names().size() == 2, "Ara wrapper should expose embedded animation names")
    assert(actor.play_animation_matching(["sit idle"], ["idle"]) == "test/Idle", "Missing preferred clips should use a compatible fallback")
    assert(actor.play_animation_matching(["Talk with gestures"]) == "test/Talk with gestures", "Semantic clip matching should be case-insensitive and accept spaces")
    assert(actor.play_animation_matching(["drink"], ["sip"]) == "", "Missing clips should fail safely without inventing an animation")

    actor.free()
    print("Cinematic animation matching tests passed.")
    quit(0)
