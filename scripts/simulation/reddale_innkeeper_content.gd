class_name ReddaleInnkeeperContent
extends RefCounted
## Source-backed port of "A Stone for Nella" from campaign2Dialogue.js.
## The service owns quest state and inventory consequences; presentation calls
## greeting() and resolves the returned choice IDs.

const QUEST_ID := "a_stone_for_nella"
const OBJECTIVE_ID := "bring_blue_gem"
const NPC_ID := "nella_brook"
const GEM_ITEM_ID := "gem_blue"
const REWARD_GOLD := 20
const REWARD_REPUTATION := 20
const REWARD_KNOWLEDGE := 20


static func definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "A Stone for Nella",
		"description": "Bring Nella Brook a blue gem.",
		"objectives": [
			{"id": OBJECTIVE_ID, "description": "Bring Nella Brook a blue gem.", "target": 1.0, "required": true}
		]
	}


static func register_definition(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if journal.quest_definitions.has(QUEST_ID):
		return {"ok": true, "already_registered": true}
	return journal.register_quest_definition(definition())


static func greeting(
	journal: CampaignJournal,
	player: CharacterState,
	abandoned_house_journal_read: bool = false
) -> Dictionary:
	if journal == null or player == null:
		return {"ok": false, "reason": "missing_journal_or_player"}
	var state := journal.quest_state(QUEST_ID)
	var status := String(state.get("status", ""))
	if status == "active":
		if _blue_gem_instance_id(player).is_empty():
			return {
				"ok": true,
				"speaker": "Nella Brook",
				"text": "Still keeping an eye out for that blue stone? No rush.",
				"choices": [{"id": "nella_not_yet", "label": "I'll find one.", "text": ""}]
			}
		return {
			"ok": true,
			"speaker": "Nella Brook",
			"text": "Is that... you found one? A blue stone, just like I asked.",
			"choices": [
				{"id": "nella_turn_in", "label": "Here you go.", "text": ""},
				{"id": "nella_not_yet", "label": "Not yet.", "text": ""}
			]
		}
	if status == "completed":
		return {
			"ok": true,
			"speaker": "Nella Brook",
			"text": "Thank you again for finding my mother's stone. It means more than I can say.",
			"choices": [{"id": "nella_leave", "label": "I'm glad it found its way home.", "text": ""}]
		}
	if abandoned_house_journal_read:
		return {
			"ok": true,
			"speaker": "Nella Brook",
			"text": "Welcome to Reddale. Rooms are warm and the ale's better than the road food, I promise you that. A family out past Millbrook way went quiet a season back, and a grave near here was found disturbed not long after. Everyone says animals. I'm not so sure they're the same kind of quiet.",
			"choices": [{"id": "nella_leave", "label": "Worth looking into.", "text": ""}]
		}
	return {
		"ok": true,
		"speaker": "Nella Brook",
		"text": "Welcome to Reddale. Rooms are warm and the ale's better than the road food, I promise you that.",
		"choices": [
			{"id": "nella_offer_stone", "label": "Anything you need?", "text": ""},
			{"id": "nella_rumours", "label": "Hear anything from Hollowmere way?", "text": ""},
			{"id": "nella_leave", "label": "Good to know.", "text": ""}
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


static func turn_in(journal: CampaignJournal, player: CharacterState) -> Dictionary:
	if journal == null or player == null:
		return {"ok": false, "reason": "missing_journal_or_player"}
	if String(journal.quest_state(QUEST_ID).get("status", "")) != "active":
		return {"ok": false, "reason": "quest_not_active"}
	var gem_instance_id := _blue_gem_instance_id(player)
	if gem_instance_id.is_empty():
		return {"ok": false, "reason": "blue_gem_missing"}
	var progress := journal.set_objective_progress(QUEST_ID, OBJECTIVE_ID, 1.0)
	if not bool(progress.get("ok", false)):
		return progress
	if not player.remove_inventory_item(gem_instance_id):
		return {"ok": false, "reason": "blue_gem_removal_failed"}
	var completion := journal.complete_quest(QUEST_ID)
	if not bool(completion.get("ok", false)):
		return completion
	player.gold += REWARD_GOLD
	var reputation := journal.adjust_npc_reputation(
		NPC_ID,
		float(REWARD_REPUTATION),
		float(REWARD_KNOWLEDGE),
		"Returned Nella Brook's mother's blue stone"
	)
	return {
		"ok": true,
		"quest_completed": true,
		"item_id": GEM_ITEM_ID,
		"gold": REWARD_GOLD,
		"reputation": reputation
	}


static func resolve_choice(
	journal: CampaignJournal,
	player: CharacterState,
	choice_id: String
) -> Dictionary:
	match choice_id:
		"nella_offer_stone":
			var accepted := accept(journal)
			if not bool(accepted.get("ok", false)):
				return accepted
			return {
				"ok": true,
				"dialogue": {
					"speaker": "Nella Brook",
					"text": "Funny you ask — my mother always wore a blue stone, before we lost everything on the road here. If you ever find one out there, I'd pay well for it. Sentimental, I know.",
					"choices": [{"id": "nella_leave", "label": "I'll keep an eye out.", "text": ""}]
				}
			}
		"nella_turn_in":
			var reward := turn_in(journal, player)
			if not bool(reward.get("ok", false)):
				return reward
			return {
				"ok": true,
				"quest_completed": true,
				"reward": reward,
				"dialogue": {
					"speaker": "Nella Brook",
					"text": "Is that... you found one? A blue stone, just like I asked. Thank you. My mother would have been glad to know it was found.",
					"choices": [{"id": "nella_leave", "label": "I'm glad I could help.", "text": ""}]
				}
			}
		"nella_not_yet", "nella_leave", "nella_rumours":
			return {"ok": true, "handled": true}
		_:
			return {"ok": false, "reason": "unknown_choice"}


static func _blue_gem_instance_id(player: CharacterState) -> String:
	for item_value in player.inventory:
		if not item_value is Dictionary:
			continue
		var item: Dictionary = item_value
		if String(item.get("id", "")) == GEM_ITEM_ID and int(item.get("quantity", 1)) > 0:
			return String(item.get("instance_id", ""))
	return ""
