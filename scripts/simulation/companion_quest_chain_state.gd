class_name CompanionQuestChainState
extends RefCounted
## Data-driven port of the authored personal quest chapters in Hex-crpg.
## CampaignJournal owns quest status/decisions; this class owns companion-arc
## development and the rules that connect a chapter to its companion and actor.

const DATA_PATH := "res://data/quests/companion_quest_chains.json"
const PREREQUISITE_DATA_PATH := "res://data/quests/companion_prerequisite_quests.json"
const CHAPTER_COOLDOWN_SECONDS := 43200.0

var chapters: Dictionary = {}
var prerequisite_quests: Dictionary = {}
var arc_states: Dictionary = {}
var personality_growth: Dictionary = {}


func _init() -> void:
	_load_chapters()


func chapter_for(chapter_id: String) -> Dictionary:
	return chapters.get(chapter_id, {}).duplicate(true)


func all_chapters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for chapter_value in chapters.values():
		var chapter: Dictionary = chapter_value
		result.append(chapter.duplicate(true))
	return result


func register_quest_definitions(journal: CampaignJournal) -> void:
	if journal == null:
		return
	for chapter_value in chapters.values():
		var chapter: Dictionary = chapter_value
		var quest_id := String(chapter.get("id", ""))
		if quest_id.is_empty() or journal.quest_definitions.has(quest_id):
			continue
		journal.register_quest_definition({
			"id": quest_id,
			"title": String(chapter.get("title", quest_id)),
			"description": String(chapter.get("intro", "")),
			"prerequisites": [String(chapter.get("previous", ""))],
			"objectives": [{"id":"resolution","description":"Discuss the chapter with its supporting character and decide how the companion should proceed.","target":1.0,"required":true}]
		})
	for quest_value in prerequisite_quests.values():
		var quest: Dictionary = quest_value
		var prerequisite_id := String(quest.get("id", ""))
		if prerequisite_id.is_empty() or journal.quest_definitions.has(prerequisite_id):
			continue
		journal.register_quest_definition({
			"id":prerequisite_id,
			"title":String(quest.get("title", prerequisite_id)),
			"description":String(quest.get("description", "")),
			"prerequisites":[String(quest.get("previous", ""))] if not String(quest.get("previous", "")).is_empty() else [],
			"objectives":[{"id":"resolution","description":"Investigate the companion’s concern and decide how it should be resolved.","target":1.0,"required":true}]
		})


func can_start(chapter_id: String, journal: CampaignJournal, party_ids: Array[String], world_seconds: float = 0.0) -> Dictionary:
	var chapter: Dictionary = chapters.get(chapter_id, {})
	if chapter.is_empty():
		return {"ok":false,"reason":"unknown_chapter"}
	var companion_id := String(chapter.get("companion_id", ""))
	if not _party_contains_companion(party_ids, companion_id):
		return {"ok":false,"reason":"companion_not_in_party","companion_id":companion_id}
	if journal == null:
		return {"ok":false,"reason":"missing_journal"}
	var previous_id := String(chapter.get("previous", ""))
	var previous := journal.quest_state(previous_id)
	if String(previous.get("status", "")) != "completed":
		return {"ok":false,"reason":"previous_chapter_incomplete","previous_quest_id":previous_id}
	if int(chapter.get("chapter", 1)) >= 3:
		var completed_at: Variant = previous.get("completed_at", previous.get("completedAt", null))
		if completed_at != null and is_finite(float(completed_at)) and world_seconds - float(completed_at) < CHAPTER_COOLDOWN_SECONDS:
			return {"ok":false,"reason":"chapter_cooldown","remaining_seconds":CHAPTER_COOLDOWN_SECONDS - (world_seconds - float(completed_at))}
	if journal.quest_state(chapter_id).size() > 0:
		return {"ok":false,"reason":"chapter_already_started"}
	return {"ok":true,"chapter_id":chapter_id,"companion_id":companion_id}


func start(chapter_id: String, journal: CampaignJournal, party_ids: Array[String], companion_relationships: CompanionRelationshipState, world_seconds: float = 0.0) -> Dictionary:
	if companion_relationships == null:
		return {"ok":false,"reason":"missing_companion_relationship_state"}
	var eligibility := can_start(chapter_id, journal, party_ids, world_seconds)
	if not bool(eligibility.get("ok", false)):
		return eligibility
	var chapter: Dictionary = chapters[chapter_id]
	var started := journal.start_quest(chapter_id)
	if not bool(started.get("ok", false)):
		return started
	var quest_state: Dictionary = journal.quests[chapter_id]
	quest_state["started_at"] = world_seconds
	quest_state["chapter"] = int(chapter.get("chapter", 1))
	quest_state["chapter_stage"] = "consult"
	quest_state["consulted"] = false
	quest_state["offered_at"] = world_seconds
	quest_state["resolution"] = ""
	quest_state["effective_resolution"] = ""
	quest_state["description"] = String(chapter.get("intro", "")) + " Speak with " + String(chapter.get("actor", "the supporting character")) + "."
	journal.quests[chapter_id] = quest_state
	var companion_id := String(chapter.get("companion_id", ""))
	var opening_memory := companion_relationships.note_conversation(companion_id, chapter_id + ":opened", 3.0)
	return {"ok":true,"quest_id":chapter_id,"chapter":chapter.duplicate(true),"stage":"consult","relationship":opening_memory}


