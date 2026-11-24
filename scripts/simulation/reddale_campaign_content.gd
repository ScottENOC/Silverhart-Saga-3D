class_name ReddaleCampaignContent
extends RefCounted
## Source-backed port of Hex-crpg's Reddale's Cut decision.
## The Reeve's offer is gated by Ironbond's merchant influence in Silverhart.

const QUEST_ID := "reddale_cut"
const IRONBOND_ID := "ironbond_company"
const KINGDOM_ID := "silverhart_kingdom"
const WORLD_CONSEQUENCE_SERVICE = preload("res://scripts/simulation/campaign_world_consequence_service.gd")
const DEFAULT_IRONBOND_INFLUENCE := 30.0
const INFLUENCE_OFFER_THRESHOLD := 40.0
const FACTION_DECISION_SERVICE := preload("res://scripts/simulation/campaign_faction_decision_service.gd")


static func quest_definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": "Reddale's Cut",
		"description": "Decide how Reddale answers the Ironbond Company.",
		"objectives": [
			{
				"id": "response",
				"description": "Choose whether to resist Ironbond or broker its deal.",
				"target": 1.0,
				"required": true
			}
		]
	}


static func ironbond_influence(journal: CampaignJournal) -> float:
	if journal == null:
		return DEFAULT_IRONBOND_INFLUENCE
	var stored: Dictionary = journal.merchant_influence.get(IRONBOND_ID, {})
	return float(stored.get(KINGDOM_ID, DEFAULT_IRONBOND_INFLUENCE))


static func can_offer_cut(journal: CampaignJournal) -> bool:
	if journal == null or journal.quests.has(QUEST_ID):
		return false
	return ironbond_influence(journal) >= INFLUENCE_OFFER_THRESHOLD


static func start_cut(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if journal.quests.has(QUEST_ID):
		return {"ok": false, "reason": "quest_already_started"}
	if not can_offer_cut(journal):
		return {
			"ok": false,
			"reason": "influence_below_threshold",
			"required_influence": INFLUENCE_OFFER_THRESHOLD,
			"current_influence": ironbond_influence(journal)
		}
	var registration := journal.register_quest_definition(quest_definition())
	if not bool(registration.get("ok", false)):
		return registration
	return journal.start_quest(QUEST_ID)


static func choices() -> Array[Dictionary]:
	return [
		{
			"id": "resist_ironbond",
			"label": "Help you push back against Ironbond.",
			"ironbond_standing_delta": -15.0,
			"ironbond_knowledge_delta": 15.0,
			"influence_delta": -15.0,
			"kingdom_standing_delta": 20.0,
			"kingdom_knowledge_delta": 20.0,
			"gold_delta": 0,
			"settlement_updates": [{
				"settlement_id": "reddale",
				"deltas": {"public_order": 10.0, "ironbond_presence": -20.0},
				"flags": {"reeve_backed_resistance": true}
			}],
			"npc_updates": [{
				"npc_id": "reeve_aldous_finch",
				"deltas": {"trust": 15.0, "fear": -10.0},
				"flags": {"will_openly_oppose_ironbond": true, "public_status_visible": true, "public_status": "Openly opposes Ironbond"}
			}]
		},
		{
			"id": "broker_ironbond_deal",
			"label": "Broker the deal in Ironbond's favour. (+50 gold)",
			"ironbond_standing_delta": 20.0,
			"ironbond_knowledge_delta": 15.0,
			"influence_delta": 15.0,
			"kingdom_standing_delta": -10.0,
			"kingdom_knowledge_delta": 15.0,
			"gold_delta": 50,
			"settlement_updates": [{
				"settlement_id": "reddale",
				"deltas": {"prosperity": 8.0, "ironbond_presence": 20.0},
				"flags": {"ironbond_deal_brokered": true, "public_status_visible": true, "public_status": "Brokered Ironbond deal"}
			}],
			"npc_updates": [{
				"npc_id": "reeve_aldous_finch",
				"deltas": {"trust": 5.0, "fear": 5.0},
				"flags": {"will_openly_oppose_ironbond": false, "ironbond_deal_brokered": true}
			}]
		}
	]


static func resolve_cut(journal: CampaignJournal, choice_id: String) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var selected: Dictionary = {}
	for choice_value in choices():
		var choice: Dictionary = choice_value
		if String(choice.get("id", "")) == choice_id:
			selected = choice
			break
	if selected.is_empty():
		return {"ok": false, "reason": "choice_unavailable"}
	var reason := "Reddale's Cut: " + choice_id
	var faction_changes: Array[Dictionary] = [
		{
			"faction_id": IRONBOND_ID,
			"standing_delta": float(selected["ironbond_standing_delta"]),
			"knowledge_delta": float(selected["ironbond_knowledge_delta"])
		},
		{
			"faction_id": KINGDOM_ID,
			"standing_delta": float(selected["kingdom_standing_delta"]),
			"knowledge_delta": float(selected["kingdom_knowledge_delta"])
		}
	]
	var influence_changes: Array[Dictionary] = [{
		"faction_id": IRONBOND_ID,
		"kingdom_id": KINGDOM_ID,
		"amount": float(selected["influence_delta"])
	}]
	var consequence := FACTION_DECISION_SERVICE.apply_outcome(
		journal,
		QUEST_ID,
		"reeve_response",
		choice_id,
		faction_changes,
		influence_changes,
		reason
	)
	if not bool(consequence.get("ok", false)):
		return consequence
	var world_consequences := WORLD_CONSEQUENCE_SERVICE.apply_decision_consequences(
		journal,
		QUEST_ID,
		"reeve_response",
		selected.get("settlement_updates", []),
		selected.get("npc_updates", [])
	)
	if not bool(world_consequences.get("ok", false)):
		return world_consequences
	journal.set_objective_progress(QUEST_ID, "response", 1.0)
	var completion := journal.complete_quest(QUEST_ID)
	if not bool(completion.get("ok", false)):
		return completion
	return {
		"ok": true,
		"choice": selected.duplicate(true),
		"gold_delta": int(selected["gold_delta"]),
		"ironbond_influence": ironbond_influence(journal)
	}
