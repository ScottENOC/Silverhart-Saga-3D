class_name CompanionPrerequisiteDialogueService
extends RefCounted
## Presentation-neutral adapter for source-authored companion prerequisite quests.
## The campaign state remains in CompanionQuestChainState/CampaignJournal; this
## service packages prompts and translates NPC interactions into state calls.


static func dialogue_for_companion(
	chain: CompanionQuestChainState,
	journal: CampaignJournal,
	companion_id: String,
	party_ids: Array[String],
	player_state: CharacterState = null,
	world_seconds: float = 0.0
) -> Dictionary:
	if chain == null or journal == null:
		return {}
	var normalized_companion_id := companion_id.trim_prefix("companion_")
	var next := chain.next_prerequisite_for_companion(normalized_companion_id, journal, party_ids)
	if next.is_empty():
		var next_chapter := chain.next_chapter_for(normalized_companion_id, journal, party_ids, world_seconds)
		if next_chapter.is_empty():
			return {}
		var chapter: Dictionary = next_chapter.get("chapter", {})
		var chapter_state: Dictionary = next_chapter.get("quest_state", {})
		var chapter_id := String(chapter.get("id", ""))
		var chapter_body := String(chapter.get("intro", ""))
		var chapter_choices: Array[Dictionary] = []
		if chapter_state.is_empty():
			chapter_choices.append({
				"id":"companion_chain_start",
				"chapter_id":chapter_id,
				"label":"Let's take this on together."
			})
		elif bool(chapter_state.get("consulted", false)):
			chapter_body = String(chapter.get("reckoning", chapter_body))
			for option_value in chain.resolution_options(chapter_id):
				var option: Dictionary = option_value
				chapter_choices.append({
					"id":"companion_chain_resolve",
					"chapter_id":chapter_id,
					"resolution_id":String(option.get("id", "")),
					"label":String(option.get("label", "Choose"))
				})
		else:
			chapter_body = String(chapter_state.get("description", chapter_body))
			chapter_choices.append({"id":"continue","label":"Continue","text":""})
		return {"quest_id":chapter_id,"body":chapter_body,"choices":chapter_choices,"quest_state":chapter_state.duplicate(true),"chapter":chapter.duplicate(true)}
	var definition: Dictionary = next.get("quest", {})
	var quest_state: Dictionary = next.get("quest_state", {})
	var quest_id := String(definition.get("id", ""))
	if quest_state.is_empty():
		return {
			"quest_id":quest_id,
			"body":String(definition.get("opening", definition.get("description", ""))),
			"choices":[{"id":"companion_prerequisite_start","quest_id":quest_id,"label":"Let's take this on together."}]
		}
	var body := String(definition.get("opening", definition.get("description", "")))
	var choices: Array[Dictionary] = []
	var opening_choice_keys: Array = quest_state.get("opening_choice_keys", [])
	if opening_choice_keys.is_empty():
		for choice_value in definition.get("opening_choices", []):
			var opening_choice: Dictionary = choice_value
			choices.append({
				"id":"companion_prerequisite_opening_choice",
				"quest_id":quest_id,
				"choice_id":String(opening_choice.get("id", "")),
				"label":String(opening_choice.get("label", "Continue")),
				"text":String(opening_choice.get("response", ""))
			})
	else:
		body += "\n\n" + String(quest_state.get("description", definition.get("description", "")))
	if chain.can_resolve_prerequisite(quest_id, journal):
		choices.clear()
		for option_value in chain.prerequisite_resolution_options(quest_id, player_state):
			var option: Dictionary = option_value
			choices.append({
				"id":"companion_prerequisite_resolve",
				"quest_id":quest_id,
				"resolution_id":String(option.get("id", "")),
				"label":String(option.get("label", "Choose")),
				"available":bool(option.get("available", true)),
				"unavailable_reason":String(option.get("unavailable_reason", ""))
			})
		body += "\n\nThe evidence is gathered. Decide how to resolve this with your companion."
	if choices.is_empty():
		choices.append({"id":"continue","label":"Continue","text":""})
	return {"quest_id":quest_id,"body":body,"choices":choices,"quest_state":quest_state.duplicate(true)}