func consult(chapter_id: String, journal: CampaignJournal, actor_id: String = "", world_seconds: float = 0.0) -> Dictionary:
	var chapter: Dictionary = chapters.get(chapter_id, {})
	if chapter.is_empty() or journal == null:
		return {"ok":false,"reason":"unknown_chapter_or_missing_journal"}
	var expected_actor := String(chapter.get("actor_id", ""))
	if not actor_id.is_empty() and not expected_actor.is_empty() and actor_id != expected_actor:
		return {"ok":false,"reason":"wrong_supporting_character","expected_actor_id":expected_actor}
	if not journal.quests.has(chapter_id):
		return {"ok":false,"reason":"chapter_not_started"}
	var quest_state: Dictionary = journal.quests[chapter_id]
	if String(quest_state.get("status", "")) != "active":
		return {"ok":false,"reason":"chapter_not_active"}
	quest_state["consulted"] = true
	quest_state["chapter_stage"] = "reckoning"
	quest_state["consulted_at"] = world_seconds
	quest_state["description"] = String(chapter.get("actor", "The supporting character")) + " has given you the missing context. Talk to " + String(chapter.get("companion", "your companion")) + " and decide what comes next."
	journal.quests[chapter_id] = quest_state
	return {
		"ok":true,
		"chapter_id":chapter_id,
		"actor_id":expected_actor,
		"actor":String(chapter.get("actor", "")),
		"text":String(chapter.get("actorText", "")),
		"prompt":String(chapter.get("actorPrompt", "")),
		"reckoning":String(chapter.get("reckoning", ""))
	}


func resolve(chapter_id: String, requested_resolution: String, journal: CampaignJournal, companion_relationships: CompanionRelationshipState, world_seconds: float = 0.0) -> Dictionary:
	var chapter: Dictionary = chapters.get(chapter_id, {})
	if chapter.is_empty() or journal == null or not journal.quests.has(chapter_id):
		return {"ok":false,"reason":"chapter_not_started"}
	if companion_relationships == null:
		return {"ok":false,"reason":"missing_companion_relationship_state"}
	var quest_state: Dictionary = journal.quests[chapter_id]
	if String(quest_state.get("status", "")) != "active":
		return {"ok":false,"reason":"chapter_not_active"}
	if not bool(quest_state.get("consulted", false)):
		return {"ok":false,"reason":"supporting_character_not_consulted"}
	var resolutions: Dictionary = chapter.get("resolutions", {})
	if not resolutions.has(requested_resolution):
		return {"ok":false,"reason":"unknown_resolution"}
	var effective_resolution := requested_resolution
	if requested_resolution == "companion_decides":
		effective_resolution = _resolve_companion_decision(chapter_id, arc_states.get(String(chapter.get("companion_id", "")), {}))
	if not resolutions.has(effective_resolution):
		return {"ok":false,"reason":"companion_decision_unresolved"}
	var requested_effect: Dictionary = resolutions[requested_resolution]
	var effect: Dictionary = resolutions[effective_resolution]
	var reward: Dictionary = requested_effect if requested_resolution == "companion_decides" else effect
	var decision := journal.record_decision(chapter_id, "resolution", requested_resolution)
	if not bool(decision.get("ok", false)):
		return decision
	var progress := journal.set_objective_progress(chapter_id, "resolution", 1.0)
	if not bool(progress.get("ok", false)):
		return progress
	var completion := journal.complete_quest(chapter_id)
	if not bool(completion.get("ok", false)):
		return completion
	quest_state = journal.quests[chapter_id]
	quest_state["chapter_stage"] = "completed"
	quest_state["completed_at"] = world_seconds
	quest_state["resolution"] = requested_resolution
	quest_state["effective_resolution"] = effective_resolution
	quest_state["completion_reason"] = String(effect.get("reason", chapter.get("title", "")))
	journal.quests[chapter_id] = quest_state

	var companion_id := String(chapter.get("companion_id", ""))
	var companion_name := String(chapter.get("companion", "your companion"))
	var reason := String(effect.get("reason", chapter.get("title", "")))
	var reward_reason := String(reward.get("reason", chapter.get("title", "")))
	if companion_relationships != null:
		var relationship_changes: Dictionary = reward.get("relationship", {})
		if not relationship_changes.is_empty():
			companion_relationships.record_event(companion_id, "quest_chain:" + chapter_id + ":relationship", relationship_changes, reward_reason)
		var affinity_changes: Dictionary = reward.get("affinity", {})
		var normalized_affinity: Dictionary = {}
		for axis_value in affinity_changes:
			var axis := String(axis_value)
			match axis:
				"romanticBond": normalized_affinity["romantic_bond"] = affinity_changes[axis_value]
				"friendship", "attraction": normalized_affinity[axis] = affinity_changes[axis_value]
		if not normalized_affinity.is_empty():
			companion_relationships.record_event(companion_id, "quest_chain:" + chapter_id + ":affinity", normalized_affinity, reward_reason)

	var arc_state: Dictionary = arc_states.get(companion_id, {})
	for trait_value in effect.get("arc", {}).keys():
		var arc_trait := String(trait_value)
		arc_state[arc_trait] = float(arc_state.get(arc_trait, 0.0)) + float(effect.arc[trait_value])
	arc_states[companion_id] = arc_state
	var growth: Dictionary = personality_growth.get(companion_id, {})
	for trait_pair_value in chapter.get("personality", []):
		var trait_pair: Array = trait_pair_value
		if trait_pair.size() >= 2:
			var trait_name := String(trait_pair[0])
			growth[trait_name] = float(growth.get(trait_name, 0.0)) + float(trait_pair[1])
	personality_growth[companion_id] = growth
	var result_line := String(effect.get("line", "The decision is made."))
	if requested_resolution == "companion_decides":
		var pronoun := "himself" if companion_id in ["ser_aldric_thorne", "brother_alden", "fenn_oakheart"] else "herself"
		result_line += "\n\nGiven the choice, " + companion_name + " chooses for " + pronoun + "."
	return {
		"ok":true,
		"quest_id":chapter_id,
		"requested_resolution":requested_resolution,
		"effective_resolution":effective_resolution,
		"reason":reason,
		"line":result_line,
		"companion_decided":requested_resolution == "companion_decides",
		"xp_reward":int(chapter.get("xp", 0)),
		"relationship":reward.get("relationship", {}).duplicate(true),
		"affinity":reward.get("affinity", {}).duplicate(true),
		"arc_state":arc_state.duplicate(true),
		"personality_growth":growth.duplicate(true),
		"requested_choice_reason":reward_reason
	}


