extends SceneTree

const CAMP_CONTROLLER = preload("res://scripts/world/camp_lifecycle_controller.gd")
const ROWAN_WORLD_SERVICE = preload("res://scripts/world/rowan_fletcher_world_service.gd")

var failures: int = 0

func _initialize() -> void:
	_test_camp_sleep_button_phase_mapping()
	_test_rowan_visit_key_uses_day_and_camp_site()
	if failures > 0:
		push_error("%d campaign world service assertion(s) failed." % failures)
		quit(1)
		return
	print("Campaign world service tests passed.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _test_camp_sleep_button_phase_mapping() -> void:
	var simulation := WorldSimulation.new()
	var controller := CAMP_CONTROLLER.new()
	var button := Button.new()
	controller.simulation = simulation
	controller.sleep_button = button
	var expected := {
		"evening": ["Sleep until morning", true, false],
		"interrupted": ["Continue sleeping", true, false],
		"night": ["Pack camp", true, false],
		"morning": ["Morning routine…", true, true],
		"resolved": ["Pack camp", true, false],
		"inactive": ["", false, false]
	}
	for phase in expected:
		simulation.camp_simulation.phase = phase
		controller.sync_sleep_button_state()
		var state: Array = expected[phase]
		_check(button.text == String(state[0]), "Camp phase %s should display its matching action label." % phase)
		_check(button.visible == bool(state[1]), "Camp phase %s should have the correct button visibility." % phase)
		_check(button.disabled == bool(state[2]), "Camp phase %s should have the correct enabled state." % phase)
	button.free()
	controller.free()
	simulation.free()

func _test_rowan_visit_key_uses_day_and_camp_site() -> void:
	var simulation := WorldSimulation.new()
	var service := ROWAN_WORLD_SERVICE.new()
	service.simulation = simulation
	simulation.clock.world_seconds = 2.0 * 86400.0 + 3600.0
	simulation.camp_simulation.site = {"hex": Vector2i(12, -7)}
	_check(service.visit_key() == "2:12:-7", "Rowan's visit key should remain stable for a world day and campsite.")
	service.free()
	simulation.free()
