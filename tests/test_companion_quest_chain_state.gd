extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_authored_chapter_catalogue()
	_test_chapter_prerequisites_and_flow()
	_test_companion_decision_and_relationship_effects()
	_test_chapter_three_cooldown()
	_test_save_load()
	if _failures > 0:
		push_error("%d companion quest chain assertion(s) failed." % _failures)
		quit(1)
		return
	print("Companion quest chain tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_authored_chapter_catalogue() -> void:
	var chains: Variant = _new_chain_state()
	if chains == null:
		return
	_check(chains.all_chapters().size() == 9, "All nine authored personal quest chapters are loaded")
	var mirabel: Variant = chains.chapter_for("mirabel_borrowed_voice")
	_check(String(mirabel.get("previous", "")) == "mirabel_unquiet_concordance")
	_check(String(mirabel.get("actor_id", "")) == "court_wizard_thessaly")
	_check(String(mirabel.get("reckoning", "")).contains("interpolate"), "Source-authored companion reckoning text is preserved")
	var reyna: Variant = chains.chapter_for("reyna_shared_watch")
	_check(String(reyna.get("actor_id", "")) == "commander_hart", "Commander Hart has a stable actor identifier")


func _test_chapter_prerequisites_and_flow() -> void:
	var journal := CampaignJournal.new()
	_complete_previous(journal, "aldric_measure_of_oath", 100.0)
	var chains: Variant = _new_chain_state()
	if chains == null:
		return
	chains.register_quest_definitions(journal)
	var empty_party_ids: Array[String] = []
	var absent: Variant = chains.can_start("aldric_weight_of_command", journal, empty_party_ids, 50000.0)
	_check(String(absent.get("reason", "")) == "companion_not_in_party")
	var party_ids: Array[String] = ["ser_aldric_thorne"]
	var eligibility: Variant = chains.can_start("aldric_weight_of_command", journal, party_ids, 50000.0)
	_check(bool(eligibility.get("ok", false)))
	var companion_relationships := CompanionRelationshipState.new()
	var started: Variant = chains.start("aldric_weight_of_command", journal, party_ids, companion_relationships, 50000.0)
	_check(bool(started.get("ok", false)))
	_check(float(companion_relationships.snapshot("ser_aldric_thorne").get("familiarity", 0.0)) == 13.0, "Opening a personal chapter records its one-time companion conversation")
	_check(String(journal.quest_state("aldric_weight_of_command").get("chapter_stage", "")) == "consult")
	var wrong_actor: Variant = chains.consult("aldric_weight_of_command", journal, "court_wizard_thessaly", 50100.0)
	_check(String(wrong_actor.get("reason", "")) == "wrong_supporting_character")
	var consulted: Variant = chains.consult("aldric_weight_of_command", journal, "adelram", 50200.0)
	_check(bool(consulted.get("ok", false)))
	_check(String(consulted.get("prompt", "")).contains("Red Ford"))
	_check(bool(journal.quest_state("aldric_weight_of_command").get("consulted", false)))


func _test_companion_decision_and_relationship_effects() -> void:
	var journal := CampaignJournal.new()
	_complete_previous(journal, "aldric_measure_of_oath", 100.0)
	var chains: Variant = _new_chain_state()
	if chains == null:
		return
	chains.register_quest_definitions(journal)
	var party_ids: Array[String] = ["ser_aldric_thorne"]
	var relationships := CompanionRelationshipState.new()
	relationships.ensure("ser_aldric_thorne", "feminine")
	chains.start("aldric_weight_of_command", journal, party_ids, relationships, 50000.0)
	chains.consult("aldric_weight_of_command", journal, "adelram", 50100.0)
	chains.arc_states["ser_aldric_thorne"] = {"sharedBurden":10.0}
	var result: Variant = chains.resolve("aldric_weight_of_command", "companion_decides", journal, relationships, 60000.0)
	_check(bool(result.get("ok", false)))
	_check(String(result.get("effective_resolution", "")) == "shared_command")
	_check(bool(result.get("companion_decided", false)))
	_check(String(result.get("line", "")).contains("chooses for himself."), "The source companion-decided closing line is retained")
	_check(int(result.get("xp_reward", 0)) == 350)
	_check(String(journal.quest_state("aldric_weight_of_command").get("status", "")) == "completed")
	_check(float(relationships.snapshot("ser_aldric_thorne").get("approval", 0.0)) == 56.0, "Companion-decided choice uses its own authored relationship reward")
	_check(float(relationships.snapshot("ser_aldric_thorne").get("trust", 0.0)) == 22.0)
	_check(float(relationships.snapshot("ser_aldric_thorne").get("familiarity", 0.0)) == 19.0)
	_check(float(relationships.snapshot("ser_aldric_thorne").get("friendship", 0.0)) == 26.0)
	_check(float(relationships.snapshot("ser_aldric_thorne").get("romantic_bond", 0.0)) == 3.0)
	_check(float(chains.arc_states["ser_aldric_thorne"].get("sharedBurden", 0.0)) == 34.0)
	_check(float(chains.personality_growth["ser_aldric_thorne"].get("duty", 0.0)) == 1.0)


func _test_chapter_three_cooldown() -> void:
	var journal := CampaignJournal.new()
	_complete_previous(journal, "aldric_measure_of_oath", 1000.0)
	var chains: Variant = _new_chain_state()
	if chains == null:
		return
	chains.register_quest_definitions(journal)
	var party_ids: Array[String] = ["ser_aldric_thorne"]
	var too_soon: Variant = chains.can_start("aldric_weight_of_command", journal, party_ids, 2000.0)
	_check(String(too_soon.get("reason", "")) == "chapter_cooldown")
	var ready: Variant = chains.can_start("aldric_weight_of_command", journal, party_ids, 44200.0)
	_check(bool(ready.get("ok", false)), "The chapter unlocks after the source-authored 12-hour cooldown")


func _test_save_load() -> void:
	var chains: Variant = _new_chain_state()
	if chains == null:
		return
	chains.arc_states["fenn_oakheart"] = {"stewardship":22.0,"independence":16.0}
	chains.personality_growth["fenn_oakheart"] = {"stewardship":1.0}
	var restored: Variant = _new_chain_state()
	if restored == null:
		return
	restored.from_dict(chains.to_dict())
	_check(float(restored.arc_states["fenn_oakheart"].get("stewardship", 0.0)) == 22.0)
	_check(float(restored.personality_growth["fenn_oakheart"].get("stewardship", 0.0)) == 1.0)


func _new_chain_state() -> Variant:
	var script: Script = load("res://scripts/simulation/companion_quest_chain_state.gd") as Script
	if script == null or not script.can_instantiate():
		_failures += 1
		push_error("Companion quest chain state script failed to load or cannot be instantiated.")
		return null
	return script.new()

func _complete_previous(journal: CampaignJournal, quest_id: String, completed_at: float) -> void:
	journal.register_quest_definition({"id":quest_id,"title":"Previous chapter","objectives":[{"id":"done","target":1.0,"required":true}]})
	journal.start_quest(quest_id)
	journal.set_objective_progress(quest_id, "done", 1.0)
	journal.complete_quest(quest_id)
	journal.quests[quest_id]["completed_at"] = completed_at