func prerequisite_for(quest_id: String) -> Dictionary:
	return prerequisite_quests.get(quest_id, {}).duplicate(true)


func all_prerequisite_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_value in prerequisite_quests.values():
		var quest: Dictionary = quest_value
		result.append(quest.duplicate(true))
	return result


func start_prerequisite(quest_id: String, journal: CampaignJournal, party_ids: Array[String], companion_relationships: CompanionRelationshipState, world_seconds: float = 0.0) -> Dictionary:
	var definition: Dictionary = prerequisite_quests.get(quest_id, {})
	if definition.is_empty():
		return {"ok":false,"reason":"unknown_prerequisite_quest"}
	if journal == null:
		return {"ok":false,"reason":"missing_journal"}
	var companion_id := String(definition.get("companion_id", ""))
	if not _party_contains_companion(party_ids, companion_id):
		return {"ok":false,"reason":"companion_not_in_party","companion_id":companion_id}
	var previous_id := String(definition.get("previous", ""))
	if not previous_id.is_empty() and String(journal.quest_state(previous_id).get("status", "")) != "completed":
		return {"ok":false,"reason":"previous_quest_incomplete","previous_quest_id":previous_id}
	if companion_relationships == null:
		return {"ok":false,"reason":"missing_companion_relationship_state"}
	register_quest_definitions(journal)
	var started := journal.start_quest(quest_id)
	if not bool(started.get("ok", false)):
		return started
	var quest_state: Dictionary = journal.quests[quest_id]
	quest_state["started_at"] = world_seconds
	quest_state["clues"] = {}
	quest_state["clue_order"] = []
	quest_state["chapter_stage"] = "investigation"
	quest_state["resolution"] = ""
	quest_state["description"] = String(definition.get("description", ""))
	var initial_stage_rules: Array = definition.get("stage_rules", [])
	if not initial_stage_rules.is_empty():
		var initial_rule: Dictionary = initial_stage_rules[initial_stage_rules.size() - 1]
		quest_state["chapter_stage"] = String(initial_rule.get("stage", "investigation"))
		quest_state["description"] = String(initial_rule.get("description", quest_state["description"]))
	journal.quests[quest_id] = quest_state
	if quest_id == "aldric_broken_vigil":
		var aldric_state: Dictionary = companion_relationships.ensure(companion_id)
		var aldric_history: Array = aldric_state.get("history", [])
		if aldric_history.is_empty() and is_equal_approx(float(aldric_state.get("familiarity", 10.0)), 10.0) and is_equal_approx(float(aldric_state.get("trust", 10.0)), 10.0):
			companion_relationships.adjust(companion_id, {"familiarity":8.0,"trust":20.0,"approval":10.0}, "authored_start:aldric_rescued_companion")
	var arc_seed_by_previous: Dictionary = definition.get("arc_seed_by_previous_resolution", {})
	if not arc_seed_by_previous.is_empty():
		var existing_arc: Dictionary = arc_states.get(companion_id, {})
		if not bool(existing_arc.get("_seeded_from_broken_vigil", false)):
			var initial_arc: Dictionary = definition.get("arc_initial", {}).duplicate(true)
			var previous_resolution := String(journal.quest_state(previous_id).get("resolution", ""))
			var arc_seed: Dictionary = arc_seed_by_previous.get(previous_resolution, {})
			for trait_value in arc_seed:
				var trait_name := String(trait_value)
				initial_arc[trait_name] = float(existing_arc.get(trait_name, float(initial_arc.get(trait_name, 0.0)) + float(arc_seed[trait_value])))
			initial_arc["_seeded_from_broken_vigil"] = true
			arc_states[companion_id] = initial_arc
	companion_relationships.note_conversation(companion_id, quest_id + ":opened", 3.0)
	for clue_id_value in definition.get("clues", {}).keys():
		var clue_id := String(clue_id_value)
		var clue: Dictionary = definition.clues[clue_id]
		if bool(clue.get("automatic", false)):
			add_prerequisite_clue(quest_id, clue_id, "companion opening conversation", journal, world_seconds)
	return {"ok":true,"quest_id":quest_id,"quest":definition.duplicate(true),"quest_state":journal.quest_state(quest_id)}



