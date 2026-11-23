class_name CompanionQuestChainState
extends RefCounted
## Data-driven port of the authored personal quest chapters in Hex-crpg.
## CampaignJournal owns quest status/decisions; this class owns companion-arc
## development and the rules that connect a chapter to its companion and actor.

const DATA_PATH := "res://data/quests/companion_quest_chains.json"
const CHAPTER_COOLDOWN_SECONDS := 43200.0

var chapters: Dictionary = {}
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


