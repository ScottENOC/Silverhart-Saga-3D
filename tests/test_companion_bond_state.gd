extends SceneTree

var _failures := 0


func _initialize() -> void:
	var bonds := CompanionBondState.new()
	var first := bonds.adjust("wren", "aldric", {"friendship": 12, "trust": 8}, "shared_watch:01")
	_check(bool(first.ok) and bool(first.changed))
	bonds.adjust("wren", "aldric", {"trust": 2}, "shared_watch:02")
	var repeated := bonds.adjust("wren", "aldric", {"friendship": 12}, "shared_watch:01")
	_check(not bool(repeated.changed), "An old event key cannot apply again after later events")
	_check(float(bonds.snapshot("wren", "aldric").friendship) == 12.0)
	_check(float(bonds.snapshot("aldric", "wren").friendship) == 0.0, "Feelings are directional, not silently reciprocal")
	bonds.set_relationship("aldric", "wren", {"friendship": 60, "trust": 50, "familiarity": 40})
	_check(bonds.compatibility_score("wren", "aldric") > 0.0)
	var flirt := bonds.record_interaction("wren", "aldric", "flirt", {"attraction": 4}, "flirt:campfire:01")
	_check(bool(flirt.get("changed", false)), "A resolved flirt interaction should update directional attraction")
	_check(not bool(bonds.record_interaction("wren", "aldric", "flirt", {"attraction": 4}, "flirt:campfire:01").get("changed", true)), "Social events must be idempotent")
	var saved := bonds.to_dict()
	var restored := CompanionBondState.new()
	_check(restored.from_dict(saved))
	_check(restored.to_dict() == saved, "Directional bonds should survive save/load")
	_check(not bool(restored.adjust("wren", "wren", {"friendship": 1}).ok))
	if _failures > 0:
		push_error("%d companion bond assertion(s) failed." % _failures)
		quit(1)
		return
	print("Companion bond state tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)
