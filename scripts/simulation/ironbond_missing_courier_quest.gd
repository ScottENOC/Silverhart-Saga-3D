class_name IronbondMissingCourierQuest
extends RefCounted
## Source-authored post-shakedown quest offer from Dray Coltayne.
## The location controller detects the tavern exit; this class owns the
## dialogue content, quest registration and faction consequences.

const QUEST_ID := "ironbond_missing_courier"
const CHOICE_PREFIX := "ironbond_missing_courier:"


static func definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "The Missing Courier",
		"description": "Find the Ironbond courier who went missing on the North Road and recover the satchel of signed contracts.",
		"faction_id": "ironbond_company",
		"objectives": [
			{
				"id": "recover_contract_satchel",
				"description": "Find the missing courier and recover the satchel of signed contracts.",
				"target": 1.0,
				"required": true
			}
		]
	}


static func opening_dialogue() -> Dictionary:
	return {
		"speaker": "Dray Coltayne",
		"text": "You handled that back there without making a mess of it. The Company can use people like that.",
		"choices": [
			{"id": CHOICE_PREFIX + "ask", "label": "What do you need?"},
			{"id": CHOICE_PREFIX + "walk_away", "label": "Walk away."}
		]
	}


static func mission_dialogue() -> Dictionary:
	return {
		"speaker": "Dray Coltayne",
		"text": "A courier of ours went dark on the North Road with a satchel of signed contracts. Bring it back, and there's coin in it for you.",
		"choices": [
			{"id": CHOICE_PREFIX + "accept", "label": "Accept the job."},
			{"id": CHOICE_PREFIX + "decline", "label": "Not interested."}
		]
	}


static func confirmation_dialogue(response: String) -> Dictionary:
	if response == "accepted":
		return {
			"speaker": "Dray Coltayne",
			"text": "Good. The courier was last seen heading north with the contracts. Bring the satchel back intact. Quest added: The Missing Courier.",
			"choices": [{"id": CHOICE_PREFIX + "continue", "label": "I'll see to it."}]
		}
	return {
		"speaker": "Dray Coltayne",
		"text": "Suit yourself.",
		"choices": [{"id": CHOICE_PREFIX + "continue", "label": "Goodbye."}]
	}


static func register(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if journal.quest_definitions.has(QUEST_ID):
		return {"ok": true, "already_registered": true, "quest_id": QUEST_ID}
	return journal.register_quest_definition(definition())


static func handle_dialogue_choice(journal: CampaignJournal, choice_id: String) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	match choice_id:
		"ironbond_missing_courier:ask":
			return {"ok": true, "dialogue": mission_dialogue()}
		"ironbond_missing_courier:accept":
			var existing := journal.quest_state(QUEST_ID)
			if not existing.is_empty():
				return {"ok": false, "reason": "quest_already_offered"}
			var started := journal.start_quest(QUEST_ID)
			if not bool(started.get("ok", false)):
				return started
			journal.record_decision(QUEST_ID, "offer_response", "accepted")
			journal.adjust_faction_reputation("ironbond_company", 10.0, 10.0, "Accepted Dray Coltayne's missing courier job")
			return {
				"ok": true,
				"accepted": true,
				"dismiss_after_continue": true,
				"dialogue": confirmation_dialogue("accepted")
			}
		"ironbond_missing_courier:decline":
			return {
				"ok": true,
				"dismiss_after_continue": true,
				"dialogue": confirmation_dialogue("declined")
			}
		"ironbond_missing_courier:walk_away":
			return {"ok": true, "dismiss_now": true}
		"ironbond_missing_courier:continue":
			return {"ok": true, "dismiss_now": true}
	return {"ok": false, "reason": "unknown_dialogue_choice"}
