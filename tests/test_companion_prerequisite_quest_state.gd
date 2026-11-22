extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_authored_fenn_quest_data()
	_test_clue_gates_and_managed_spillway()
	_test_compensation_cost_is_atomic()
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
	var denied_channel := chains.add_prerequisite_clue("fenn_living_boundary", "old_channel", "Untrained inspection", journal, 1300.0)
	_check(String(denied_channel.get("reason", "")) == "skill_gate_not_met", "The optional old-channel clue requires Nature or Perception")
	var nature_capabilities: Array[String] = ["nature"]
	var discovered_channel := chains.add_prerequisite_clue("fenn_living_boundary", "old_channel", "Nature skill", journal, 1300.0, nature_capabilities)
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
	var insufficient := chains.resolve_prerequisite("fenn_living_boundary", "compensate_preserve", journal, relationships, 1500.0, player)
	_check(String(insufficient.get("reason", "")) == "insufficient_gold")
	_check(player.gold == 40, "Failed resolution does not spend gold")
	_check(String(journal.quest_state("fenn_living_boundary").get("status", "")) == "active")
	player.gold = 60
	var completed := chains.resolve_prerequisite("fenn_living_boundary", "compensate_preserve", journal, relationships, 1600.0, player)
	_check(bool(completed.get("ok", false)))
	_check(player.gold == 0, "The 60 gold compensation is deducted exactly once")
	_check(bool(completed.get("outcome_flags", {}).get("compensated_farm", false)))
