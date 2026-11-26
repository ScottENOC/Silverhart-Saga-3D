class_name TollTakerQuestContent
extends RefCounted
## Source-backed campaign content for Petra Hollis's "The Toll-Taker".
## The world encounter owns the ogre actor; this resource owns the journal
## objective, Petra's dialogue states, and the one-time return reward.

const QUEST_ID := "toll_ogre"
const OBJECTIVE_ID := "ogre_defeated"
const FACTION_ID := "silverhart_kingdom"
const REWARD_GOLD := 30
const REWARD_EXPERIENCE := 120
const REWARD_REPUTATION := 10.0
const REWARD_KNOWLEDGE := 10.0


static func definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "The Toll-Taker",
		"description": "An ogre is demanding blood from travellers on the north road, beyond the abandoned house. Kill it and report back to Petra Hollis.",
		"objectives": [
			{"id": OBJECTIVE_ID, "description": "Defeat the toll-taking ogre on the north road.", "target": 1.0, "required": true}
		]
	}


static func register_definition(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if journal.quest_definitions.has(QUEST_ID):
		return {"ok": true, "already_registered": true}
	return journal.register_quest_definition(definition())


static func greeting(journal: CampaignJournal, ogre_alive: bool) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var status := String(journal.quest_state(QUEST_ID).get("status", ""))
	if status == "completed":
		return {
			"ok": true,
			"speaker": "Petra Hollis",
			"text": "Word is the toll problem is sorted. Travellers can use the north road again.",
			"choices": [{"id": "toll_ogre_leave", "label": "Glad to help.", "text": ""}]
		}
	if status == "active":
		if not ogre_alive:
			record_ogre_defeat(journal, false)
		var objective: Dictionary = journal.quest_state(QUEST_ID).get("objectives", {}).get(OBJECTIVE_ID, {})
		if bool(objective.get("completed", false)):
			return {
				"ok": true,
				"speaker": "Petra Hollis",
				"text": "You actually did it? Travellers on that road owe you a drink or ten. Here, take this for your trouble.",
				"choices": [{"id": "toll_ogre_turn_in", "label": "Glad to help.", "text": ""}]
			}
		return {
			"ok": true,
			"speaker": "Petra Hollis",
			"text": "Still charging a toll in blood, last I heard. The ogre is camped beyond the old abandoned house.",
			"choices": [{"id": "toll_ogre_wait", "label": "I'll finish it.", "text": ""}]
		}
	return {
		"ok": true,
		"speaker": "Petra Hollis",
		"text": "A trader passed through cursing about an ogre camped past the old abandoned house, demanding a toll from anyone using the road. Silverhart's watch hasn't done anything about it, out this far.",
		"choices": [
			{"id": "toll_ogre_accept", "label": "I'll clear it out.", "text": ""},
			{"id": "toll_ogre_decline", "label": "Not my problem.", "text": ""}
		]
	}


static func accept(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var registered := register_definition(journal)
	if not bool(registered.get("ok", false)):
		return registered
	var started := journal.start_quest(QUEST_ID)
	if not bool(started.get("ok", false)):
		return started
	journal.record_decision(QUEST_ID, "accepted", "yes")
	return started


static func record_ogre_defeat(journal: CampaignJournal, ogre_alive: bool) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if String(journal.quest_state(QUEST_ID).get("status", "")) != "active":
		return {"ok": false, "reason": "quest_not_active"}
	if ogre_alive:
		return {"ok": true, "defeated": false, "reason": "ogre_still_alive"}
	var progress := journal.set_objective_progress(QUEST_ID, OBJECTIVE_ID, 1.0)
	if not bool(progress.get("ok", false)):
		return progress
	return {"ok": true, "defeated": true}


static func turn_in(journal: CampaignJournal, player: CharacterState) -> Dictionary:
	if journal == null or player == null:
		return {"ok": false, "reason": "missing_journal_or_player"}
	if String(journal.quest_state(QUEST_ID).get("status", "")) != "active":
		return {"ok": false, "reason": "quest_not_active"}
	var objective: Dictionary = journal.quest_state(QUEST_ID).get("objectives", {}).get(OBJECTIVE_ID, {})
	if not bool(objective.get("completed", false)):
		return {"ok": false, "reason": "ogre_not_defeated"}
	var completion := journal.complete_quest(QUEST_ID)
	if not bool(completion.get("ok", false)):
		return completion
	player.gold += REWARD_GOLD
	player.experience += REWARD_EXPERIENCE
	var reputation := journal.adjust_faction_reputation(
		FACTION_ID,
		REWARD_REPUTATION,
		REWARD_KNOWLEDGE,
		"Cleared the toll-taking ogre from the north road"
	)
	return {
		"ok": true,
		"quest_completed": true,
		"gold_awarded": REWARD_GOLD,
		"experience_awarded": REWARD_EXPERIENCE,
		"faction_reputation": reputation
	}


static func resolve_choice(
	journal: CampaignJournal,
	player: CharacterState,
	choice_id: String,
	ogre_alive: bool
) -> Dictionary:
	match choice_id:
		"toll_ogre_accept":
			var accepted := accept(journal)
			if not bool(accepted.get("ok", false)):
				return accepted
			# Accepting creates the world actor immediately afterwards. Treat it as alive here;
			# otherwise a not-yet-spawned actor would complete the objective on acceptance.
			return {"ok": true, "dialogue": greeting(journal, true)}
		"toll_ogre_turn_in":
			var reward := turn_in(journal, player)
			if not bool(reward.get("ok", false)):
				return reward
			return {
				"ok": true,
				"quest_completed": true,
				"reward": reward,
				"dialogue": greeting(journal, ogre_alive)
			}
		"toll_ogre_wait", "toll_ogre_decline", "toll_ogre_leave":
			return {"ok": true, "handled": true}
		_:
			return {"ok": false, "reason": "unknown_choice"}
