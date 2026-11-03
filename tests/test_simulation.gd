extends SceneTree

func _initialize() -> void:
    _test_character_round_trip()
    _test_movement_validation()
    print("WorldSimulation tests passed.")
    quit()

func _test_character_round_trip() -> void:
    var original := CharacterState.new("npc_garrick_holt", "Garrick Holt", Vector2i(2, -1))
    original.health = 73
    var restored := CharacterState.from_dict(original.to_dict())
    assert(restored.id == original.id)
    assert(restored.display_name == original.display_name)
    assert(restored.axial == original.axial)
    assert(restored.health == 73)

func _test_movement_validation() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(2, 0), 0.0, false)
    sim.register_character(CharacterState.new("player", "Player", Vector2i.ZERO))

    assert(sim.try_move_character("player", Vector2i(1, 0)))
    assert(not sim.try_move_character("player", Vector2i(2, 0)))
    assert(not sim.try_move_character("player", Vector2i(3, 0)))
    assert(not sim.try_move_character("missing", Vector2i(0, 1)))
