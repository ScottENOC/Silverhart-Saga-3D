extends SceneTree

const ARA_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")

func _initialize() -> void:
    var actor := ARA_ACTOR.new() as AraCharacterActor
    var model := Node3D.new()
    actor.add_child(model)
    actor.model_root = model
    actor.apply_player_profile({
        "body_variant": "male",
        "gender_presentation": "Masculine",
        "pronouns": "he/him",
        "height_scale": 1.08,
        "build_scale": 1.05
    })
    assert(model.scale.is_equal_approx(Vector3(1.05, 1.08, 1.05)))
    assert(str(actor.get_meta("body_variant")) == "male")
    assert(str(actor.get_meta("gender_presentation")) == "Masculine")
    assert(str(actor.get_meta("pronouns")) == "he/him")
    actor.free()
    print("Player character visual profile tests passed.")
    quit()