func apply_prerequisite_choice(quest_id: String, choice_id: String, journal: CampaignJournal, companion_relationships: CompanionRelationshipState) -> Dictionary:
	var definition: Dictionary = prerequisite_quests.get(quest_id, {})
	if definition.is_empty() or journal == null or companion_relationships == null:
		return {"ok":false,"reason":"unknown_quest_or_missing_state"}
	var quest_state := journal.quest_state(quest_id)
	if String(quest_state.get("status", "")) != "active":
		return {"ok":false,"reason":"quest_not_active"}
	var selected: Dictionary = {}
	for choice_value in definition.get("opening_choices", []):
		var choice: Dictionary = choice_value
		if String(choice.get("id", "")) == choice_id:
			selected = choice
			break
	if selected.is_empty():
		return {"ok":false,"reason":"unknown_opening_choice"}
	var choice_keys: Array = quest_state.get("opening_choice_keys", [])
	if choice_keys.has(choice_id):
		return {"ok":true,"changed":false}
	if not choice_keys.is_empty():
		return {"ok":false,"reason":"opening_choice_already_recorded"}
	choice_keys.append(choice_id)
	quest_state["opening_choice_keys"] = choice_keys
	journal.quests[quest_id] = quest_state
	var companion_id := String(definition.get("companion_id", ""))
	var arc_state: Dictionary = arc_states.get(companion_id, {})
	for trait_value in selected.get("arc", {}).keys():
		var trait_name := String(trait_value)
		arc_state[trait_name] = float(arc_state.get(trait_name, 0.0)) + float(selected.arc[trait_value])
	arc_states[companion_id] = arc_state
	var reason := String(selected.get("reason", "companion quest opening choice"))
	var relationship_delta: Dictionary = selected.get("relationship", {})
	if not relationship_delta.is_empty():
		companion_relationships.record_event(companion_id, "prerequisite_quest:" + quest_id + ":opening:" + choice_id + ":relationship", relationship_delta, reason)
	var affinity_delta: Dictionary = selected.get("affinity", {})
	var normalized_affinity: Dictionary = {}
	for axis_value in affinity_delta:
		var axis := String(axis_value)
		match axis:
			"romanticBond":
				normalized_affinity["romantic_bond"] = affinity_delta[axis_value]
			"friendship", "attraction":
				normalized_affinity[axis] = affinity_delta[axis_value]
	if not normalized_affinity.is_empty():
		companion_relationships.record_event(companion_id, "prerequisite_quest:" + quest_id + ":opening:" + choice_id + ":affinity", normalized_affinity, reason)
	return {"ok":true,"changed":true,"arc_state":arc_state.duplicate(true)}


