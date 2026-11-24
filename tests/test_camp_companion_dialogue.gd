extends SceneTree

const SERVICE := preload("res://scripts/simulation/camp_companion_dialogue_SERVICE.gd")

var _failures := 0


func _initialize() -> void:
	var bonds := CompanionBondState.new()
	var camp := CampSimulation.new()
	var exchange := SERVICE.build_exchange(
		"companion_ser_aldric_thorne",
		"companion_nix_sharpear",
		0,
		bonds,
		"Ser Aldric Thorne",
		"Nix Sharpear"
	)
	_check(not exchange.is_empty(), "Two different companions should be able to exchange dialogue")
	_check(String(exchange.get("topic", "")) == "road")
	var lines: Array = exchange.get("lines", [])
	_check(lines.size() == 2, "An exchange should contain both sides of the conversation")
	_check(String(lines[0].get("character_id", "")) == "companion_ser_aldric_thorne")
	_check(String(lines[1].get("character_id", "")) == "companion_nix_sharpear")
	_check(String(lines[0].get("text", "")).length() > 20)
	_check(String(lines[1].get("text", "")).length() > 20)

	var recorded := SERVICE.record_exchange(bonds, camp, exchange, "test:camp:exchange:1")
	_check(bool(recorded.get("ok", false)) and bool(recorded.get("changed", false)))
	_check(float(bonds.snapshot("companion_ser_aldric_thorne", "companion_nix_sharpear").familiarity) == 1.0)
	_check(float(bonds.snapshot("companion_nix_sharpear", "companion_ser_aldric_thorne").friendship) == 1.0)
	_check(float(camp.condition_for("companion_ser_aldric_thorne").social_satisfaction) == 2.0)
	_check(float(camp.condition_for("companion_nix_sharpear").social_satisfaction) == 2.0)

	var repeated := SERVICE.record_exchange(bonds, camp, exchange, "test:camp:exchange:1")
	_check(bool(repeated.get("ok", false)) and not bool(repeated.get("changed", true)))
	_check(float(bonds.snapshot("companion_ser_aldric_thorne", "companion_nix_sharpear").familiarity) == 1.0)
	_check(float(camp.condition_for("companion_ser_aldric_thorne").social_satisfaction) == 2.0)

	for first_id in SERVICE.supported_companion_ids():
		for second_id in SERVICE.supported_companion_ids():
			if first_id == second_id:
				continue
			var pair := SERVICE.build_exchange("companion_" + first_id, "companion_" + second_id, 2, bonds)
			_check(not pair.is_empty(), "Every authored companion should have dialogue with every other companion")
			_check((pair.get("lines", []) as Array).size() == 2)

	_check(SERVICE.build_exchange("player", "companion_ser_aldric_thorne", 0, bonds).is_empty())
	_check(SERVICE.build_exchange("companion_ser_aldric_thorne", "companion_ser_aldric_thorne", 0, bonds).is_empty())

	if _failures > 0:
		push_error("%d camp companion dialogue assertion(s) failed." % _failures)
		quit(1)
		return
	print("Camp companion dialogue tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)
