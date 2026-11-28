extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_valid_site_and_environment()
	_test_rejection_rules()
	if failures > 0:
		push_error("%d camp site evaluator assertion(s) failed." % failures)
		quit(1)
		return
	print("Camp site evaluator tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _test_valid_site_and_environment() -> void:
	var simulation := WorldSimulation.new()
	var camp_hex := Vector2i.ZERO
	simulation.map_data.add_cell(camp_hex, 0.0, true, "grass")
	simulation.map_data.add_cell(Vector2i(2, 0), 0.0, true, "forest")
	simulation.map_data.add_cell(Vector2i(0, 3), 0.0, true, "water")
	var world_position := Vector3(12.0, 0.0, -8.0)
	var result := CampSiteEvaluator.evaluate(simulation, camp_hex, false, world_position)
	_check(bool(result.get("ok", false)), "A walkable, unoccupied ground hex should be a valid camp site.")
	var site: Dictionary = result.get("site", {})
	_check(site.get("hex") == camp_hex, "The evaluated site should retain its authored hex.")
	_check(site.get("position") == world_position, "The evaluated site should retain its world position.")
	_check(bool(site.get("walkable", false)) and not bool(site.get("occupied", true)), "The evaluated site should be marked walkable and unoccupied.")
	var environment: Dictionary = result.get("environment", {})
	_check(bool(environment.get("trees_nearby", false)), "Nearby forest should be reported for camp preparation.")
	_check(bool(environment.get("water_nearby", false)), "Nearby water should be reported for camp preparation.")
	simulation.free()


func _test_rejection_rules() -> void:
	var simulation := WorldSimulation.new()
	var ground := Vector2i.ZERO
	simulation.map_data.add_cell(ground, 0.0, true, "grass")
	_check(
		not bool(CampSiteEvaluator.evaluate(simulation, ground, true, Vector3.ZERO).get("ok", false)),
		"Upper-floor hexes must not be accepted as ground campsites."
	)
	_check(
		not bool(CampSiteEvaluator.evaluate(simulation, Vector2i(1, 0), false, Vector3.ZERO).get("ok", false)),
		"Unloaded hexes must not be accepted as campsites."
	)
	var blocked := Vector2i(2, 0)
	simulation.map_data.add_cell(blocked, 0.0, false, "grass")
	_check(
		not bool(CampSiteEvaluator.evaluate(simulation, blocked, false, Vector3.ZERO).get("ok", false)),
		"Unwalkable terrain must not be accepted as a campsite."
	)
	var occupied := Vector2i(3, 0)
	simulation.map_data.add_cell(occupied, 0.0, true, "grass")
	simulation.register_character(CharacterState.new("camp_site_occupant", "Occupant", occupied))
	_check(
		not bool(CampSiteEvaluator.evaluate(simulation, occupied, false, Vector3.ZERO).get("ok", false)),
		"Occupied hexes must not be accepted as campsites."
	)
	simulation.free()
