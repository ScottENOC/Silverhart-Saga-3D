class_name ElderMartaContent
extends RefCounted
## Source-backed port of Elder Marta's "A Missing Locket" errand.
## The quest logic is independent of actor placement; Marta still needs a
## persistent profile and live interaction route before this is playable.

const QUEST_ID := "elder_locket"
const OBJECTIVE_ID := "recover_mothers_locket"
const NPC_ID := "elder_marta_wynfield"
const LOCKET_ITEM_ID := "elder_locket"
const REWARD_GOLD := 20
const REWARD_EXPERIENCE := 100
const REPUTATION_GAIN := 15.0
const KNOWLEDGE_GAIN := 20.0


static func definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "A Missing Locket",
		"description": "Find Elder Marta's mother's locket, lost somewhere near the old chapel.",
		"objectives": [
			{"id": OBJECTIVE_ID, "description": "Recover Elder Marta's mother's locket.", "target": 1.0, "required": true}
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
	var status := String(journal.quest_state(QUEST_ID).get("status", ""))
	if status == "active":
		if _locket_instance_id(player).is_empty():
			return {
				"ok": true,
				"speaker": "Elder Marta Wynfield",
				"text": "Still keeping an eye out for that locket, I hope? I lost it somewhere near the old chapel.",
				"choices": [{"id": "marta_keep_looking", "label": "I'll find it.", "available": true}]
			}
		return {
			"ok": true,
			"speaker": "Elder Marta Wynfield",
			"text": "Is that... you found it! My mother's locket, after all these years.",
			"choices": [{"id": "marta_turn_in_locket", "label": "Here you go.", "available": true}]
		}
	if status == "completed":
		return {
			"ok": true,
			"speaker": "Elder Marta Wynfield",
			"text": "You've done more for Hollowmere than most ever do. I won't forget what you did for my family.",
			"choices": [{"id": "marta_leave", "label": "I'm glad it found its way home.", "available": true}]
		}
	return {
		"ok": true,
		"speaker": "Elder Marta Wynfield",
		"text": "Welcome, traveler. Hollowmere's a small place, but an honest one.",
		"choices": [
			{"id": "marta_offer_help", "label": "Need any help around the village?", "available": true},
			{"id": "marta_leave", "label": "Noted.", "available": true}
		]
	}


static func offer_locket(journal: CampaignJournal, player: CharacterState) -> Dictionary:
	if journal == null or player == null:
		return {"ok": false, "reason": "missing_journal_or_player"}
	if not _locket_instance_id(player).is_empty():
		return {
			"ok": true,
			"dialogue": {
				"speaker": "Elder Marta Wynfield",
				"text": "Wait — is that... my mother's locket? You already have it! However did you find it out there?",
				"choices": [{"id": "marta_turn_in_locket", "label": "Found it lying around. Here.", "available": true}]
			}
		}
	return {
		"ok": true,
		"dialogue": {
			"speaker": "Elder Marta Wynfield",
			"text": "As it happens... I lost my mother's locket years back, somewhere near the old chapel. Silly to still hope, but if you ever spot it...",
			"choices": [{"id": "marta_accept_locket", "label": "I'll keep an eye out.", "available": true}]
		}
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


static func turn_in(journal: CampaignJournal, player: CharacterState) -> Dictionary:
	if journal == null or player == null:
		return {"ok": false, "reason": "missing_journal_or_player"}
	var state := journal.quest_state(QUEST_ID)
	var status := String(state.get("status", ""))
	if status == "completed":
		return {"ok": false, "reason": "quest_already_completed"}
	var locket_instance_id := _locket_instance_id(player)
	if locket_instance_id.is_empty():
		return {"ok": false, "reason": "locket_missing"}
	if status.is_empty():
		var accepted := accept(journal)
		if not bool(accepted.get("ok", false)):
			return accepted
	elif status != "active":
		return {"ok": false, "reason": "quest_not_active"}
	var progress := journal.set_objective_progress(QUEST_ID, OBJECTIVE_ID, 1.0)
	if not bool(progress.get("ok", false)):
		return progress
	if not player.remove_inventory_item(locket_instance_id):
		return {"ok": false, "reason": "locket_removal_failed"}
	var completion := journal.complete_quest(QUEST_ID)
	if not bool(completion.get("ok", false)):
		return completion
	player.gold += REWARD_GOLD
	player.experience += REWARD_EXPERIENCE
	var reputation := journal.adjust_npc_reputation(
		NPC_ID,
		REPUTATION_GAIN,
		KNOWLEDGE_GAIN,
		"Returned Elder Marta's mother's locket"
	)
	return {
		"ok": true,
		"quest_completed": true,
		"item_id": LOCKET_ITEM_ID,
		"gold_awarded": REWARD_GOLD,
		"experience_awarded": REWARD_EXPERIENCE,
		"npc_reputation": reputation
	}


static func resolve_choice(
	journal: CampaignJournal,
	player: CharacterState,
	choice_id: String
) -> Dictionary:
	match choice_id:
		"marta_offer_help":
			return offer_locket(journal, player)
		"marta_accept_locket":
			var accepted := accept(journal)
			if not bool(accepted.get("ok", false)):
				return accepted
			return {
				"ok": true,
				"dialogue": {
					"speaker": "Elder Marta Wynfield",
					"text": "As it happens... I lost my mother's locket years back, somewhere near the old chapel. Silly to still hope, but if you ever spot it...",
					"choices": [{"id": "marta_keep_looking", "label": "I'll keep an eye out.", "available": true}]
				}
			}
		"marta_turn_in_locket":
			var result := turn_in(journal, player)
			if not bool(result.get("ok", false)):
				return result
			return {
				"ok": true,
				"quest_completed": true,
				"reward": result,
				"dialogue": {
					"speaker": "Elder Marta Wynfield",
					"text": "Is that... you found it! My mother's locket, after all these years.",
					"choices": [{"id": "marta_leave", "label": "I'm glad I could help.", "available": true}]
				}
			}
		"marta_keep_looking", "marta_leave":
			return {"ok": true, "handled": true}
		_:
			return {"ok": false, "reason": "unknown_choice"}


static func _locket_instance_id(player: CharacterState) -> String:
	for item_value in player.inventory:
		if not item_value is Dictionary:
			continue
		var item: Dictionary = item_value
		if String(item.get("id", "")) == LOCKET_ITEM_ID and int(item.get("quantity", 1)) > 0:
			return String(item.get("instance_id", ""))
	return ""