func add_prerequisite_clue(quest_id: String, clue_id: String, source: String, journal: CampaignJournal, world_seconds: float = 0.0, capabilities: Array[String] = []) -> Dictionary:
	var definition: Dictionary = prerequisite_quests.get(quest_id, {})
	if definition.is_empty() or journal == null:
		return {"ok":false,"reason":"unknown_quest_or_missing_journal"}
	var clue_definitions: Dictionary = definition.get("clues", {})
	if not clue_definitions.has(clue_id):
		return {"ok":false,"reason":"unknown_clue"}
	var quest_state := journal.quest_state(quest_id)
	if String(quest_state.get("status", "")) != "active":
		return {"ok":false,"reason":"quest_not_active"}
	var clues: Dictionary = quest_state.get("clues", {})
	if clues.has(clue_id):
		return {"ok":true,"changed":false,"clue":clues[clue_id].duplicate(true)}
	var clue: Dictionary = clue_definitions[clue_id]
	var access_any: Array = clue.get("access_any", [])
	if not access_any.is_empty():
		var access_granted := false
		for access_value in access_any:
			var access_id := String(access_value)
			match access_id:
				"ironbond_standing_20":
					access_granted = journal.faction_standing("ironbond_company") >= 20.0
				_:
					access_granted = capabilities.has(access_id)
			if access_granted:
				break
		if not access_granted:
			return {"ok":false,"reason":"access_gate_not_met","required_access":access_any.duplicate()}
	var skill_gate := String(clue.get("skill_gate", ""))
	if skill_gate == "nature_or_perception" and not capabilities.has("nature") and not capabilities.has("perception"):
		return {"ok":false,"reason":"skill_gate_not_met","required_capability":"nature_or_perception"}
	var capability_any: Array = clue.get("capability_any", [])
	if not capability_any.is_empty():
		var has_capability := false
		for capability_value in capability_any:
			if capabilities.has(String(capability_value)):
				has_capability = true
				break
		if not has_capability:
			return {"ok":false,"reason":"skill_gate_not_met","required_capabilities":capability_any.duplicate()}
	if bool(clue.get("requires_stealth", false)) and not capabilities.has("stealth"):
		return {"ok":false,"reason":"skill_gate_not_met","required_capability":"stealth"}
	var faction_id := String(clue.get("faction_id", ""))
	var faction_standing_min := float(clue.get("faction_standing_min", -1000.0))
	if not faction_id.is_empty() and journal.faction_standing(faction_id) < faction_standing_min:
		return {"ok":false,"reason":"faction_standing_too_low","faction_id":faction_id,"required_standing":faction_standing_min}
	clues[clue_id] = {
		"found":true,
		"source":source,
		"text":String(clue.get("text", "")),
		"at":world_seconds
	}
	quest_state["clues"] = clues
	var clue_order: Array = quest_state.get("clue_order", [])
	clue_order.append(clue_id)
	quest_state["clue_order"] = clue_order
	journal.quests[quest_id] = quest_state
	for linked_clue_value in clue.get("also_add_clues", []):
		var linked_clue_id := String(linked_clue_value)
		if not clues.has(linked_clue_id):
			add_prerequisite_clue(quest_id, linked_clue_id, source + " (linked evidence)", journal, world_seconds, capabilities)
	quest_state = journal.quest_state(quest_id)
	clues = quest_state.get("clues", {})
	var stage_rules: Array = definition.get("stage_rules", [])
	var stage_applied := false
	for rule_value in stage_rules:
		var rule: Dictionary = rule_value
		var requirements_met := true
		for required_clue_value in rule.get("required_clues", []):
			if not clues.has(String(required_clue_value)):
				requirements_met = false
				break
		if requirements_met:
			quest_state["chapter_stage"] = String(rule.get("stage", "investigation"))
			quest_state["description"] = String(rule.get("description", definition.get("description", "")))
			stage_applied = true
			break
	if not stage_applied and can_resolve_prerequisite(quest_id, journal):
		quest_state["chapter_stage"] = "reckoning"
		quest_state["description"] = String(definition.get("ready_description", quest_state.get("description", "")))
	journal.quests[quest_id] = quest_state
	return {"ok":true,"changed":true,"clue":clues[clue_id].duplicate(true),"can_resolve":can_resolve_prerequisite(quest_id, journal)}


func can_resolve_prerequisite(quest_id: String, journal: CampaignJournal) -> bool:
	var definition: Dictionary = prerequisite_quests.get(quest_id, {})
	if definition.is_empty() or journal == null:
		return false
	var quest_state := journal.quest_state(quest_id)
	if String(quest_state.get("status", "")) != "active":
		return false
	var clues: Dictionary = quest_state.get("clues", {})
	var required_sets: Array = definition.get("required_clue_sets", [])
	if not required_sets.is_empty():
		for set_value in required_sets:
			if not (set_value is Array):
				continue
			var complete_set := true
			for required_value in set_value:
				if not clues.has(String(required_value)):
					complete_set = false
					break
			if complete_set:
				return true
		return false
	for required_value in definition.get("required_clues", []):
		if not clues.has(String(required_value)):
			return false
	return true


func prerequisite_resolution_options(quest_id: String, player_state: CharacterState = null) -> Array[Dictionary]:
	var definition: Dictionary = prerequisite_quests.get(quest_id, {})
	var resolutions: Dictionary = definition.get("resolutions", {})
	var options: Array[Dictionary] = []
	for resolution_id_value in resolutions.keys():
		var resolution_id := String(resolution_id_value)
		var resolution: Dictionary = resolutions[resolution_id]
		var cost := int(resolution.get("cost_gold", 0))
		var available := cost == 0 or (player_state != null and player_state.gold >= cost)
		options.append({
			"id":resolution_id,
			"label":String(resolution.get("label", resolution_id)),
			"available":available,
			"unavailable_reason":"Requires %d gold." % cost if not available else ""
		})
	return options


