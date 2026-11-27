class_name CompanionCampaignDialogueService
extends RefCounted
## Bridges authored companion chapter data to the campaign dialogue UI.
## Quest rules remain in CompanionQuestChainState; this class only packages
## dialogue prompts and routes start/consult/resolve requests.

const RUNTIME_STORE := preload("res://scripts/simulation/companion_campaign_runtime_store.gd")


static func chapter_dialogue_for_companion(simulation: WorldSimulation, companion_id: String) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {}
	var canonical_id := companion_id.trim_prefix("companion_")
	var chain := RUNTIME_STORE.quest_chain_state_for(simulation)
	var party_ids: Array[String] = []
	for value in simulation.get_party_member_ids():
		party_ids.append(String(value))
	var next := chain.next_chapter_for(canonical_id, simulation.campaign_journal, party_ids, simulation.clock.world_seconds)
	if next.is_empty():
		return {}
	var chapter: Dictionary = next.get("chapter", {})
	if chapter.is_empty():
		return {}
	var quest_state: Dictionary = next.get("quest_state", {})
	var chapter_id := String(chapter.get("id", ""))
	var actor_name := String(chapter.get("actor", "the person involved"))
	if quest_state.is_empty():
		return {
			"body":String(chapter.get("intro", "")),
			"choices":[{
				"id":"companion_chapter_start",
				"chapter_id":chapter_id,
				"companion_id":companion_id,
				"label":"Let's take this on together."
			}]
		}
	if not bool(quest_state.get("consulted", false)):
		return {
			"body":"\n\n%s\n\nI need you to speak with %s before we decide what to do." % [String(chapter.get("intro", "")), actor_name],
			"choices":[]
		}
	var options: Array[Dictionary] = []
	for option_value in chain.resolution_options(chapter_id):
		var option: Dictionary = option_value
		options.append({
			"id":"companion_chapter_resolve",
			"chapter_id":chapter_id,
			"companion_name":String(chapter.get("companion", "Companion")),
			"resolution_id":String(option.get("id", "")),
			"label":String(option.get("label", "Choose"))
		})
	return {
		"body":"\n\n%s" % String(chapter.get("reckoning", "The decision is yours.")),
		"choices":options
	}


static func start_chapter(simulation: WorldSimulation, chapter_id: String) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"ok":false,"reason":"missing_campaign"}
	var chain := RUNTIME_STORE.quest_chain_state_for(simulation)
	var relationships := RUNTIME_STORE.relationship_state_for(simulation)
	var party_ids: Array[String] = []
	for value in simulation.get_party_member_ids():
		party_ids.append(String(value))
	return chain.start(chapter_id, simulation.campaign_journal, party_ids, relationships, simulation.clock.world_seconds)


static func consult_for_actor(simulation: WorldSimulation, actor_id: String, actor_name: String = "") -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {}
	var chain := RUNTIME_STORE.quest_chain_state_for(simulation)
	var journal := simulation.campaign_journal
	var actor_key := actor_id.strip_edges().to_lower()
	var name_key := actor_name.strip_edges().to_lower()
	for chapter_value in chain.all_chapters():
		var chapter: Dictionary = chapter_value
		var expected_id := String(chapter.get("actor_id", "")).to_lower()
		var expected_name := String(chapter.get("actor", "")).to_lower()
		var matches_id := not actor_key.is_empty() and actor_key == expected_id
		var matches_name := not name_key.is_empty() and (name_key == expected_name or name_key.ends_with(" " + expected_name) or expected_name.ends_with(" " + name_key))
		if not matches_id and not matches_name:
			continue
		var chapter_id := String(chapter.get("id", ""))
		var quest_state := journal.quest_state(chapter_id)
		if String(quest_state.get("status", "")) != "active" or bool(quest_state.get("consulted", false)):
			continue
		return chain.consult(chapter_id, journal, expected_id, simulation.clock.world_seconds)
	return {}


static func resolve_chapter(simulation: WorldSimulation, chapter_id: String, resolution_id: String) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"ok":false,"reason":"missing_campaign"}
	var chain := RUNTIME_STORE.quest_chain_state_for(simulation)
	var relationships := RUNTIME_STORE.relationship_state_for(simulation)
	return chain.resolve(chapter_id, resolution_id, simulation.campaign_journal, relationships, simulation.clock.world_seconds)


static func resolve_dialogue_choice(simulation: WorldSimulation, choice: Dictionary) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"handled": false, "ok": false, "reason": "missing_campaign"}
	var choice_id := String(choice.get("id", ""))
	if choice_id == "companion_chapter_start":
		var chapter_id := String(choice.get("chapter_id", ""))
		var start_result := start_chapter(simulation, chapter_id)
		if not bool(start_result.get("ok", false)):
			return _choice_failure(
				"Campaign journal",
				"That chapter could not be started: %s." % String(start_result.get("reason", "unknown reason")).replace("_", " ")
			)
		return {
			"handled": true,
			"ok": true,
			"action": "show_companion_dialogue",
			"companion_id": String(choice.get("companion_id", ""))
		}
	if choice_id == "companion_chapter_resolve":
		var resolution_result := resolve_chapter(
			simulation,
			String(choice.get("chapter_id", "")),
			String(choice.get("resolution_id", ""))
		)
		if not bool(resolution_result.get("ok", false)):
			return _choice_failure(
				"Campaign journal",
				"That resolution could not be recorded: %s." % String(resolution_result.get("reason", "unknown reason")).replace("_", " ")
			)
		var reward_text := String(resolution_result.get("line", "The decision is made."))
		var xp_reward := int(resolution_result.get("xp_reward", 0))
		var player_state := simulation.get_character("player")
		if player_state != null and xp_reward > 0:
			player_state.experience += xp_reward
			reward_text += "\n\nChapter complete · %d XP gained." % xp_reward
		return {
			"handled": true,
			"ok": true,
			"dialogue": {
				"speaker": String(choice.get("companion_name", "Companion")),
				"text": reward_text,
				"choices": [{"id": "continue", "label": "Continue", "text": ""}]
			}
		}
	if choice_id.begins_with("wren_arc_choice:"):
		var wren_choice_id := choice_id.trim_prefix("wren_arc_choice:")
		var wren_arc := RUNTIME_STORE.wren_arc_state_for(simulation)
		var relationships := RUNTIME_STORE.relationship_state_for(simulation)
		if wren_arc == null:
			return {"handled": true, "ok": false, "action": "show_wren_dialogue"}
		var applied := wren_arc.apply_dialogue_choice(wren_choice_id, relationships)
		if bool(applied.get("ok", false)):
			return {
				"handled": true,
				"ok": true,
				"dialogue": {
					"speaker": "Wren Talbot",
					"text": wren_arc.dialogue_response_for(wren_choice_id),
					"choices": [{"id": "continue", "label": "I understand.", "text": ""}]
				}
			}
		return {"handled": true, "ok": false, "action": "show_wren_dialogue"}
	return {"handled": false}


static func _choice_failure(speaker: String, message: String) -> Dictionary:
	return {
		"handled": true,
		"ok": false,
		"dialogue": {
			"speaker": speaker,
			"text": message,
			"choices": [{"id": "continue", "label": "Continue", "text": ""}]
		}
	}
