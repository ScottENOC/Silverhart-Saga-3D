extends SceneTree

const RUNTIME_STORE = preload("res://scripts/simulation/companion_campaign_runtime_store.gd")
const DIALOGUE_SERVICE = preload("res://scripts/simulation/companion_campaign_dialogue_service.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_runtime_registration_and_save_restore()
	_test_wren_gender_presentation_and_authored_events()
	_test_wren_character_development_and_persistence()
	_test_wren_personal_conversation_topics()
	_test_companion_chapter_dialogue_flow()
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



func _test_wren_personal_conversation_topics() -> void:
	var simulation := WorldSimulation.new()
	var relationships := RUNTIME_STORE.relationship_state_for(simulation)
	var arc := RUNTIME_STORE.wren_arc_state_for(simulation)
	var initial_topics := arc.dialogue_topics(relationships, simulation.campaign_journal)
	_check(initial_topics.size() == 1 and String(initial_topics[0].get("id", "")) == "wren_arc_topic:why_stay", "Wren's why-stay topic is available at her source-authored starting familiarity")
	relationships.adjust("wren_talbot", {"familiarity": 35.0})
	var familiar_topics := arc.dialogue_topics(relationships, simulation.campaign_journal)
	_check(familiar_topics.size() == 1 and String(familiar_topics[0].get("id", "")) == "wren_arc_topic:why_stay", "Why Wren stays becomes available at the authored familiarity threshold")
	_check(not arc.why_stays_line(relationships).is_empty(), "Wren's reason for staying is responsive to relationship and character axes")
	arc.apply_dialogue_choice("people_do_not_give_up", relationships)
	_check(arc.dialogue_topics(relationships, simulation.campaign_journal).size() == 1, "The why-stay topic remains available after its first authored response")
	_check(arc.dialogue_options_for_topic("why_stay").size() == 1, "A repeated why-stay topic becomes a short follow-up rather than awarding effects again")

	_check(simulation.campaign_journal.register_quest_definition({"id":"wren_parents","objectives":[{"id":"resolved","target":1.0}]}).get("ok", false), "Wren's parents quest can be registered for reflection gating")
	_check(simulation.campaign_journal.start_quest("wren_parents").get("ok", false), "Wren's parents quest starts for reflection test")
	simulation.campaign_journal.set_objective_progress("wren_parents", "resolved", 1.0)
	simulation.campaign_journal.complete_quest("wren_parents")
	var topics_after_parents := arc.dialogue_topics(relationships, simulation.campaign_journal)
	_check(topics_after_parents.size() == 2 and String(topics_after_parents[1].get("id", "")) == "wren_arc_topic:parents_reflection", "Parents reflection appears only after that quest is completed")
	var reflection_options := arc.dialogue_options_for_topic("parents_reflection")
	_check(reflection_options.size() == 4, "The parents reflection offers the four authored dialogue responses")
	arc.apply_dialogue_choice("truth_even_when_it_hurts", relationships)
	_check(arc.dialogue_topics(relationships, simulation.campaign_journal).size() == 2, "The parents reflection topic remains available after its first response")
	_check(arc.dialogue_options_for_topic("parents_reflection").size() == 1, "A repeated parents reflection becomes a short follow-up without repeating effects")


func _test_companion_chapter_dialogue_flow() -> void:
	var simulation := WorldSimulation.new()
	_check(RUNTIME_STORE.register_quest_definitions(simulation), "Companion chapter definitions register for dialogue flow")
	var previous_id := "aldric_measure_of_oath"
	_check(simulation.campaign_journal.register_quest_definition({"id":previous_id,"objectives":[{"id":"resolved","target":1.0}]}).get("ok", false), "Aldric's preceding chapter can be registered")
	_check(simulation.campaign_journal.start_quest(previous_id).get("ok", false), "Aldric's preceding chapter starts")
	simulation.campaign_journal.set_objective_progress(previous_id, "resolved", 1.0)
	simulation.campaign_journal.complete_quest(previous_id)
	var companion := CharacterState.new("companion_ser_aldric_thorne", "Ser Aldric Thorne")
	simulation.register_character(companion)
	_check(simulation.recruit_companion(companion.id).get("ok", false), "Aldric can be recruited for his next chapter")
	var offer := DIALOGUE_SERVICE.chapter_dialogue_for_companion(simulation, companion.id)
	_check(offer.get("choices", []).size() == 1 and String(offer.choices[0].get("id", "")) == "companion_chapter_start", "A companion conversation offers the eligible chapter")
	_check(String(offer.choices[0].get("companion_id", "")) == companion.id, "Chapter dialogue preserves the party actor ID for returning to companion dialogue")
	var started := DIALOGUE_SERVICE.start_chapter(simulation, "aldric_weight_of_command")
	_check(bool(started.get("ok", false)), "The companion dialogue starts the chapter through its quest-chain rules")
	var waiting := DIALOGUE_SERVICE.chapter_dialogue_for_companion(simulation, companion.id)
	_check(waiting.get("choices", []).is_empty() and String(waiting.get("body", "")).contains("High Cleric Adelram"), "The companion directs the player to the supporting character before deciding")
	var consultation := DIALOGUE_SERVICE.consult_for_actor(simulation, "high_cleric_adelram", "High Cleric Adelram")
	_check(bool(consultation.get("ok", false)) and bool(simulation.campaign_journal.quest_state("aldric_weight_of_command").get("consulted", false)), "Speaking with the supporting character advances the chapter to its reckoning")
	var reckoning := DIALOGUE_SERVICE.chapter_dialogue_for_companion(simulation, companion.id)
	_check(reckoning.get("choices", []).size() == 4, "The companion conversation exposes the four authored resolutions")
	var resolved := DIALOGUE_SERVICE.resolve_chapter(simulation, "aldric_weight_of_command", "shared_command")
	_check(bool(resolved.get("ok", false)), "A companion chapter resolution completes through the authored state machine")
	_check(String(simulation.campaign_journal.quest_state("aldric_weight_of_command").get("status", "")) == "completed", "The chapter completion is recorded in the campaign journal")
	_check(float(RUNTIME_STORE.relationship_state_for(simulation).snapshot("ser_aldric_thorne").get("trust", 0.0)) > 0.0, "The authored chapter resolution updates companion trust")
