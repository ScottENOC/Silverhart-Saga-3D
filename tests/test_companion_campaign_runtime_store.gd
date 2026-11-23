extends SceneTree

const RUNTIME_STORE = preload("res://scripts/simulation/companion_campaign_runtime_store.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_runtime_registration_and_save_restore()
	_test_wren_gender_presentation_and_authored_events()\n\t_test_wren_character_development_and_persistence()
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
	relationships.set_presentation("wren_talbot", "feminine")
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
	_check(String(restored_relationships.snapshot("wren_talbot").get("presentation", "")) == "feminine", "Player gender presentation survives companion save/load")
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


func _test_wren_character_development_and_persistence() -> void:
	var simulation := WorldSimulation.new()
	var relationships := RUNTIME_STORE.relationship_state_for(simulation)
	var arc := RUNTIME_STORE.wren_arc_state_for(simulation)
	_check(arc != null, "Wren character arc state is available from the campaign runtime")
	_check(float(arc.player.get("personalLoyalty", 999.0)) == 0.0, "Player values use the source-authored starting point")
	_check(float(arc.wren.get("personalLoyalty", 0.0)) == 20.0 and float(arc.wren.get("mercy", 0.0)) == 15.0 and float(arc.wren.get("security", 0.0)) == -20.0, "Wren uses the source-authored starting axes")

	var story := arc.apply_story_event("hollowmere_shakedown:fight", relationships)
	_check(bool(story.get("ok", false)) and bool(story.get("changed", false)), "A source-authored story event changes character development")
	_check(float(arc.player.get("personalLoyalty", 0.0)) == 3.0, "Player values receive the full authored story influence")
	_check(float(arc.wren.get("security", 0.0)) == -18.0, "Direct effects on Wren apply at full strength")
	var duplicate_story := arc.apply_story_event("hollowmere_shakedown:fight", relationships)
	_check(not bool(duplicate_story.get("changed", true)), "Story influence is idempotent")

	var dialogue := arc.apply_dialogue_choice("you_do_not_owe_me", relationships)
	_check(bool(dialogue.get("changed", false)), "Wren's personal dialogue choice applies once")
	_check(float(arc.wren.get("security", 0.0)) > -18.0, "Dialogue choice improves Wren's attachment security")
	_check(float(relationships.snapshot("wren_talbot").get("trust", 0.0)) >= 31.0, "Dialogue choice also applies its authored relationship trust")
	var duplicate_dialogue := arc.apply_dialogue_choice("you_do_not_owe_me", relationships)
	_check(not bool(duplicate_dialogue.get("changed", true)), "Dialogue choices cannot award their effects twice")

	var saved := RUNTIME_STORE.to_dict(simulation)
	var restored := WorldSimulation.new()
	var restored_relationships := RUNTIME_STORE.relationship_state_for(restored)
	restored_relationships.load_dict(saved.get("relationships", {}))
	_check(RUNTIME_STORE.restore(restored, saved), "Wren's character arc restores with campaign runtime state")
	var restored_arc := RUNTIME_STORE.wren_arc_state_for(restored)
	_check(restored_arc.to_dict() == arc.to_dict(), "Wren's axes, idempotency keys and development history survive save/load")
	_check(restored_arc.stance() == arc.stance() and restored_arc.attachment_state() == arc.attachment_state(), "Derived Wren stance and attachment remain stable after restore")
