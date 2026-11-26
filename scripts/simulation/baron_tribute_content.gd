class_name BaronTributeContent
extends RefCounted
## Source-backed port of "The Baron's Tribute" from campaign2Dialogue.js.
## This is the tribute quest branch only; the Baron's separate espionage
## dialogue and double-cross branches remain independently owned.

const QUEST_ID := "baron_tribute"
const OBJECTIVE_ID := "present_red_gem"
const NPC_ID := "baron_corwin_aldervale"
const FACTION_ID := "silverhart_kingdom"
const GEM_ITEM_ID := "gem_red"
const REWARD_GOLD := 20
const NPC_REPUTATION_GAIN := 20.0
const NPC_KNOWLEDGE_GAIN := 20.0
const FACTION_REPUTATION_GAIN := 10.0
const FACTION_KNOWLEDGE_GAIN := 15.0


static func definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "The Baron's Tribute",
		"description": "Bring Baron Corwin Aldervale a red gem as tribute.",
		"objectives": [
			{"id": OBJECTIVE_ID, "description": "Present Baron Corwin Aldervale with a red gem.", "target": 1.0, "required": true}
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
		if _red_gem_instance_id(player).is_empty():
			return {
				"ok": true,
				"speaker": "Baron Corwin Aldervale",
				"text": "Still no tribute? A red stone isn't so hard to find, surely.",
				"choices": [{"id": "baron_tribute_wait", "label": "Still looking.", "text": ""}]
			}
		return {
			"ok": true,
			"speaker": "Baron Corwin Aldervale",
			"text": "A tribute, is it? Let's see it, then.",
			"choices": [
				{"id": "baron_tribute_present", "label": "Present the gem.", "text": ""},
				{"id": "baron_tribute_wait", "label": "Not yet.", "text": ""}
			]
		}
	if status == "completed":
		return {
			"ok": true,
			"speaker": "Baron Corwin Aldervale",
			"text": "A fine stone. You understand how to show respect to the crown's appointed stewards.",
			"choices": [{"id": "baron_tribute_leave", "label": "I understand.", "text": ""}]
		}
	return {
		"ok": true,
		"speaker": "Baron Corwin Aldervale",
		"text": "Reddale answers to me, same as the rest of the barony. Mind your business here and we'll get along fine. Bring a gift worth the visit and I'll remember it kindly — a fine red gem would do nicely.",
		"choices": [
			{"id": "baron_tribute_offer", "label": "I'll bring you a tribute.", "text": ""},
			{"id": "baron_tribute_leave", "label": "Understood.", "text": ""}
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
	var gem_instance_id := _red_gem_instance_id(player)
	if gem_instance_id.is_empty():
		return {"ok": false, "reason": "red_gem_missing"}
	var progress := journal.set_objective_progress(QUEST_ID, OBJECTIVE_ID, 1.0)
	if not bool(progress.get("ok", false)):
		return progress
	if not player.remove_inventory_item(gem_instance_id):
		return {"ok": false, "reason": "red_gem_removal_failed"}
	var completion := journal.complete_quest(QUEST_ID)
	if not bool(completion.get("ok", false)):
		return completion
	player.gold += REWARD_GOLD
	var npc_reputation := journal.adjust_npc_reputation(
		NPC_ID,
		NPC_REPUTATION_GAIN,
		NPC_KNOWLEDGE_GAIN,
		"Presented Baron Corwin Aldervale with a red gem"
	)
	var faction_reputation := journal.adjust_faction_reputation(
		FACTION_ID,
		FACTION_REPUTATION_GAIN,
		FACTION_KNOWLEDGE_GAIN,
		"Presented Baron Corwin Aldervale with a red gem"
	)
	return {
		"ok": true,
		"quest_completed": true,
		"item_id": GEM_ITEM_ID,
		"gold_awarded": REWARD_GOLD,
		"npc_reputation": npc_reputation,
		"faction_reputation": faction_reputation
	}


static func resolve_choice(journal: CampaignJournal, player: CharacterState, choice_id: String) -> Dictionary:
	match choice_id:
		"baron_tribute_offer":
			var accepted := accept(journal)
			if not bool(accepted.get("ok", false)):
				return accepted
			return {"ok": true, "dialogue": greeting(journal, player)}
		"baron_tribute_present":
			var reward := turn_in(journal, player)
			if not bool(reward.get("ok", false)):
				return reward
			return {
				"ok": true,
				"quest_completed": true,
				"reward": reward,
				"dialogue": {
					"speaker": "Baron Corwin Aldervale",
					"text": "A tribute, is it? Let's see it, then.",
					"choices": [{"id": "baron_tribute_leave", "label": "I understand.", "text": ""}]
				}
			}
		"baron_tribute_wait", "baron_tribute_leave":
			return {"ok": true, "handled": true}
		_:
			return {"ok": false, "reason": "unknown_choice"}


static func _red_gem_instance_id(player: CharacterState) -> String:
	for item_value in player.inventory:
		if not item_value is Dictionary:
			continue
		var item: Dictionary = item_value
		if String(item.get("id", "")) == GEM_ITEM_ID and int(item.get("quantity", 1)) > 0:
			return String(item.get("instance_id", ""))
	return ""
