extends SceneTree

var _failures := 0

func _initialize() -> void:
	_test_species_weights()
	_test_candidate_distance_and_map_rules()
	if _failures > 0:
		push_error("%d wilderness creature spawn assertion(s) failed." % _failures)
		quit(1)
		return
	print("Wilderness creature spawn service tests passed.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _test_species_weights() -> void:
	_check(WildernessCreatureSpawnService.species_for_roll(0.0) == "wolf", "The first species weight should select wolves.")
	_check(WildernessCreatureSpawnService.species_for_roll(0.25) == "wolf", "The wolf weight boundary should be inclusive.")
	_check(WildernessCreatureSpawnService.species_for_roll(0.2501) == "fox", "The second species weight should select foxes.")
	_check(WildernessCreatureSpawnService.species_for_roll(0.5) == "fox", "The fox weight boundary should be inclusive.")
	_check(WildernessCreatureSpawnService.species_for_roll(0.5001) == "deer", "The third species weight should select deer.")
	_check(WildernessCreatureSpawnService.species_for_roll(0.8) == "deer", "The deer weight boundary should be inclusive.")
	_check(WildernessCreatureSpawnService.species_for_roll(0.8001) == "stag", "The final species weight should select stags.")
	_check(WildernessCreatureSpawnService.species_for_roll(1.0) == "stag", "The final species should handle the upper roll boundary.")

func _test_candidate_distance_and_map_rules() -> void:
	var simulation := WorldSimulation.new()
	var player_hex := Vector2i(0, 0)
	var valid_hex := Vector2i(7, 0)
	simulation.map_data.add_cell(valid_hex, 0.0, true, "grass")
	_check(
		WildernessCreatureSpawnService.candidate_is_valid(simulation, player_hex, valid_hex, Callable()),
		"A walkable, unoccupied hex outside the minimum distance should be valid."
	)
	_check(
		not WildernessCreatureSpawnService.candidate_is_valid(simulation, player_hex, Vector2i(6, 0), Callable()),
		"Candidates at the minimum distance should be rejected."
	)
	_check(
		not WildernessCreatureSpawnService.candidate_is_valid(simulation, player_hex, Vector2i(14, 0), Callable()),
		"Candidates beyond the maximum distance should be rejected."
	)
	_check(
		not WildernessCreatureSpawnService.candidate_is_valid(simulation, player_hex, Vector2i(7, 1), Callable()),
		"Candidates without a loaded map cell should be rejected."
	)

	var blocked_hex := Vector2i(8, 0)
	simulation.map_data.add_cell(blocked_hex, 0.0, false, "grass")
	_check(
		not WildernessCreatureSpawnService.candidate_is_valid(simulation, player_hex, blocked_hex, Callable()),
		"Blocked terrain should be rejected."
	)

	var occupied_hex := Vector2i(9, 0)
	simulation.map_data.add_cell(occupied_hex, 0.0, true, "grass")
	var occupant := CharacterState.new("wildlife_test_occupant", "Occupant", occupied_hex)
	simulation.register_character(occupant)
	_check(
		not WildernessCreatureSpawnService.candidate_is_valid(simulation, player_hex, occupied_hex, Callable()),
		"Occupied hexes should be rejected."
	)

	var excluded_hex := Vector2i(10, 0)
	simulation.map_data.add_cell(excluded_hex, 0.0, true, "grass")
	var exclusion := Callable(self, "_exclude_test_hex")
	_check(
		not WildernessCreatureSpawnService.candidate_is_valid(simulation, player_hex, excluded_hex, exclusion),
		"Location-provided exclusion rules should be respected."
	)
	simulation.free()

func _exclude_test_hex(hex: Vector2i) -> bool:
	return hex == Vector2i(10, 0)
