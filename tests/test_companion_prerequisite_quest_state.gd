extends SceneTree

const PREREQUISITE_DIALOGUE_SERVICE := preload("res://scripts/simulation/companion_prerequisite_dialogue_service.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_authored_fenn_quest_data()
	_test_clue_gates_and_managed_spillway()
	_test_compensation_cost_is_atomic()
	_test_aldric_broken_vigil_source_data_and_ordinary_evidence()
	_test_aldric_sealed_dispatch_alternative_and_proof_bonus()
	_test_aldric_money_resolution_and_faction_consequences()
	_test_aldric_measure_of_oath_prerequisite_and_literal_self_decision()
	_test_aldric_measure_of_oath_bounded_self_decision()
	_test_prerequisite_dialogue_adapter_routes_npc_evidence()
	_test_campaign_simulation_persists_companion_state()
	if _failures > 0:
		push_error("%d companion prerequisite quest assertion(s) failed." % _failures)
		quit(1)
		return
	print("Companion prerequisite quest tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _new_chain_state() -> Variant:
	var script: Script = load("res://scripts/simulation/companion_quest_chain_state.gd") as Script
	if script == null or not script.can_instantiate():
		_failures += 1
		push_error("Companion quest chain state script failed to load or cannot be instantiated.")
		return null
	return script.new()


func _new_fenn_journal(chains: Variant) -> CampaignJournal:
	var journal := CampaignJournal.new()
	chains.register_quest_definitions(journal)
	return journal


func _start_fenn(chains: Variant, journal: CampaignJournal, relationships: CompanionRelationshipState) -> Dictionary:
	var party_ids: Array[String] = ["fenn_oakheart"]
	return chains.start_prerequisite("fenn_living_boundary", journal, party_ids, relationships, 1000.0)


func _add_fenn_required_clues(chains: Variant, journal: CampaignJournal) -> void:
	chains.add_prerequisite_clue("fenn_living_boundary", "flooded_pasture", "Old Mac", journal, 1100.0)
	chains.add_prerequisite_clue("fenn_living_boundary", "young_marsh", "Elder Nessa Wren", journal, 1200.0)


func _test_authored_fenn_quest_data() -> void:
	var chains: Variant = _new_chain_state()
	if chains == null:
		return
	var quest: Dictionary = chains.prerequisite_for("fenn_living_boundary")
	_check(not quest.is_empty(), "The Living Boundary is loaded from source-authored quest data")
	_check(String(quest.get("title", "")) == "The Living Boundary")
	_check(String(quest.get("clues", {}).get("young_marsh", {}).get("text", "")).contains("medicinal plants"), "The authored habitat evidence is preserved")
	_check(quest.get("resolutions", {}).size() == 4, "All four authored resolution paths are present")
	_check(quest.get("clues", {}).has("old_channel"), "The optional hydrology clue is retained")


func _test_clue_gates_and_managed_spillway() -> void:
	var chains: Variant = _new_chain_state()
	if chains == null:
		return
	var journal := _new_fenn_journal(chains)
	var relationships := CompanionRelationshipState.new()
	var absent_party: Array[String] = []
	var unavailable: Dictionary = chains.start_prerequisite("fenn_living_boundary", journal, absent_party, relationships, 1000.0)
	_check(String(unavailable.get("reason", "")) == "companion_not_in_party")
	var started := _start_fenn(chains, journal, relationships)
	_check(bool(started.get("ok", false)))
	var quest_state := journal.quest_state("fenn_living_boundary")
	_check(quest_state.get("clues", {}).has("changed_flow"), "Opening automatically records the changed drainage clue")
	_check(not chains.can_resolve_prerequisite("fenn_living_boundary", journal))
	chains.add_prerequisite_clue("fenn_living_boundary", "flooded_pasture", "Old Mac", journal, 1100.0)
	_check(not chains.can_resolve_prerequisite("fenn_living_boundary", journal), "Both affected parties must be heard")
	chains.add_prerequisite_clue("fenn_living_boundary", "young_marsh", "Elder Nessa Wren", journal, 1200.0)
	_check(chains.can_resolve_prerequisite("fenn_living_boundary", journal))
	var denied_channel: Dictionary = chains.add_prerequisite_clue("fenn_living_boundary", "old_channel", "Untrained inspection", journal, 1300.0)
	_check(String(denied_channel.get("reason", "")) == "skill_gate_not_met", "The optional old-channel clue requires Nature or Perception")
	var nature_capabilities: Array[String] = ["nature"]
	var discovered_channel: Dictionary = chains.add_prerequisite_clue("fenn_living_boundary", "old_channel", "Nature skill", journal, 1300.0, nature_capabilities)
	_check(bool(discovered_channel.get("changed", false)))
	var player := CharacterState.new("player", "Player")
	var result: Dictionary = chains.resolve_prerequisite("fenn_living_boundary", "managed_spillway", journal, relationships, 1400.0, player)
	_check(bool(result.get("ok", false)))
	_check(String(result.get("line", "")).contains("Not restored. Not untouched. Managed."), "Hydrology knowledge changes the authored resolution line")
	_check(float(result.get("arc_state", {}).get("stewardship", 0.0)) == 12.0)
	_check(float(result.get("arc_state", {}).get("independence", 0.0)) == 13.0)
	_check(float(journal.npc_standings.get("old_mac_human_male", 0.0)) == 6.0)
	_check(float(journal.npc_standings.get("elder_nessa_wren_elf_female", 0.0)) == 6.0)
	_check(bool(result.get("outcome_flags", {}).get("managed_flow", false)))
	_check(String(journal.quest_state("fenn_living_boundary").get("status", "")) == "completed")


func _test_compensation_cost_is_atomic() -> void:
	var chains: Variant = _new_chain_state()
	if chains == null:
		return
	var journal := _new_fenn_journal(chains)
	var relationships := CompanionRelationshipState.new()
	_start_fenn(chains, journal, relationships)
	_add_fenn_required_clues(chains, journal)
	var player := CharacterState.new("player", "Player")
	player.gold = 40
	var options: Array[Dictionary] = chains.prerequisite_resolution_options("fenn_living_boundary", player)
	var compensation: Dictionary = {}
	for option in options:
		if String(option.get("id", "")) == "compensate_preserve":
			compensation = option
	_check(not bool(compensation.get("available", true)), "The compensation choice is disabled when the player cannot afford it")
	var insufficient: Dictionary = chains.resolve_prerequisite("fenn_living_boundary", "compensate_preserve", journal, relationships, 1500.0, player)
	_check(String(insufficient.get("reason", "")) == "insufficient_gold")
	_check(player.gold == 40, "Failed resolution does not spend gold")
	_check(String(journal.quest_state("fenn_living_boundary").get("status", "")) == "active")
	player.gold = 60
	var completed: Dictionary = chains.resolve_prerequisite("fenn_living_boundary", "compensate_preserve", journal, relationships, 1600.0, player)
	_check(bool(completed.get("ok", false)))
	_check(player.gold == 0, "The 60 gold compensation is deducted exactly once")
	_check(bool(completed.get("outcome_flags", {}).get("compensated_farm", false)))


func _new_aldric_quest() -> Dictionary:
	var chains: Variant = _new_chain_state()
	if chains == null:
		return {}
	var journal := CampaignJournal.new()
	chains.register_quest_definitions(journal)
	journal.seed_faction_reputation("ironbond_company", 0.0, 0.0)
	var relationships := CompanionRelationshipState.new()
	var party_ids: Array[String] = ["ser_aldric_thorne"]
	var started: Dictionary = chains.start_prerequisite("aldric_broken_vigil", journal, party_ids, relationships, 2000.0)
	_check(bool(started.get("ok", false)), "Aldric's Broken Vigil starts when Aldric is in the party")
	var starting_relationship: Dictionary = relationships.snapshot("ser_aldric_thorne")
	_check(float(starting_relationship.get("familiarity", 0.0)) == 21.0, "Aldric receives his source-authored rescued-companion familiarity and opening conversation")
	_check(float(starting_relationship.get("trust", 0.0)) == 30.0, "Aldric starts with the source-authored trust value")
	_check(float(starting_relationship.get("approval", 0.0)) == 60.0, "Aldric starts with the source-authored approval value")
	return {"chains":chains,"journal":journal,"relationships":relationships}


func _test_aldric_broken_vigil_source_data_and_ordinary_evidence() -> void:
	var setup := _new_aldric_quest()
	if setup.is_empty():
		return
	var chains: Variant = setup.chains
	var journal: CampaignJournal = setup.journal
	var quest: Dictionary = chains.prerequisite_for("aldric_broken_vigil")
	_check(String(quest.get("title", "")) == "The Broken Vigil")
	var petra_hook: Dictionary = chains.active_prerequisite_for_actor("guildmaster_petra_voss", journal)
	var baron_hook: Dictionary = chains.active_prerequisite_for_actor("baron_corwin_aldervale", journal)
	_check(String(petra_hook.get("quest_id", "")) == "aldric_broken_vigil", "The Ironbond archive NPC is discoverable as an active quest actor")
	_check(String(baron_hook.get("quest_id", "")) == "aldric_broken_vigil", "The Baron is discoverable as an active quest actor")
	_check(quest.get("resolutions", {}).size() == 4, "All four source-authored outcomes are retained")
	_check(quest.get("clues", {}).has("sealed_dispatch"), "The signed dispatch remains a separate proof clue")
	_check(not chains.can_resolve_prerequisite("aldric_broken_vigil", journal))
	chains.add_prerequisite_clue("aldric_broken_vigil", "company_roster", "Petra Voss", journal, 2100.0)
	_check(not chains.can_resolve_prerequisite("aldric_broken_vigil", journal), "The roster alone is insufficient")
	chains.add_prerequisite_clue("aldric_broken_vigil", "baron_customs", "Baron Corwin Aldervale", journal, 2200.0)
	_check(chains.can_resolve_prerequisite("aldric_broken_vigil", journal), "The ordinary investigation path needs both roster and customs evidence")


func _test_aldric_sealed_dispatch_alternative_and_proof_bonus() -> void:
	var setup := _new_aldric_quest()
	if setup.is_empty():
		return
	var chains: Variant = setup.chains
	var journal: CampaignJournal = setup.journal
	var relationships: CompanionRelationshipState = setup.relationships
	var capabilities: Array[String] = ["persuasion"]
	var proof: Dictionary = chains.add_prerequisite_clue("aldric_broken_vigil", "sealed_dispatch", "Persuasion — Ironbond archive", journal, 2300.0, capabilities)
	_check(bool(proof.get("changed", false)), "Persuasion independently unlocks the sealed dispatch")
	_check(journal.quest_state("aldric_broken_vigil").get("clues", {}).has("company_roster"), "The sealed dispatch also records the associated duty roster")
	_check(chains.can_resolve_prerequisite("aldric_broken_vigil", journal), "The signed dispatch is an alternative to the two ordinary clues")
	var player := CharacterState.new("player", "Player")
	var result: Dictionary = chains.resolve_prerequisite("aldric_broken_vigil", "spare_patrol", journal, relationships, 2400.0, player)
	_check(bool(result.get("ok", false)))
	_check(bool(result.get("full_proof", false)))
	_check(int(result.get("xp_reward", 0)) == 300, "Signed proof awards the source-authored 300 XP")
	_check(float(relationships.snapshot("ser_aldric_thorne").get("trust", 0.0)) == 44.0, "Signed proof adds the source-authored two trust bonus to Aldric's start value")


func _test_aldric_money_resolution_and_faction_consequences() -> void:
	var setup := _new_aldric_quest()
	if setup.is_empty():
		return
	var chains: Variant = setup.chains
	var journal: CampaignJournal = setup.journal
	var relationships: CompanionRelationshipState = setup.relationships
	chains.add_prerequisite_clue("aldric_broken_vigil", "company_roster", "Petra Voss", journal, 2100.0)
	chains.add_prerequisite_clue("aldric_broken_vigil", "baron_customs", "Baron Corwin Aldervale", journal, 2200.0)
	var player := CharacterState.new("player", "Player")
	player.gold = 5
	var result: Dictionary = chains.resolve_prerequisite("aldric_broken_vigil", "buried_for_money", journal, relationships, 2500.0, player)
	_check(bool(result.get("ok", false)))
	_check(player.gold == 125, "The source-authored 120 gold settlement is awarded once")
	_check(is_equal_approx(journal.faction_standing("ironbond_company"), 6.0), "The money outcome improves Ironbond standing by six")
	_check(is_equal_approx(float(journal.faction_knowledge.get("ironbond_company", 0.0)), 10.0), "The money outcome records the source knowledge delta")
	_check(is_equal_approx(float(result.get("world_effects", {}).get("surface_power_delta", 0.0)), 2.0), "The source surface-power consequence is exposed to the world runtime")
	_check(is_equal_approx(float(journal.quest_state("aldric_broken_vigil").get("world_effects", {}).get("surface_power_delta", 0.0)), 2.0), "The surface-power consequence is retained in the persistent quest record")
	_check(int(result.get("xp_reward", 0)) == 240, "The ordinary evidence path awards the source-authored 240 XP")
	_check(String(journal.quest_state("aldric_broken_vigil").get("status", "")) == "completed")



func _prepare_aldric_measure(previous_resolution: String) -> Dictionary:
	var setup := _new_aldric_quest()
	if setup.is_empty():
		return {}
	var chains: Variant = setup.chains
	var journal: CampaignJournal = setup.journal
	var relationships: CompanionRelationshipState = setup.relationships
	chains.add_prerequisite_clue("aldric_broken_vigil", "company_roster", "Petra Voss", journal, 2600.0)
	chains.add_prerequisite_clue("aldric_broken_vigil", "baron_customs", "Baron Corwin Aldervale", journal, 2700.0)
	var player := CharacterState.new("player", "Player")
	var completed: Dictionary = chains.resolve_prerequisite("aldric_broken_vigil", previous_resolution, journal, relationships, 2800.0, player)
	_check(bool(completed.get("ok", false)), "The Broken Vigil must complete before its follow-on chapter")
	return setup


func _add_aldric_measure_clues(chains: Variant, journal: CampaignJournal) -> void:
	chains.add_prerequisite_clue("aldric_measure_of_oath", "hospice_need", "Preceptor Garran Vey", journal, 3100.0)
	chains.add_prerequisite_clue("aldric_measure_of_oath", "obedience_vow", "Preceptor Garran Vey", journal, 3100.0)
	chains.add_prerequisite_clue("aldric_measure_of_oath", "adelram_counsel", "High Cleric Adelram", journal, 3200.0)
	chains.add_prerequisite_clue("aldric_measure_of_oath", "service_options", "Preceptor Garran Vey", journal, 3300.0)


func _test_aldric_measure_of_oath_prerequisite_and_literal_self_decision() -> void:
	var setup := _new_aldric_quest()
	if setup.is_empty():
		return
	var chains: Variant = setup.chains
	var journal: CampaignJournal = setup.journal
	var relationships: CompanionRelationshipState = setup.relationships
	var party_ids: Array[String] = ["ser_aldric_thorne"]
	var blocked: Dictionary = chains.start_prerequisite("aldric_measure_of_oath", journal, party_ids, relationships, 3000.0)
	_check(String(blocked.get("reason", "")) == "previous_quest_incomplete", "The Measure of an Oath must remain gated until The Broken Vigil is complete")
	chains.add_prerequisite_clue("aldric_broken_vigil", "company_roster", "Petra Voss", journal, 2600.0)
	chains.add_prerequisite_clue("aldric_broken_vigil", "baron_customs", "Baron Corwin Aldervale", journal, 2700.0)
	var player := CharacterState.new("player", "Player")
	var previous_result: Dictionary = chains.resolve_prerequisite("aldric_broken_vigil", "public_accountability", journal, relationships, 2800.0, player)
	_check(bool(previous_result.get("ok", false)))
	var next_prerequisite: Dictionary = chains.next_prerequisite_for_companion("ser_aldric_thorne", journal, party_ids)
	_check(String(next_prerequisite.get("quest", {}).get("id", "")) == "aldric_measure_of_oath", "Aldric's next eligible personal quest follows The Broken Vigil")
	var started: Dictionary = chains.start_prerequisite("aldric_measure_of_oath", journal, party_ids, relationships, 3000.0)
	_check(bool(started.get("ok", false)))
	var preceptor_hook: Dictionary = chains.active_prerequisite_for_actor("preceptor_garran_vey", journal)
	_check(preceptor_hook.get("clues", []).size() == 2, "Preceptor Garran exposes both linked summons clues in one NPC interaction")
	var adelram_hook: Dictionary = chains.active_prerequisite_for_actor("adelram", journal)
	_check(adelram_hook.is_empty(), "High Cleric Adelram's counsel remains gated until Aldric's obedience vow is established")
	var seeded_arc: Dictionary = chains.arc_states.get("ser_aldric_thorne", {})
	_check(float(seeded_arc.get("discernment", 0.0)) == -5.0, "Public accountability seeds Aldric's discernment from the previous chapter")
	_check(float(seeded_arc.get("sharedBurden", 0.0)) == -15.0, "Public accountability seeds Aldric's shared-burden arc")
	var opening: Dictionary = chains.apply_prerequisite_choice("aldric_measure_of_oath", "discern_first", journal, relationships)
	_check(bool(opening.get("ok", false)))
	var duplicate_opening: Dictionary = chains.apply_prerequisite_choice("aldric_measure_of_oath", "discern_first", journal, relationships)
	_check(bool(duplicate_opening.get("ok", false)) and not bool(duplicate_opening.get("changed", true)), "The opening choice is idempotent")
	var second_opening: Dictionary = chains.apply_prerequisite_choice("aldric_measure_of_oath", "agency", journal, relationships)
	_check(String(second_opening.get("reason", "")) == "opening_choice_already_recorded", "Only one opening response may be selected")
	_add_aldric_measure_clues(chains, journal)
	_check(chains.can_resolve_prerequisite("aldric_measure_of_oath", journal), "All four Order and counsel clues are required")
	var result: Dictionary = chains.resolve_prerequisite("aldric_measure_of_oath", "aldric_decides", journal, relationships, 3400.0, player)
	_check(bool(result.get("ok", false)))
	_check(String(result.get("effective_resolution", "")) == "literal_return", "Aldric's self-decision follows the source arc threshold")
	_check(bool(result.get("outcome_flags", {}).get("future_wardenship", false)), "The literal outcome records future wardenship")
	_check(int(result.get("xp_reward", 0)) == 300)


func _test_aldric_measure_of_oath_bounded_self_decision() -> void:
	var setup := _prepare_aldric_measure("spare_patrol")
	if setup.is_empty():
		return
	var chains: Variant = setup.chains
	var journal: CampaignJournal = setup.journal
	var relationships: CompanionRelationshipState = setup.relationships
	var party_ids: Array[String] = ["ser_aldric_thorne"]
	var started: Dictionary = chains.start_prerequisite("aldric_measure_of_oath", journal, party_ids, relationships, 4000.0)
	_check(bool(started.get("ok", false)))
	var opening: Dictionary = chains.apply_prerequisite_choice("aldric_measure_of_oath", "agency", journal, relationships)
	_check(bool(opening.get("ok", false)))
	_add_aldric_measure_clues(chains, journal)
	var player := CharacterState.new("player", "Player")
	var result: Dictionary = chains.resolve_prerequisite("aldric_measure_of_oath", "aldric_decides", journal, relationships, 4400.0, player)
	_check(bool(result.get("ok", false)))
	_check(String(result.get("effective_resolution", "")) == "bounded_service", "Aldric chooses shared service when either source arc reaches zero")
	_check(bool(result.get("outcome_flags", {}).get("vow_amended", false)), "The bounded outcome records the amended service")
	_check(float(result.get("arc_state", {}).get("discernment", -99.0)) == 8.0, "The self-decision applies its own authored arc delta")



func _test_prerequisite_dialogue_adapter_routes_npc_evidence() -> void:
	var setup := _new_aldric_quest()
	if setup.is_empty():
		return
	var chains: Variant = setup.chains
	var journal: CampaignJournal = setup.journal
	var relationships: CompanionRelationshipState = setup.relationships
	var party_ids: Array[String] = ["ser_aldric_thorne"]
	var companion_dialogue: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.dialogue_for_companion(chains, journal, "ser_aldric_thorne", party_ids)
	_check(String(companion_dialogue.get("quest_id", "")) == "aldric_broken_vigil")
	_check(companion_dialogue.get("choices", []).size() == 2, "The companion adapter exposes the authored opening responses")
	var ordinary_petra: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.actor_prompt(chains, journal, "guildmaster_petra_voss")
	_check(ordinary_petra.get("clues", []).size() == 1, "The ordinary Petra interaction does not expose the sealed dispatch")
	var persuasion: Array[String] = ["persuasion"]
	var skilled_petra: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.actor_prompt(chains, journal, "guildmaster_petra_voss", persuasion)
	_check(skilled_petra.get("clues", []).size() == 2, "Persuasion exposes both the roster and sealed dispatch")
	var recorded: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.record_actor_clues(chains, journal, "guildmaster_petra_voss", 5100.0, persuasion)
	_check(bool(recorded.get("ok", false)))
	_check(bool(recorded.get("can_resolve", false)), "The sealed dispatch provides the alternative full-proof resolution route")
	var ready_dialogue: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.dialogue_for_companion(chains, journal, "ser_aldric_thorne", party_ids)
	_check(ready_dialogue.get("choices", []).size() == 4, "The companion adapter exposes all four authored resolutions when evidence is sufficient")
	var player := CharacterState.new("player", "Player")
	var resolution: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.resolve(chains, journal, relationships, "aldric_broken_vigil", "private_closure", 5200.0, player)
	_check(bool(resolution.get("ok", false)), "The dialogue adapter routes the companion's resolution back to campaign state")

	var measure_setup := _prepare_aldric_measure("public_accountability")
	if measure_setup.is_empty():
		return
	var measure_chains: Variant = measure_setup.chains
	var measure_journal: CampaignJournal = measure_setup.journal
	var measure_relationships: CompanionRelationshipState = measure_setup.relationships
	var measure_party_ids: Array[String] = ["ser_aldric_thorne"]
	var measure_start: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.start_quest(measure_chains, measure_journal, measure_relationships, "aldric_measure_of_oath", measure_party_ids, 6000.0)
	_check(bool(measure_start.get("ok", false)))
	_check(String(measure_journal.quest_state("aldric_measure_of_oath").get("description", "")).contains("Speak with Preceptor Garran Vey"), "The new chapter begins with its first supporting NPC objective")
	var garran_prompt: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.actor_prompt(measure_chains, measure_journal, "preceptor_garran_vey")
	_check(garran_prompt.get("clues", []).size() == 2, "Garran initially exposes the summons and obedience-vow clues")
	var adelram_before: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.actor_prompt(measure_chains, measure_journal, "adelram")
	_check(adelram_before.is_empty(), "Adelram cannot be consulted before the obedience vow is established")
	var garran_recorded: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.record_actor_clues(measure_chains, measure_journal, "preceptor_garran_vey", 6100.0)
	_check(garran_recorded.get("recorded_clues", []).size() == 2)
	_check(String(measure_journal.quest_state("aldric_measure_of_oath").get("description", "")).contains("Speak with High Cleric Adelram"), "The quest journal points the player to the next required NPC")
	var adelram_after: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.actor_prompt(measure_chains, measure_journal, "adelram")
	_check(adelram_after.get("clues", []).size() == 1, "Adelram's counsel unlocks only after the summons conversation")
	var adelram_recorded: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.record_actor_clues(measure_chains, measure_journal, "adelram", 6200.0)
	_check(bool(adelram_recorded.get("ok", false)))
	_check(String(measure_journal.quest_state("aldric_measure_of_oath").get("description", "")).contains("Return to Preceptor Garran Vey"), "The quest journal sends the player back to Garran after counsel")
	var garran_followup: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.actor_prompt(measure_chains, measure_journal, "preceptor_garran_vey")
	_check(garran_followup.get("clues", []).size() == 1, "Garran's service-options clue unlocks after the initial summons and vow")
	var service_options: Dictionary = PREREQUISITE_DIALOGUE_SERVICE.record_actor_clues(measure_chains, measure_journal, "preceptor_garran_vey", 6300.0)
	_check(bool(service_options.get("ok", false)))
	_check(String(measure_journal.quest_state("aldric_measure_of_oath").get("description", "")).contains("Talk to Aldric"), "The completed investigation points back to Aldric for the final decision")



func _test_campaign_simulation_persists_companion_state() -> void:
	var chains: Variant = _new_chain_state()
	if chains == null:
		return
	chains.arc_states["fenn_oakheart"] = {"stewardship":17.0,"independence":-3.0}
	var restored_chains := CompanionQuestChainState.new()
	restored_chains.from_dict(chains.to_dict())
	var relationships := CompanionRelationshipState.new()
	relationships.adjust("fenn_oakheart", {"trust":7.0,"friendship":4.0}, "test:persistence")
	var restored_relationships := CompanionRelationshipState.new()
	restored_relationships.load_dict(relationships.to_dict())
	var arc: Dictionary = restored_chains.arc_states.get("fenn_oakheart", {})
	var relationship: Dictionary = restored_relationships.snapshot("fenn_oakheart")
	_check(is_equal_approx(float(arc.get("stewardship", 0.0)), 17.0), "Companion arc state survives a save round-trip")
	_check(is_equal_approx(float(relationship.get("trust", 0.0)), 17.0), "Companion trust survives a save round-trip")
	_check(is_equal_approx(float(relationship.get("friendship", 0.0)), 20.0), "Companion friendship survives a save round-trip")
