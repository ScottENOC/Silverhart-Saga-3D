class_name DwarvenAmbassadorContent
extends RefCounted
## Source-backed port of "Coin for the Deepholds" from campaign2Dialogue.js.
## The letter-delivery follow-up is deliberately kept as a separate quest.

const QUEST_ID := "dwarven_toll"
const OBJECTIVE_ID := "pay_trade_toll"
const NPC_ID := "ambassador_brokk_stonehammer_dwarf_male"
const FACTION_ID := "dwarven_kingdom"
const TOLL_GOLD := 15
const REWARD_EXPERIENCE := 60
const NPC_REPUTATION := 10.0
const FACTION_REPUTATION := 10.0
const KNOWLEDGE_GAIN := 15.0


static func definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "Coin for the Deepholds",
		"description": "Pay a 15 gold trade toll to Ambassador Brokk Stonehammer.",
		"objectives": [
			{"id": OBJECTIVE_ID, "description": "Pay the 15 gold trade toll.", "target": 1.0, "required": true}
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
	var state := journal.quest_state(QUEST_ID)
	var status := String(state.get("status", ""))
	if status == "active":
		if player.gold >= TOLL_GOLD:
			return {
				"ok": true,
				"speaker": "Ambassador Brokk Stonehammer",
				"text": "Fifteen gold, as agreed. Not charity — a toll, same as any trade road. The Deepholds don't forget who pays their way.",
				"choices": [
					{"id": "brokk_pay_toll", "label": "Here.", "available": true},
					{"id": "brokk_not_yet", "label": "Not yet.", "available": true}
				]
			}
		return {
			"ok": true,
			"speaker": "Ambassador Brokk Stonehammer",
			"text": "Fifteen gold, when you have it. The Deepholds trade in iron and good sense, in roughly that order.",
			"choices": [{"id": "brokk_soon", "label": "Soon.", "available": true}]
		}
	if status == "completed":
		return {
			"ok": true,
			"speaker": "Ambassador Brokk Stonehammer",
			"text": "Silverhart's been fair with us. Long may that last — and you've done your part toward it.",
			"choices": [{"id": "brokk_leave", "label": "Long may it last.", "available": true}]
		}
	return {
		"ok": true,
		"speaker": "Ambassador Brokk Stonehammer",
		"text": "The Deepholds trade in iron and good sense, in roughly that order. A trade toll of fifteen gold would smooth the road between us — nothing more than that, for now.",
		"choices": [
			{"id": "brokk_accept_toll", "label": "I'll pay the toll.", "available": true},
			{"id": "brokk_leave", "label": "Long may it last.", "available": true}
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


static func pay_toll(journal: CampaignJournal, player: CharacterState) -> Dictionary:
	if journal == null or player == null:
		return {"ok": false, "reason": "missing_journal_or_player"}
	if String(journal.quest_state(QUEST_ID).get("status", "")) != "active":
		return {"ok": false, "reason": "quest_not_active"}
	if player.gold < TOLL_GOLD:
		return {"ok": false, "reason": "insufficient_gold"}
	var progress := journal.set_objective_progress(QUEST_ID, OBJECTIVE_ID, 1.0)
	if not bool(progress.get("ok", false)):
		return progress
	player.gold -= TOLL_GOLD
	var completion := journal.complete_quest(QUEST_ID)
	if not bool(completion.get("ok", false)):
		player.gold += TOLL_GOLD
		return completion
	player.experience += REWARD_EXPERIENCE
	var npc_result := journal.adjust_npc_reputation(
		NPC_ID, NPC_REPUTATION, KNOWLEDGE_GAIN, "Paid the Deepholds trade toll"
	)
	var faction_result := journal.adjust_faction_reputation(
		FACTION_ID, FACTION_REPUTATION, KNOWLEDGE_GAIN, "Paid the Deepholds trade toll"
	)
	return {
		"ok": true,
		"quest_completed": true,
		"gold_paid": TOLL_GOLD,
		"experience_awarded": REWARD_EXPERIENCE,
		"npc_reputation": npc_result,
		"faction_reputation": faction_result
	}


static func resolve_choice(journal: CampaignJournal, player: CharacterState, choice_id: String) -> Dictionary:
	match choice_id:
		"brokk_accept_toll":
			var accepted := accept(journal)
			if not bool(accepted.get("ok", false)):
				return accepted
			return {
				"ok": true,
				"dialogue": {
					"speaker": "Ambassador Brokk Stonehammer",
					"text": "Fifteen gold, when you have it. The Deepholds trade in iron and good sense, in roughly that order.",
					"choices": [{"id": "brokk_soon", "label": "Soon.", "available": true}]
				}
			}
		"brokk_pay_toll":
			return pay_toll(journal, player)
		"brokk_not_yet", "brokk_soon", "brokk_leave":
			return {"ok": true, "handled": true}
		_:
			return {"ok": false, "reason": "unknown_choice"}