func resolve_prerequisite(quest_id: String, resolution_id: String, journal: CampaignJournal, companion_relationships: CompanionRelationshipState, world_seconds: float = 0.0, player_state: CharacterState = null) -> Dictionary:
	var definition: Dictionary = prerequisite_quests.get(quest_id, {})
	if definition.is_empty() or journal == null:
		return {"ok":false,"reason":"unknown_quest_or_missing_journal"}
	if companion_relationships == null:
		return {"ok":false,"reason":"missing_companion_relationship_state"}
	if not can_resolve_prerequisite(quest_id, journal):
		return {"ok":false,"reason":"required_clues_missing"}
	var resolutions: Dictionary = definition.get("resolutions", {})
	if not resolutions.has(resolution_id):
		return {"ok":false,"reason":"unknown_resolution"}
	var effect: Dictionary = resolutions[resolution_id]
	var effective_resolution := resolution_id
	var companion_decision: Dictionary = effect.get("companion_decision", {})
	if not companion_decision.is_empty():
		var decision_arc: Dictionary = arc_states.get(String(definition.get("companion_id", "")), {})
		var any_nonnegative := false
		for trait_value in companion_decision.get("trait_any_gte_zero", []):
			if float(decision_arc.get(String(trait_value), -1.0)) >= 0.0:
				any_nonnegative = true
				break
		effective_resolution = String(companion_decision.get("if_true" if any_nonnegative else "if_false", resolution_id))
		if not resolutions.has(effective_resolution):
			return {"ok":false,"reason":"companion_decision_unresolved"}
	var effective_effect: Dictionary = resolutions[effective_resolution]
	var gold_cost := int(effect.get("cost_gold", 0))
	var gold_reward := int(effect.get("gold_reward", 0))
	if (gold_cost > 0 or gold_reward > 0) and player_state == null:
		return {"ok":false,"reason":"missing_player_state","required_gold":gold_cost}
	if gold_cost > 0 and player_state.gold < gold_cost:
		return {"ok":false,"reason":"insufficient_gold","required_gold":gold_cost,"available_gold":player_state.gold}
	var decision := journal.record_decision(quest_id, "resolution", resolution_id)
	if not bool(decision.get("ok", false)):
		return decision
	var progress := journal.set_objective_progress(quest_id, "resolution", 1.0)
	if not bool(progress.get("ok", false)):
		return progress
	var completion := journal.complete_quest(quest_id)
	if not bool(completion.get("ok", false)):
		return completion
	if gold_cost > 0:
		player_state.gold -= gold_cost
	if gold_reward > 0:
		player_state.gold += gold_reward
	var quest_state := journal.quest_state(quest_id)
	var companion_id := String(definition.get("companion_id", ""))
	var clues: Dictionary = quest_state.get("clues", {})
	var has_sealed_dispatch := clues.has("sealed_dispatch")
	var has_old_channel := clues.has("old_channel")
	var relationship_delta: Dictionary = effect.get("relationship", {}).duplicate(true)
	if has_sealed_dispatch:
		var proof_bonus: Dictionary = effect.get("full_proof_relationship_bonus", {})
		for axis_value in proof_bonus:
			var proof_axis := String(axis_value)
			relationship_delta[proof_axis] = float(relationship_delta.get(proof_axis, 0.0)) + float(proof_bonus[axis_value])
	if resolution_id == "managed_spillway" and has_old_channel:
		var channel_bonus: Dictionary = effect.get("channel_relationship_bonus", {})
		for axis_value in channel_bonus:
			var axis := String(axis_value)
			relationship_delta[axis] = float(relationship_delta.get(axis, 0.0)) + float(channel_bonus[axis_value])
	var affinity_delta: Dictionary = effect.get("affinity", {})
	var reason := String(effect.get("reason", "resolved " + String(definition.get("title", quest_id))))
	companion_relationships.record_event(companion_id, "prerequisite_quest:" + quest_id + ":relationship", relationship_delta, reason)
	var normalized_affinity: Dictionary = {}
	for axis_value in affinity_delta:
		var axis := String(axis_value)
		match axis:
			"romanticBond":
				normalized_affinity["romantic_bond"] = affinity_delta[axis_value]
			"friendship", "attraction":
				normalized_affinity[axis] = affinity_delta[axis_value]
	if not normalized_affinity.is_empty():
		companion_relationships.record_event(companion_id, "prerequisite_quest:" + quest_id + ":affinity", normalized_affinity, reason)
	var arc_state: Dictionary = arc_states.get(companion_id, {})
	var arc_delta: Dictionary = effect.get("arc", {})
	for trait_value in arc_delta:
		var arc_trait := String(trait_value)
		arc_state[arc_trait] = float(arc_state.get(arc_trait, 0.0)) + float(arc_delta[trait_value])
	arc_states[companion_id] = arc_state
	var npc_reputation: Dictionary = effect.get("npc_reputation", {})
	for npc_id_value in npc_reputation:
		var npc_id := String(npc_id_value)
		var reputation: Dictionary = npc_reputation[npc_id]
		journal.adjust_npc_reputation(npc_id, float(reputation.get("standing", 0.0)), float(reputation.get("knowledge", 0.0)), reason)
	var faction_reputation: Dictionary = effect.get("faction_reputation", {})
	for faction_id_value in faction_reputation:
		var faction_id := String(faction_id_value)
		var faction_change: Dictionary = faction_reputation[faction_id]
		journal.adjust_faction_reputation(faction_id, float(faction_change.get("standing", 0.0)), float(faction_change.get("knowledge", 0.0)), reason)
	var flags: Dictionary = effective_effect.get("flags", effect.get("flags", {})).duplicate(true)
	if quest_id == "fenn_living_boundary":
		flags["hydrology_understood"] = has_old_channel
	quest_state["chapter_stage"] = "completed"
	quest_state["resolution"] = resolution_id
	quest_state["effective_resolution"] = effective_resolution
	quest_state["completed_at"] = world_seconds
	quest_state["completion_reason"] = reason
	quest_state["outcome_flags"] = flags
	var world_effects := {"surface_power_delta":float(effect.get("surface_power_delta", 0.0))}
	quest_state["world_effects"] = world_effects.duplicate(true)
	quest_state["description"] = String(effective_effect.get("description", effect.get("description", definition.get("description", ""))))
	journal.quests[quest_id] = quest_state
	var result_line := String(effect.get("line", "The decision is made."))
	var xp_reward := int(definition.get("xp", 0))
	if has_sealed_dispatch:
		xp_reward += int(definition.get("full_proof_xp_bonus", 0))
	if resolution_id == "managed_spillway" and has_old_channel:
		result_line = String(effect.get("line_with_channel", result_line))
	return {
		"ok":true,
		"quest_id":quest_id,
		"resolution":resolution_id,
		"effective_resolution":effective_resolution,
		"line":result_line,
		"xp_reward":xp_reward,
		"relationship":relationship_delta,
		"affinity":affinity_delta.duplicate(true),
		"arc_state":arc_state.duplicate(true),
		"outcome_flags":flags,
		"gold_spent":gold_cost,
		"gold_awarded":gold_reward,
		"full_proof":has_sealed_dispatch,
		"world_effects":world_effects.duplicate(true)
	}