static func start_quest(
	chain: CompanionQuestChainState,
	journal: CampaignJournal,
	relationships: CompanionRelationshipState,
	quest_id: String,
	party_ids: Array[String],
	world_seconds: float
) -> Dictionary:
	if chain == null:
		return {"ok":false,"reason":"missing_quest_chain"}
	return chain.start_prerequisite(quest_id, journal, party_ids, relationships, world_seconds)


static func apply_opening_choice(
	chain: CompanionQuestChainState,
	journal: CampaignJournal,
	relationships: CompanionRelationshipState,
	quest_id: String,
	choice_id: String
) -> Dictionary:
	if chain == null:
		return {"ok":false,"reason":"missing_quest_chain"}
	return chain.apply_prerequisite_choice(quest_id, choice_id, journal, relationships)


static func actor_prompt(
	chain: CompanionQuestChainState,
	journal: CampaignJournal,
	actor_id: String,
	capabilities: Array[String] = []
) -> Dictionary:
	if chain == null or journal == null:
		return {}
	var active := chain.active_prerequisite_for_actor(actor_id, journal)
	if active.is_empty():
		var chain_actor_id := "nessa_wren" if actor_id == "elder_nessa_wren_elf_female" else actor_id
		var active_chapter := chain.active_chapter_for_actor(chain_actor_id, journal)
		if active_chapter.is_empty():
			return {}
		var chapter: Dictionary = active_chapter.get("chapter", {})
		var chapter_id := String(chapter.get("id", ""))
		var chapter_body := String(chapter.get("actorText", ""))
		var actor_prompt_text := String(chapter.get("actorPrompt", ""))
		if not actor_prompt_text.is_empty():
			chapter_body += "\n\n" + actor_prompt_text
		return {
			"quest_id":chapter_id,
			"chapter_id":chapter_id,
			"title":String(chapter.get("title", chapter_id)),
			"companion_id":String(chapter.get("companion_id", "")),
			"actor_id":chain_actor_id,
			"body":chapter_body,
			"choices":[{
				"id":"companion_chain_consult",
				"chapter_id":chapter_id,
				"actor_id":chain_actor_id,
				"label":"Ask what this means for our companion."
			}]
		}
	var accessible_clues: Array[Dictionary] = []
	var dialogue_parts: Array[String] = []
	for clue_value in active.get("clues", []):
		var clue_entry: Dictionary = clue_value
		var clue: Dictionary = clue_entry.get("definition", {})
		if not _clue_accessible(clue, journal, capabilities):
			continue
		accessible_clues.append({"id":String(clue_entry.get("id", "")),"label":String(clue.get("label", ""))})
		var dialogue := String(clue.get("dialogue", ""))
		if not dialogue.is_empty():
			dialogue_parts.append(dialogue)
	if accessible_clues.is_empty():
		return {}
	var combined_dialogue := ""
	for dialogue_part in dialogue_parts:
		if not combined_dialogue.is_empty():
			combined_dialogue += "\n\n"
		combined_dialogue += dialogue_part
	return {
		"quest_id":String(active.get("quest_id", "")),
		"title":String(active.get("title", "")),
		"companion_id":String(active.get("companion_id", "")),
		"actor_id":actor_id,
		"body":combined_dialogue,
		"clues":accessible_clues,
		"choices":[{
			"id":"companion_prerequisite_record_clues",
			"quest_id":String(active.get("quest_id", "")),
			"actor_id":actor_id,
			"clue_ids":accessible_clues.map(func(item: Dictionary) -> String: return String(item.get("id", ""))),
			"label":"Record what we learned."
		}]
	}


