class_name ReddaleMissingWatchQuest
extends RefCounted
## Source-faithful quest state and turn-in for Captain Ilsa Rennick's
## Missing Watch. The source encounter spawns two tagged goblins at the
## Reddale search site; world placement and actor presentation are handled
## by the encounter/presentation integration.

const QUEST_ID := "reddale_missing_watch"
const OBJECTIVE_ID := "patrol_goblins_defeated"
const GOBLIN_COUNT := 2
const REWARD_GOLD := 40
const REWARD_EXPERIENCE := 200
const FACTION_ID := "silverhart_kingdom"
const REPUTATION_GAIN := 15.0
const KNOWLEDGE_GAIN := 20.0

static func definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "The Missing Watch",
		"description": "Find Captain Rennick's missing patrol along the road east of Reddale.",
		"objectives": [
			{"id": OBJECTIVE_ID, "description": "Defeat the goblins who attacked the missing patrol.", "target": float(GOBLIN_COUNT), "required": true}
		]
	}


static func register_definition(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if journal.quest_definitions.has(QUEST_ID):
		return {"ok": true, "already_registered": true}
	return journal.register_quest_definition(definition())


static func greeting(journal: CampaignJournal, goblins_remaining: int) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var state := journal.quest_state(QUEST_ID)
	var status := String(state.get("status", ""))
	if status.is_empty():
		return {
			"ok": true,
			"speaker": "Captain Ilsa Rennick",
			"text": "Two of my watchmen went out on the east road patrol three days back. Never came home. I fear the worst, but I can't spare anyone else to look.",
			"choices": [
				{"id": "ilsa_missing_watch_accept", "label": "I'll find them."},
				{"id": "ilsa_missing_watch_decline", "label": "Not my concern."}
			]
		}
	if status == "active":
		if goblins_remaining > 0:
			return {
				"ok": true,
				"speaker": "Captain Ilsa Rennick",
				"text": "Head out along the east road. Whatever got them didn't leave much sign — watch yourself.",
				"choices": [{"id": "ilsa_missing_watch_continue", "label": "I'll report back."}]
			}
		return {
			"ok": true,
			"speaker": "Captain Ilsa Rennick",
			"text": "Goblins, this far out? That's further than they've ever ranged before — worth knowing, and worth worrying about. My thanks, truly.",
			"choices": [{"id": "ilsa_missing_watch_turn_in", "label": "Glad to help."}]
		}
	return {
		"ok": true,
		"speaker": "Captain Ilsa Rennick",
		"text": "The patrol is avenged. You've done Reddale a real service.",
		"choices": [{"id": "ilsa_missing_watch_leave", "label": "Just doing what's needed."}]
	}


static func accept(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var result := journal.start_quest(QUEST_ID)
	if not bool(result.get("ok", false)):
		return result
	journal.record_decision(QUEST_ID, "accepted", "yes")
	return result


static func record_goblin_defeats(journal: CampaignJournal, defeated_count: int) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	return journal.set_objective_progress(QUEST_ID, OBJECTIVE_ID, float(clampi(defeated_count, 0, GOBLIN_COUNT)))


static func turn_in(journal: CampaignJournal, player: CharacterState) -> Dictionary:
	if journal == null or player == null:
		return {"ok": false, "reason": "missing_journal_or_player"}
	var state := journal.quest_state(QUEST_ID)
	if String(state.get("status", "")) != "active":
		return {"ok": false, "reason": "quest_not_active"}
	var objectives: Dictionary = state.get("objectives", {})
	var objective: Dictionary = objectives.get(OBJECTIVE_ID, {})
	if not bool(objective.get("completed", false)):
		return {"ok": false, "reason": "goblins_remain"}
	var completed := journal.complete_quest(QUEST_ID)
	if not bool(completed.get("ok", false)):
		return completed
	player.gold += REWARD_GOLD
	player.experience += REWARD_EXPERIENCE
	var reputation := journal.adjust_faction_reputation(
		FACTION_ID,
		REPUTATION_GAIN,
		KNOWLEDGE_GAIN,
		"Resolved Captain Rennick's missing patrol"
	)
	return {
		"ok": bool(reputation.get("ok", false)),
		"gold": REWARD_GOLD,
		"experience": REWARD_EXPERIENCE,
		"reputation": reputation.get("delta", 0.0),
		"knowledge": reputation.get("knowledge", 0.0)
	}


static func resolve_choice(
	journal: CampaignJournal,
	player: CharacterState,
	choice_id: String,
	goblins_remaining: int
) -> Dictionary:
	match choice_id:
		"ilsa_missing_watch_accept":
			var accepted := accept(journal)
			if not bool(accepted.get("ok", false)):
				return {"ok": false, "handled": true, "reason": accepted.get("reason", "could_not_accept")}
			return {
				"ok": true,
				"handled": true,
				"quest_started": true,
				"speaker": "Captain Ilsa Rennick",
				"text": "Thank you. The east road is a long walk, but if they're alive, every hour matters.",
				"choices": [{"id": "ilsa_missing_watch_continue", "label": "I'll go now."}]
			}
		"ilsa_missing_watch_decline":
			return {
				"ok": true,
				"handled": true,
				"declined": true,
				"speaker": "Captain Ilsa Rennick",
				"text": "I understand. If you change your mind, you know where to find me.",
				"choices": [{"id": "ilsa_missing_watch_leave", "label": "Understood."}]
			}
		"ilsa_missing_watch_turn_in":
			var reward := turn_in(journal, player)
			if not bool(reward.get("ok", false)):
				return {"ok": false, "handled": true, "reason": reward.get("reason", "turn_in_failed")}
			return {
				"ok": true,
				"handled": true,
				"quest_completed": true,
				"reward": reward,
				"speaker": "Captain Ilsa Rennick",
				"text": "Goblins this far out is a worrying sign. You have my thanks — and Reddale's.",
				"choices": [{"id": "ilsa_missing_watch_leave", "label": "Just doing what's needed."}]
		"ilsa_missing_watch_continue", "ilsa_missing_watch_leave":
			return {"ok": true, "handled": true, "close": true}
		_:
			return {"ok": false, "handled": false, "reason": "unknown_choice"}
