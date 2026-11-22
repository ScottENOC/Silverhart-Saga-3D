extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_authored_starts_and_independent_axes()
	_test_hard_caps_and_companion_styles()
	_test_idempotent_events_and_conversations()
	_test_save_load()
	if _failures > 0:
		push_error("%d companion relationship assertion(s) failed." % _failures)
		quit(1)
		return
	print("Companion relationship state tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_authored_starts_and_independent_axes() -> void:
	var relationships := CompanionRelationshipState.new()
	var wren := relationships.snapshot("wren_talbot")
	_check(float(wren.get("familiarity", 0.0)) == 35.0, "Wren starts as an established tavern acquaintance")
	_check(float(wren.get("trust", 0.0)) == 25.0, "Wren's initial trust remains lower than familiarity")
	_check(float(wren.get("friendship", 0.0)) == 38.0, "Wren's authored friendship start is preserved")
	_check(float(wren.get("approval", 0.0)) == 50.0, "Approval remains its own axis")
	relationships.adjust("wren_talbot", {"approval": -10.0}, "disagreed with a choice")
	wren = relationships.snapshot("wren_talbot")
	_check(float(wren.get("approval", 0.0)) == 40.0)
	_check(float(wren.get("trust", 0.0)) == 25.0, "Approval changes must not silently alter trust")


func _test_hard_caps_and_companion_styles() -> void:
	var relationships := CompanionRelationshipState.new()
	relationships.set_presentation("wren_talbot", "feminine")
	var wren := relationships.adjust("wren_talbot", {"attraction": 100.0, "romantic_bond": 100.0})
	_check(float(wren.state.get("attraction", 100.0)) == 30.0, "Wren's feminine-presentation attraction cap is 30")
	_check(float(wren.state.get("romantic_bond", 0.0)) == 85.0, "Wren's feminine-presentation romantic cap is 85")
	var alden := relationships.adjust("brother_alden", {"attraction": 100.0, "romantic_bond": 70.0})
	_check(float(alden.state.get("attraction", 100.0)) == 0.0, "Alden's asexuality is a hard zero-attraction cap")
	_check(float(alden.state.get("romantic_bond", 0.0)) == 70.0, "Alden can develop romantic attachment without sexual attraction")
	var fenn_profile := relationships.profile_for("fenn_oakheart")
	var fenn_style: Dictionary = fenn_profile.get("relationship_style", {})
	_check(String(fenn_style.get("romantic_exclusivity", "")) == "open")
	_check(bool(fenn_style.get("group_relationships", false)), "Fenn's authored relationship style permits group relationships")
	var reyna_profile := relationships.profile_for("reyna_fletcher")
	var reyna_caps: Dictionary = reyna_profile.get("attraction_caps", {})
	_check(float(reyna_caps.get("masculine", 100.0)) == 5.0, "Reyna's authored attraction cap is preserved")


func _test_idempotent_events_and_conversations() -> void:
	var relationships := CompanionRelationshipState.new()
	var first := relationships.note_conversation("mirabel_quill", "personal:archive", 2.0)
	var repeated := relationships.note_conversation("mirabel_quill", "personal:archive", 2.0)
	_check(bool(first.get("changed", false)))
	_check(not bool(repeated.get("changed", true)), "Repeated conversation keys cannot farm familiarity")
	_check(float(repeated.state.get("familiarity", 0.0)) == 12.0)
	var event := relationships.record_trust_event("wren_talbot", "kept:parents_promise", 8.0, "kept a personal promise")
	var repeated_event := relationships.record_trust_event("wren_talbot", "kept:parents_promise", 8.0)
	_check(bool(event.get("changed", false)))
	_check(not bool(repeated_event.get("changed", true)), "Trust events are idempotent")
	_check(float(repeated_event.state.get("trust", 0.0)) == 33.0)


func _test_save_load() -> void:
	var relationships := CompanionRelationshipState.new()
	relationships.record_event("fenn_oakheart", "grove:controlled_burn", {"friendship": 7.0, "trust": 5.0}, "supported careful stewardship")
	relationships.set_agreement("fenn_oakheart", {"state": "committed", "romantic_exclusivity": "open", "sexual_exclusivity": "open"}, 1234.0)
	var saved := relationships.to_dict()
	var restored := CompanionRelationshipState.new()
	restored.load_dict(saved)
	_check(restored.to_dict() == saved, "Companion relationship state and agreements survive save/load")
	var agreement: Dictionary = restored.snapshot("fenn_oakheart").get("agreement", {})
	_check(String(agreement.get("state", "")) == "committed")
	_check(float(agreement.get("established_world_seconds", 0.0)) == 1234.0)