func next_chapter_for(companion_id: String, journal: CampaignJournal, party_ids: Array[String], world_seconds: float = 0.0) -> Dictionary:
	for chapter_value in chapters.values():
		var chapter: Dictionary = chapter_value
		if String(chapter.get("companion_id", "")) != companion_id:
			continue
		var quest_state := journal.quest_state(String(chapter.id))
		if String(quest_state.get("status", "")) == "active":
			return {"chapter":chapter.duplicate(true),"quest_state":quest_state.duplicate(true)}
		var eligible := can_start(String(chapter.id), journal, party_ids, world_seconds)
		if bool(eligible.get("ok", false)):
			return {"chapter":chapter.duplicate(true),"quest_state":{}}
	return {}


func active_chapter_for_actor(actor_id: String, journal: CampaignJournal) -> Dictionary:
	if actor_id.is_empty() or journal == null:
		return {}
	for chapter_value in chapters.values():
		var chapter: Dictionary = chapter_value
		if String(chapter.get("actor_id", "")) != actor_id:
			continue
		var quest_state := journal.quest_state(String(chapter.get("id", "")))
		if String(quest_state.get("status", "")) == "active" and not bool(quest_state.get("consulted", false)):
			return {"chapter":chapter.duplicate(true),"quest_state":quest_state}
	return {}


func next_prerequisite_for_companion(companion_id: String, journal: CampaignJournal, party_ids: Array[String]) -> Dictionary:
	if journal == null or not _party_contains_companion(party_ids, companion_id):
		return {}
	for quest_value in prerequisite_quests.values():
		var definition: Dictionary = quest_value
		if String(definition.get("companion_id", "")) != companion_id:
			continue
		var quest_id := String(definition.get("id", ""))
		var quest_state := journal.quest_state(quest_id)
		if String(quest_state.get("status", "")) == "active":
			return {"quest":definition.duplicate(true),"quest_state":quest_state.duplicate(true)}
		if not quest_state.is_empty():
			continue
		var previous_id := String(definition.get("previous", ""))
		if not previous_id.is_empty() and String(journal.quest_state(previous_id).get("status", "")) != "completed":
			continue
		return {"quest":definition.duplicate(true),"quest_state":{}}
	return {}


func active_prerequisite_for_actor(actor_id: String, journal: CampaignJournal) -> Dictionary:
	if actor_id.strip_edges().is_empty() or journal == null:
		return {}
	for quest_value in prerequisite_quests.values():
		var definition: Dictionary = quest_value
		var quest_id := String(definition.get("id", ""))
		var quest_state := journal.quest_state(quest_id)
		if String(quest_state.get("status", "")) != "active":
			continue
		var found_clues: Array[Dictionary] = []
		var known_clues: Dictionary = quest_state.get("clues", {})
		var clue_definitions: Dictionary = definition.get("clues", {})
		for clue_id_value in clue_definitions.keys():
			var clue_id := String(clue_id_value)
			var clue: Dictionary = clue_definitions[clue_id]
			if String(clue.get("actor_id", "")) != actor_id or known_clues.has(clue_id):
				continue
			var prerequisites_met := true
			for required_clue_value in clue.get("requires_clues", []):
				if not known_clues.has(String(required_clue_value)):
					prerequisites_met = false
					break
			if not prerequisites_met:
				continue
			found_clues.append({"id":clue_id,"definition":clue.duplicate(true)})
		if not found_clues.is_empty():
			return {
				"quest_id":quest_id,
				"title":String(definition.get("title", quest_id)),
				"companion_id":String(definition.get("companion_id", "")),
				"quest_state":quest_state.duplicate(true),
				"clues":found_clues
			}
	return {}


