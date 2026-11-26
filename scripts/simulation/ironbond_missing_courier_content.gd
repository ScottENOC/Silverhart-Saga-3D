class_name IronbondMissingCourierContent
extends RefCounted
## Source-backed port of Dray Coltayne's initial "The Missing Courier" offer.
## The original source currently implements the offer/acceptance beat only; it
## does not define a recovery encounter or turn-in, so this resource does not
## invent those missing consequences.

const QUEST_ID := "ironbond_missing_courier"
const FACTION_ID := "ironbond_company"
const REPUTATION_GAIN := 10.0
const KNOWLEDGE_GAIN := 10.0


static func definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "The Missing Courier",
		"description": "Find the Ironbond courier who went missing on the North Road and recover the satchel of contracts.",
		"objectives": []
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
	var status := String(journal.quest_state(QUEST_ID).get("status", ""))
	if status == "active":
		return {
			"ok": true,
			"speaker": "Dray Coltayne",
			"text": "A courier of ours went dark on the North Road with a satchel of signed contracts. Bring it back, and there's coin in it for you.",
			"choices": [{"id": "ironbond_courier_wait", "label": "I'm still looking.", "text": ""}]
		}
	if status == "completed":
		return {
			"ok": true,
			"speaker": "Dray Coltayne",
			"text": "The Company has not forgotten the help you gave us.",
			"choices": [{"id": "ironbond_courier_leave", "label": "Good.", "text": ""}]
		}
	return {
		"ok": true,
		"speaker": "Dray Coltayne",
		"text": "A courier of ours went dark on the North Road with a satchel of signed contracts. Bring it back, and there's coin in it for you.",
		"choices": [
			{"id": "ironbond_courier_accept", "label": "Accept the job.", "text": ""},
			{"id": "ironbond_courier_decline", "label": "Not interested.", "text": ""}
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
	var reputation := journal.adjust_faction_reputation(
		FACTION_ID,
		REPUTATION_GAIN,
		KNOWLEDGE_GAIN,
		"Accepted Dray Coltayne's missing courier job"
	)
	return {"ok": true, "quest_started": true, "faction_reputation": reputation}


static func resolve_choice(journal: CampaignJournal, choice_id: String) -> Dictionary:
	match choice_id:
		"ironbond_courier_accept":
			var result := accept(journal)
			if not bool(result.get("ok", false)):
				return result
			return {
				"ok": true,
				"quest_started": true,
				"dialogue": {
					"speaker": "Dray Coltayne",
					"text": "Good. The satchel has the Company's contracts in it. Keep your eyes open along the North Road.",
					"choices": [{"id": "ironbond_courier_leave", "label": "I'll find it.", "text": ""}]
				}
			}
		"ironbond_courier_decline":
			return {
				"ok": true,
				"handled": true,
				"dialogue": {
					"speaker": "Dray Coltayne",
					"text": "Suit yourself.",
					"choices": [{"id": "ironbond_courier_leave", "label": "Walk away.", "text": ""}]
				}
			}
		"ironbond_courier_wait", "ironbond_courier_leave":
			return {"ok": true, "handled": true}
		_:
			return {"ok": false, "reason": "unknown_choice"}
