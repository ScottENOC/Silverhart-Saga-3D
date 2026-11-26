class_name AldenreachMessageContent
extends RefCounted
## Source-backed port of "A Quiet Word" from campaign2Dialogue.js.
## Cassia is a streamed Silverhart actor; Elder Marta is a local Hollowmere actor.

const QUEST_ID := "aldenreach_message"
const DELIVERY_OBJECTIVE_ID := "deliver_message_to_elder"
const REPORT_OBJECTIVE_ID := "report_delivery_to_cassia"
const NPC_ID := "ambassador_cassia_wren"
const REWARD_GOLD := 15
const REWARD_EXPERIENCE := 60
const REPUTATION_GAIN := 10.0
const KNOWLEDGE_GAIN := 15.0


static func definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "A Quiet Word",
		"description": "Deliver Ambassador Cassia Wren's message of goodwill to Elder Marta Wynfield in Hollowmere, then report back.",
		"objectives": [
			{"id": DELIVERY_OBJECTIVE_ID, "description": "Deliver Cassia's quiet word to Elder Marta.", "target": 1.0, "required": true},
			{"id": REPORT_OBJECTIVE_ID, "description": "Report the delivery to Ambassador Cassia Wren.", "target": 1.0, "required": true}
		]
	}


static func register_definition(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if journal.quest_definitions.has(QUEST_ID):
		return {"ok": true, "already_registered": true}
	return journal.register_quest_definition(definition())


static func greeting(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var state := journal.quest_state(QUEST_ID)
	var status := String(state.get("status", ""))
	if status == "active":
		if _message_delivered(state):
			return {
				"ok": true,
				"speaker": "Ambassador Cassia Wren",
				"text": "Elder Marta had your word for it, then? Good. Aldenreach likes to know its friendlier gestures actually land somewhere.",
				"choices": [{"id": "cassia_claim_delivery", "label": "They landed.", "available": true}]
			}
		return {
			"ok": true,
			"speaker": "Ambassador Cassia Wren",
			"text": "Still waiting to hear whether Hollowmere's elder got my word. No rush — just don't forget.",
			"choices": [{"id": "cassia_not_delivered", "label": "I haven't.", "available": true}]
		}
	if status == "completed":
		return {
			"ok": true,
			"speaker": "Ambassador Cassia Wren",
			"text": "Aldenreach and Silverhart haven't gone to war in three generations. Small favors like yours are most of why.",
			"choices": [{"id": "cassia_leave", "label": "Glad to help.", "available": true}]
		}
	return {
		"ok": true,
		"speaker": "Ambassador Cassia Wren",
		"text": "Aldenreach and Silverhart haven't gone to war in three generations. My whole posting here is to keep it that way, one dull treaty dinner at a time. Would you carry a quiet word of goodwill to Hollowmere's elder for me? Nothing Silverhart needs to know about.",
		"choices": [
			{"id": "cassia_accept_message", "label": "I'll carry your word.", "available": true},
			{"id": "cassia_leave", "label": "Sounds like important work.", "available": true}
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
	var decision := journal.record_decision(QUEST_ID, "accepted", "yes")
	if not bool(decision.get("ok", false)):
		return decision
	return started


static func deliver_to_elder(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var state := journal.quest_state(QUEST_ID)
	if String(state.get("status", "")) != "active" or _message_delivered(state):
		return {"ok": true, "delivered_now": false}
	var progress := journal.set_objective_progress(QUEST_ID, DELIVERY_OBJECTIVE_ID, 1.0)
	if not bool(progress.get("ok", false)):
		return progress
	var decision := journal.record_decision(QUEST_ID, "delivered_to_elder", "yes")
	if not bool(decision.get("ok", false)):
		return decision
	return {"ok": true, "delivered_now": true}


static func claim_delivery(journal: CampaignJournal, player: CharacterState) -> Dictionary:
	if journal == null or player == null:
		return {"ok": false, "reason": "missing_journal_or_player"}
	var state := journal.quest_state(QUEST_ID)
	if String(state.get("status", "")) != "active":
		return {"ok": false, "reason": "quest_not_active"}
	if not _message_delivered(state):
		return {"ok": false, "reason": "message_not_delivered"}
	var progress := journal.set_objective_progress(QUEST_ID, REPORT_OBJECTIVE_ID, 1.0)
	if not bool(progress.get("ok", false)):
		return progress
	var completion := journal.complete_quest(QUEST_ID)
	if not bool(completion.get("ok", false)):
		return completion
	player.gold += REWARD_GOLD
	player.experience += REWARD_EXPERIENCE
	var reputation := journal.adjust_npc_reputation(
		NPC_ID,
		REPUTATION_GAIN,
		KNOWLEDGE_GAIN,
		"Delivered Cassia Wren's message of goodwill to Elder Marta"
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
		"cassia_accept_message":
			var accept_result := accept(journal)
			if not bool(accept_result.get("ok", false)):
				return accept_result
			return {"ok": true, "quest_started": true, "handled": true}
		"cassia_claim_delivery":
			var claim_result := claim_delivery(journal, player)
			if not bool(claim_result.get("ok", false)):
				return claim_result
			return {"ok": true, "quest_completed": true, "handled": true}
		"cassia_not_delivered", "cassia_leave":
			return {"ok": true, "handled": true}
		_:
			return {"ok": false, "reason": "unknown_choice"}


static func _message_delivered(state: Dictionary) -> bool:
	var decisions: Dictionary = state.get("decisions", {})
	return String(decisions.get("delivered_to_elder", "")) == "yes"
