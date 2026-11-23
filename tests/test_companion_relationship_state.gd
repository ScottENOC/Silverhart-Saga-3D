extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_authored_starts_and_independent_axes()
	_test_hard_caps_and_companion_styles()
	_test_idempotent_events_and_conversations()
	_test_wren_source_events()
	_test_relationship_progression_and_agreements()
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
	var feminine_start := relationships.ensure("wren_talbot", "feminine")
	_check(float(feminine_start.get("attraction", 0.0)) == 5.0, "Wren’s initial attraction is rounded against the feminine-presentation cap")
	_check(String(feminine_start.get("romance_state", "")) == "unspoken")
	relationships.set_presentation("wren_talbot", "feminine")
	var wren := relationships.adjust("wren_talbot", {"attraction": 100.0, "romantic_bond": 100.0})
	_check(float(wren.state.get("attraction", 100.0)) == 30.0, "Wren's feminine-presentation attraction cap is 30")
	_check(float(wren.state.get("romantic_bond", 0.0)) == 85.0, "Wren's feminine-presentation romantic cap is 85")
	var alden := relationships.adjust("brother_alden", {"attraction": 100.0, "romantic_bond": 70.0})
	_check(float(alden.state.get("attraction", 100.0)) == 0.0, "Alden's asexuality is a hard zero-attraction cap")
	_check(float(alden.state.get("romantic_bond", 0.0)) == 70.0, "Alden can develop romantic attachment without sexual attraction")
	relationships.adjust("brother_alden", {"friendship": 40.0})
	_check(String(relationships.interpret_relationship("brother_alden").get("mode", "")) == "asexual_romance", "Alden has a distinct asexual-romance interpretation")
	relationships.adjust("wren_talbot", {"friendship": 30.0, "romantic_bond": 60.0})
	_check(String(relationships.interpret_relationship("wren_talbot").get("mode", "")) == "love_desire_conflict", "Wren retains her authored love/desire-conflict state")
	var fenn_profile := relationships.profile_for("fenn_oakheart")
	var fenn_style: Dictionary = fenn_profile.get("relationship_style", {})
	_check(String(fenn_style.get("romantic_exclusivity", "")) == "open")
	_check(bool(fenn_style.get("group_relationships", false)), "Fenn's authored relationship style permits group relationships")
	_check(int(relationships.profile_for("brother_alden").get("strong_physical_desire_threshold", 0)) == 101, "Alden’s physical-desire threshold remains unreachable")
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


func _test_wren_source_events() -> void:
	var relationships := CompanionRelationshipState.new()
	var fight := relationships.apply_wren_authored_event("hollowmere_shakedown:fight")
	_check(bool(fight.get("ok", false)), "Wren's original shakedown fight consequence is recognised")
	_check(float(fight.state.get("approval", 0.0)) == 60.0)
	_check(float(fight.state.get("trust", 0.0)) == 33.0)
	_check(float(fight.state.get("friendship", 0.0)) == 41.0)
	_check(float(fight.state.get("attraction", 0.0)) == 20.0)
	var repeated := relationships.apply_wren_authored_event("hollowmere_shakedown:fight")
	_check(not bool(repeated.get("changed", true)), "Wren's shakedown consequence cannot be applied twice")
	var dialogue := relationships.apply_wren_authored_event("you_do_not_owe_me")
	_check(bool(dialogue.get("ok", false)))
	_check(float(dialogue.state.get("friendship", 0.0)) == 48.0)
	_check(float(dialogue.state.get("romantic_bond", 0.0)) == 5.0)
	var millbrook := relationships.apply_wren_authored_event("parents_search_reached_millbrook")
	_check(float(millbrook.state.get("approval", 0.0)) == 65.0)
	_check(float(millbrook.state.get("trust", 0.0)) == 43.0)
	_check(float(millbrook.state.get("friendship", 0.0)) == 54.0)
	var betrayal := relationships.apply_wren_authored_event("goblin_resolution:betrayal")
	_check(bool(betrayal.get("ok", false)))
	_check(float(betrayal.state.get("approval", 0.0)) == 25.0)
	_check(float(betrayal.state.get("trust", 0.0)) == 8.0)
	_check(float(betrayal.state.get("friendship", 0.0)) == 36.0)
	var lichdom := relationships.apply_wren_authored_event("player_became_lich")
	_check(float(lichdom.state.get("approval", 0.0)) == 0.0)
	_check(float(lichdom.state.get("trust", 0.0)) == 0.0)
	_check(float(lichdom.state.get("friendship", 0.0)) == 14.0)
	var unknown := relationships.apply_wren_authored_event("not_a_real_event")
	_check(String(unknown.get("reason", "")) == "unknown_wren_event")


func _test_relationship_progression_and_agreements() -> void:
	var relationships := CompanionRelationshipState.new()
	for day in range(60):
		relationships.note_personal_dialogue("wren_talbot", "topic_" + str(day))
	_check(float(relationships.snapshot("wren_talbot").get("familiarity", 0.0)) == 60.0, "Unique personal dialogue familiarity is capped at 60")
	var repeated_dialogue := relationships.note_personal_dialogue("wren_talbot", "topic_59")
	_check(not bool(repeated_dialogue.get("changed", true)))
	var first_day := relationships.tick_shared_familiarity("mirabel_quill", 10)
	_check(not bool(first_day.get("changed", true)), "The first shared day establishes a baseline")
	var elapsed_days := relationships.tick_shared_familiarity("mirabel_quill", 20)
	_check(float(elapsed_days.state.get("familiarity", 0.0)) == 20.0, "Elapsed shared days add one familiarity per day")
	var repeated_day := relationships.tick_shared_familiarity("mirabel_quill", 20)
	_check(not bool(repeated_day.get("changed", true)), "Repeated world-day ticks do not duplicate familiarity")
	relationships.tick_shared_familiarity("mirabel_quill", 100)
	_check(float(relationships.snapshot("mirabel_quill").get("familiarity", 0.0)) == 50.0, "Shared-party familiarity is capped at 50")

	relationships.commit_relationship("wren_talbot", "committed", 100.0)
	var wren_breach := relationships.record_outside_connection("wren_talbot", "Another person", "sex", true, 200.0, 10.0)
	_check(bool(wren_breach.get("breach", false)))
	_check(String(wren_breach.agreement.get("state", "")) == "strained", "Fear-bound Wren's breach response strains rather than ends the relationship")
	_check(float(wren_breach.state.get("trust", 100.0)) == 0.0)

	relationships.commit_relationship("brother_alden", "committed", 100.0)
	var alden_sex := relationships.record_outside_connection("brother_alden", "Another person", "sex", true, 200.0)
	_check(bool(alden_sex.get("allowed", false)), "Alden permits outside sexual connections under his agreement")
	var alden_romance := relationships.record_outside_connection("brother_alden", "Another person", "romance", true, 300.0)
	_check(bool(alden_romance.get("breach", false)), "A second romantic commitment breaches Alden's agreement")
	_check(String(alden_romance.agreement.get("state", "")) == "ended")

	relationships.commit_relationship("fenn_oakheart", "committed", 100.0)
	var disclosed := relationships.record_outside_connection("fenn_oakheart", "Another person", "sex", true, 200.0)
	_check(bool(disclosed.get("allowed", false)), "Disclosed connections are compatible with Fenn's open agreement")
	var hidden := relationships.record_outside_connection("fenn_oakheart", "Another person", "sex", false, 300.0)
	_check(bool(hidden.get("breach", false)), "Hiding an outside connection breaches an open agreement")


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
