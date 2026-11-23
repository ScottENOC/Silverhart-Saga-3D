extends SceneTree

const RUNTIME_STORE = preload("res://scripts/simulation/companion_campaign_runtime_store.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_runtime_registration_and_save_restore()
	_test_wren_gender_presentation_and_authored_events()
	if _failures > 0:
		push_error("%d companion campaign runtime assertion(s) failed." % _failures)
		quit(1)
		return
	print("Companion campaign runtime tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_runtime_registration_and_save_restore() -> void:
	var source := WorldSimulation.new()
	_check(RUNTIME_STORE.register_quest_definitions(source), "Companion chapter definitions register against the campaign journal")
	var source_quest_state := RUNTIME_STORE.quest_chain_state_for(source)
	_check(source_quest_state != null and not source_quest_state.all_chapters().is_empty(), "The source-authored companion chapter catalogue loads")
	_check(source.campaign_journal.quest_definitions.has("aldric_weight_of_command"), "Companion chapter quests are available to the campaign journal")

	var relationships := RUNTIME_STORE.relationship_state_for(source)
	relationships.record_event("ser_aldric_thorne", "runtime_test:trust", {"trust": 12.0}, "proved trustworthy")
	source_quest_state.arc_states["ser_aldric_thorne"] = {"sharedBurden": 18.0}
	source_quest_state.personality_growth["ser_aldric_thorne"] = {"delegation": 4.0}
	var saved_runtime := RUNTIME_STORE.to_dict(source)
	var saved_journal := source.campaign_journal.to_dict()

	var restored := WorldSimulation.new()
	_check(RUNTIME_STORE.register_quest_definitions(restored), "Companion chapter definitions register before save restoration")
	restored.campaign_journal.load_dict(saved_journal)
	_check(RUNTIME_STORE.restore(restored, saved_runtime), "Companion runtime state restores from the campaign save")
	var restored_relationships := RUNTIME_STORE.relationship_state_for(restored)
	var restored_quest_state := RUNTIME_STORE.quest_chain_state_for(restored)
	_check(float(restored_relationships.snapshot("ser_aldric_thorne").get("trust", 0.0)) == 22.0, "Companion trust survives save/load")
	_check(float(restored_quest_state.arc_states["ser_aldric_thorne"].get("sharedBurden", 0.0)) == 18.0, "Companion arc state survives save/load")
	_check(float(restored_quest_state.personality_growth["ser_aldric_thorne"].get("delegation", 0.0)) == 4.0, "Companion personality growth survives save/load")
	var repeated := restored_relationships.record_event("ser_aldric_thorne", "runtime_test:trust", {"trust": 12.0}, "proved trustworthy")
	_check(not bool(repeated.get("changed", true)), "A restored event key prevents duplicate relationship rewards")


func _test_wren_gender_presentation_and_authored_events() -> void:
	var simulation := WorldSimulation.new()
	var relationships := RUNTIME_STORE.relationship_state_for(simulation)
	relationships.set_presentation("wren_talbot", "feminine")
	relationships.adjust("wren_talbot", {"friendship": 30.0, "romantic_bond": 60.0, "attraction": 100.0})
	var interpreted := relationships.interpret_relationship("wren_talbot")
	_check(float(interpreted.get("attraction", 100.0)) == 30.0, "Feminine player presentation applies Wren's source attraction cap")
	_check(String(interpreted.get("mode", "")) == "love_desire_conflict", "Wren's feminine-presentation love/desire conflict is available in runtime state")

	var event := relationships.apply_wren_authored_event("hollowmere_shakedown:fight")
	_check(bool(event.get("ok", false)), "The live Hollowmere shakedown maps to Wren's authored relationship event")
	var after_event := relationships.snapshot("wren_talbot")
	_check(float(after_event.get("approval", 0.0)) == 60.0, "Standing with Hollowmere affects Wren's approval")
	_check(float(after_event.get("trust", 0.0)) == 33.0, "Standing with Hollowmere affects Wren's trust")
	var repeated := relationships.apply_wren_authored_event("hollowmere_shakedown:fight")
	_check(not bool(repeated.get("changed", true)), "Wren's authored consequence is idempotent")