static func record_actor_clues(
	chain: CompanionQuestChainState,
	journal: CampaignJournal,
	actor_id: String,
	world_seconds: float,
	capabilities: Array[String] = []
) -> Dictionary:
	var prompt := actor_prompt(chain, journal, actor_id, capabilities)
	if prompt.is_empty():
		return {"ok":false,"reason":"no_available_prerequisite_clues"}
	var recorded: Array[String] = []
	for clue_value in prompt.get("clues", []):
		var clue: Dictionary = clue_value
		var result := chain.add_prerequisite_clue(
			String(prompt.get("quest_id", "")),
			String(clue.get("id", "")),
			actor_id,
			journal,
			world_seconds,
			capabilities
		)
		if bool(result.get("ok", false)) and bool(result.get("changed", false)):
			recorded.append(String(clue.get("id", "")))
	return {
		"ok":not recorded.is_empty(),
		"quest_id":String(prompt.get("quest_id", "")),
		"recorded_clues":recorded,
		"can_resolve":chain.can_resolve_prerequisite(String(prompt.get("quest_id", "")), journal)
	}


static func resolve(
	chain: CompanionQuestChainState,
	journal: CampaignJournal,
	relationships: CompanionRelationshipState,
	quest_id: String,
	resolution_id: String,
	world_seconds: float,
	player_state: CharacterState
) -> Dictionary:
	if chain == null:
		return {"ok":false,"reason":"missing_quest_chain"}
	return chain.resolve_prerequisite(quest_id, resolution_id, journal, relationships, world_seconds, player_state)




static func start_chapter(
	chain: CompanionQuestChainState,
	journal: CampaignJournal,
	relationships: CompanionRelationshipState,
	chapter_id: String,
	party_ids: Array[String],
	world_seconds: float
) -> Dictionary:
	if chain == null:
		return {"ok":false,"reason":"missing_quest_chain"}
	return chain.start(chapter_id, journal, party_ids, relationships, world_seconds)


static func consult_chapter(
	chain: CompanionQuestChainState,
	journal: CampaignJournal,
	chapter_id: String,
	actor_id: String,
	world_seconds: float
) -> Dictionary:
	if chain == null:
		return {"ok":false,"reason":"missing_quest_chain"}
	return chain.consult(chapter_id, journal, actor_id, world_seconds)


static func resolve_chapter(
	chain: CompanionQuestChainState,
	journal: CampaignJournal,
	relationships: CompanionRelationshipState,
	chapter_id: String,
	resolution_id: String,
	world_seconds: float
) -> Dictionary:
	if chain == null:
		return {"ok":false,"reason":"missing_quest_chain"}
	return chain.resolve(chapter_id, resolution_id, journal, relationships, world_seconds)


static func _clue_accessible(clue: Dictionary, journal: CampaignJournal, capabilities: Array[String]) -> bool:
	var access_any: Array = clue.get("access_any", [])
	if not access_any.is_empty():
		var granted := false
		for access_value in access_any:
			var access_id := String(access_value)
			if access_id == "ironbond_standing_20":
				granted = journal.faction_standing("ironbond_company") >= 20.0
			else:
				granted = capabilities.has(access_id)
			if granted:
				break
		if not granted:
			return false
	var skill_gate := String(clue.get("skill_gate", ""))
	if skill_gate == "nature_or_perception" and not capabilities.has("nature") and not capabilities.has("perception"):
		return false
	var capability_any: Array = clue.get("capability_any", [])
	if not capability_any.is_empty():
		var capability_granted := false
		for capability_value in capability_any:
			if capabilities.has(String(capability_value)):
				capability_granted = true
				break
		if not capability_granted:
			return false
	if bool(clue.get("requires_stealth", false)) and not capabilities.has("stealth"):
		return false
	var faction_id := String(clue.get("faction_id", ""))
	if not faction_id.is_empty() and journal.faction_standing(faction_id) < float(clue.get("faction_standing_min", -1000.0)):
		return false
	return true