func resolution_options(chapter_id: String) -> Array[Dictionary]:
	var chapter: Dictionary = chapters.get(chapter_id, {})
	var resolutions: Dictionary = chapter.get("resolutions", {})
	var options: Array[Dictionary] = []
	for resolution_id in resolutions:
		var resolution: Dictionary = resolutions[resolution_id]
		options.append({"id":String(resolution_id),"label":String(resolution.get("label", "")),"available":true})
	return options


func _party_contains_companion(party_ids: Array[String], companion_id: String) -> bool:
	return party_ids.has(companion_id) or party_ids.has("companion_" + companion_id)


func to_dict() -> Dictionary:
	return {"version":1,"arc_states":arc_states.duplicate(true),"personality_growth":personality_growth.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	var arcs: Variant = data.get("arc_states", {})
	var growth: Variant = data.get("personality_growth", {})
	arc_states = arcs.duplicate(true) if arcs is Dictionary else {}
	personality_growth = growth.duplicate(true) if growth is Dictionary else {}


func _load_chapters() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_error("Missing companion quest chain data: " + DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not (parsed is Dictionary):
		push_error("Invalid companion quest chain JSON.")
		return
	var chapter_list: Variant = parsed.get("chapters", [])
	if not (chapter_list is Array):
		push_error("Companion quest chain JSON has no chapter list.")
		return
	for chapter_value in chapter_list:
		if not (chapter_value is Dictionary):
			continue
		var chapter: Dictionary = chapter_value
		var chapter_id := String(chapter.get("id", ""))
		if not chapter_id.is_empty():
			chapters[chapter_id] = chapter.duplicate(true)
	_load_prerequisite_quests()


func _load_prerequisite_quests() -> void:
	if not FileAccess.file_exists(PREREQUISITE_DATA_PATH):
		push_error("Missing companion prerequisite quest data: " + PREREQUISITE_DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREREQUISITE_DATA_PATH))
	if not (parsed is Dictionary):
		push_error("Invalid companion prerequisite quest JSON.")
		return
	var quest_list: Variant = parsed.get("quests", [])
	if not (quest_list is Array):
		push_error("Companion prerequisite quest JSON has no quest list.")
		return
	for quest_value in quest_list:
		if not (quest_value is Dictionary):
			continue
		var quest: Dictionary = quest_value
		var quest_id := String(quest.get("id", ""))
		if not quest_id.is_empty():
			prerequisite_quests[quest_id] = quest.duplicate(true)


func _resolve_companion_decision(chapter_id: String, arc_state: Dictionary) -> String:
	match chapter_id:
		"aldric_weight_of_command":
			return "shared_command" if float(arc_state.get("sharedBurden", 0.0)) >= 0.0 else "take_every_burden"
		"mirabel_borrowed_voice":
			return "limited_testimony" if float(arc_state.get("restraint", 0.0)) >= 0.0 else "full_reconstruction"
		"mirabel_place_for_dangerous_books":
			var rootedness := float(arc_state.get("rootedness", 0.0))
			return "accept_curatorship" if rootedness >= 30.0 else ("shared_archive" if rootedness >= 0.0 or float(arc_state.get("restraint", 0.0)) >= 15.0 else "keep_wandering")
		"fenn_fire_in_understory":
			return "mosaic_burn" if float(arc_state.get("stewardship", 0.0)) >= 5.0 and float(arc_state.get("independence", 0.0)) >= 0.0 else "hand_clear"
		"fenn_groves_answer":
			var independence := float(arc_state.get("independence", 0.0))
			return "changed_charter" if independence >= 20.0 else ("return_traditional" if independence <= -20.0 else "remain_outside")
		"reyna_shared_watch":
			var interdependence := float(arc_state.get("interdependence", 0.0))
			return "joint_watch" if interdependence >= 10.0 and float(arc_state.get("institutionalTrust", 0.0)) >= 0.0 else ("private_network" if interdependence >= 0.0 else "reyna_centre")
		"reyna_rangers_writ":
			var institutional_trust := float(arc_state.get("institutionalTrust", 0.0))
			var interdependence := float(arc_state.get("interdependence", 0.0))
			return "distributed_charter" if institutional_trust >= 20.0 and interdependence >= 20.0 else ("take_writ" if institutional_trust >= 20.0 else ("distributed_charter" if institutional_trust >= 0.0 and interdependence >= 10.0 else "reject_writ"))
		"alden_missing_sixth":
			return "return_and_name" if float(arc_state.get("particularity", 0.0)) >= 10.0 else ("pursue_network" if float(arc_state.get("engagement", 0.0)) >= 10.0 else "close_record")
		"alden_rule_for_living":
			var engagement := float(arc_state.get("engagement", 0.0))
			var particularity := float(arc_state.get("particularity", 0.0))
			return "take_office" if engagement >= 25.0 and particularity >= 10.0 else ("rotating_ministry" if engagement >= 5.0 or particularity >= 15.0 else "return_contemplation")
	return ""


