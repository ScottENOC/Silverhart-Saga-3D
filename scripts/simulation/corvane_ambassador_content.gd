class_name CorvaneAmbassadorContent
extends RefCounted
## Source-backed port of "Eyes on the Border" from campaign2Dialogue.js.
## The quest is a report-back task: the Skarn-tooth threat must leave its
## active state before Toren Aldwyn will accept the player's dispatch.

const QUEST_ID := "corvane_watch"
const OBJECTIVE_ID := "report_goblin_resolution"
const GOBLIN_QUEST_ID := "goblin_threat"
const NPC_ID := "ambassador_toren_aldwyn_human_male"
const REWARD_GOLD := 15
const REWARD_EXPERIENCE := 60
const REPUTATION_GAIN := 10.0
const KNOWLEDGE_GAIN := 15.0


static func definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "Eyes on the Border",
		"description": "Bring Ambassador Toren Aldwyn real word of how the greenskin trouble west of Hollowmere is resolved.",
		"objectives": [
			{"id": OBJECTIVE_ID, "description": "Report how the Skarn-tooth threat was resolved.", "target": 1.0, "required": true}
		]
	}


static func register_definition(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if journal.quest_definitions.has(QUEST_ID):
		return {"ok": true, "already_registered": true}
	return journal.register_quest_definition(definition())


static func greeting(journal: CampaignJournal, player: CharacterState) -> Dictionary:
	if journal == null or player == null:
		return {"ok": false, "reason": "missing_journal_or_player"}
	var quest_state := journal.quest_state(QUEST_ID)
	var status := String(quest_state.get("status", ""))
	if status == "active":
		if _goblin_threat_resolved(journal):
			return {
				"ok": true,
				"speaker": "Ambassador Toren Aldwyn",
				"text": "The greenskin camp west of Hollowmere — word is it's settled, one way or another. That's the first good dispatch I've had cause to send home in months.",
				"choices": [{"id": "toren_report_resolved", "label": "It's settled.", "available": true}]
			}
		return {
			"ok": true,
			"speaker": "Ambassador Toren Aldwyn",
			"text": "Corvane sent me to watch the greenskin trouble on Silverhart's border and report back. So far: it's trouble, and it's on the border. Riveting dispatches, I know.",
			"choices": [{"id": "toren_keep_watching", "label": "Keep watching.", "available": true}]
		}
	if status == "completed":
		return {
			"ok": true,
			"speaker": "Ambassador Toren Aldwyn",
			"text": "The border's quieter these days. Corvane appreciates knowing why.",
			"choices": [{"id": "toren_good_to_hear", "label": "Good to hear.", "available": true}]
		}
	return {
		"ok": true,
		"speaker": "Ambassador Toren Aldwyn",
		"text": "Corvane sent me to watch the greenskin trouble on Silverhart's border and report back. So far: it's trouble, and it's on the border. If you hear anything real out that way — anything I could actually put in a dispatch — I'd owe you.",
		"choices": [
			{"id": "toren_accept_report", "label": "I'll let you know what I find.", "available": true},
			{"id": "toren_riveting", "label": "Riveting.", "available": true}
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
	return journal.record_decision(QUEST_ID, "accepted", "yes")


static func report_resolution(journal: CampaignJournal, player: CharacterState) -> Dictionary:
	if journal == null or player == null:
		return {"ok": false, "reason": "missing_journal_or_player"}
	if String(journal.quest_state(QUEST_ID).get("status", "")) != "active":
		return {"ok": false, "reason": "quest_not_active"}
	if not _goblin_threat_resolved(journal):
		return {"ok": false, "reason": "goblin_threat_still_active"}
	var progress := journal.set_objective_progress(QUEST_ID, OBJECTIVE_ID, 1.0)
	if not bool(progress.get("ok", false)):
		return progress
	var completion := journal.complete_quest(QUEST_ID)
	if not bool(completion.get("ok", false)):
		return completion
	player.gold += REWARD_GOLD
	player.experience += REWARD_EXPERIENCE
	var reputation := journal.adjust_npc_reputation(
		NPC_ID, REPUTATION_GAIN, KNOWLEDGE_GAIN, "Reported the resolution of the Skarn-tooth threat"
	)
	return {
		"ok": true,
		"quest_completed": true,
		"gold_awarded": REWARD_GOLD,
		"experience_awarded": REWARD_EXPERIENCE,
		"npc_reputation": reputation
	}


static func resolve_choice(journal: CampaignJournal, player: CharacterState, choice_id: String) -> Dictionary:
	match choice_id:
		"toren_accept_report":
			var accepted := accept(journal)
			if not bool(accepted.get("ok", false)):
				return accepted
			return {"ok": true, "dialogue": greeting(journal, player)}
		"toren_report_resolved":
			return report_resolution(journal, player)
		"toren_keep_watching", "toren_riveting", "toren_good_to_hear":
			return {"ok": true, "handled": true}
		_:
			return {"ok": false, "reason": "unknown_choice"}


static func _goblin_threat_resolved(journal: CampaignJournal) -> bool:
	var goblin_state := journal.quest_state(GOBLIN_QUEST_ID)
	if goblin_state.is_empty():
		return false
	return String(goblin_state.get("status", "")) != "active"
