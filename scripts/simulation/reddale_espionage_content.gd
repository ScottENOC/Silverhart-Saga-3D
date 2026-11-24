class_name ReddaleEspionageContent
extends RefCounted
## Shared, persistent rules for Reddale's mirrored guildhouse/manor espionage.
## Physical stealth and evidence discovery are handled by the world layer;
## this service owns mission state, double-agent choices and consequences.

const GUILD_QUEST := "spy_on_guild"
const BARON_QUEST := "spy_on_baron"
const KINGDOM := "silverhart_kingdom"
const IRONBOND := "ironbond_company"
const FACTION_DECISIONS = preload("res://scripts/simulation/campaign_faction_decision_service.gd")
const WORLD_CONSEQUENCES = preload("res://scripts/simulation/campaign_world_consequence_service.gd")

static func quest_definition(quest_id: String) -> Dictionary:
	var is_guild := quest_id == GUILD_QUEST
	if not is_guild and quest_id != BARON_QUEST:
		return {}
	return {
		"id": quest_id,
		"title": "Eyes on the Guildhouse" if is_guild else "A Look at the Ledgers",
		"description": "Find Ironbond's private ledgers without being seen." if is_guild else "Find the Baron's real tariff tally without being seen.",
		"objectives": [{"id":"evidence", "description":"Recover the records and return to the employer.", "target":1.0, "required":true}]
	}

static func can_offer(journal: CampaignJournal, quest_id: String) -> bool:
	if journal == null or not quest_definition(quest_id):
		return false
	if journal.quests.has(GUILD_QUEST) or journal.quests.has(BARON_QUEST):
		return false
	if quest_id == GUILD_QUEST:
		return journal.faction_standing(KINGDOM) >= 20.0
	return journal.merchant_influence_for(IRONBOND, KINGDOM) >= 40.0

static func start(journal: CampaignJournal, quest_id: String) -> Dictionary:
	if not can_offer(journal, quest_id):
		return {"ok":false, "reason":"quest_unavailable"}
	var registration := journal.register_quest_definition(quest_definition(quest_id))
	if not bool(registration.get("ok", false)):
		return registration
	return journal.start_quest(quest_id)

static func record_double_agent(journal: CampaignJournal, quest_id: String, side_id: String, accept: bool) -> Dictionary:
	if journal == null or not journal.quests.has(quest_id):
		return {"ok":false, "reason":"quest_not_started"}
	var quest: Dictionary = journal.quests[quest_id]
	if String(quest.get("status", "")) != "active" or quest.has("double_agent_for") or quest.has("double_cross_declined"):
		return {"ok":false, "reason":"double_cross_unavailable"}
	var expected_side := KINGDOM if quest_id == BARON_QUEST else IRONBOND
	if side_id != expected_side:
		return {"ok":false, "reason":"invalid_double_agent_side"}
	quest["double_cross_offered"] = true
	if accept:
		quest["double_agent_for"] = side_id
	else:
		quest["double_cross_declined"] = true
	journal.quests[quest_id] = quest
	var delta := 10.0 if accept else -10.0
	var standing := journal.adjust_faction_reputation(side_id, delta, 15.0, "Reddale espionage double-cross")
	return {"ok":true, "accepted":accept, "faction_result":standing}

static func fail(journal: CampaignJournal, quest_id: String) -> Dictionary:
	if journal == null or not journal.quests.has(quest_id):
		return {"ok":false, "reason":"quest_not_started"}
	var quest: Dictionary = journal.quests[quest_id]
	if String(quest.get("status", "")) != "active":
		return {"ok":false, "reason":"quest_not_active"}
	var spied_faction := IRONBOND if quest_id == GUILD_QUEST else KINGDOM
	var failed := journal.fail_quest(quest_id, "Detected by the target faction's guard")
	if not bool(failed.get("ok", false)):
		return failed
	var reputation := journal.adjust_faction_reputation(spied_faction, -20.0, 15.0, "Caught during Reddale espionage")
	return {"ok":true, "quest_id":quest_id, "reputation":reputation}

static func complete(journal: CampaignJournal, quest_id: String, player: CharacterState) -> Dictionary:
	if journal == null or player == null:
		return {"ok":false, "reason":"missing_journal_or_player"}
	if not journal.quests.has(quest_id):
		return {"ok":false, "reason":"quest_not_started"}
	var quest: Dictionary = journal.quests[quest_id]
	if String(quest.get("status", "")) != "active":
		return {"ok":false, "reason":"quest_not_active"}
	var is_guild := quest_id == GUILD_QUEST
	if not is_guild and quest_id != BARON_QUEST:
		return {"ok":false, "reason":"unknown_quest"}
	var employer := KINGDOM if is_guild else IRONBOND
	var target := IRONBOND if is_guild else KINGDOM
	var double_agent := String(quest.get("double_agent_for", "")) == target
	var faction_changes: Array[Dictionary] = []
	var influence_changes: Array[Dictionary] = []
	if double_agent:
		# The employer rewards the double agent; the target's anger is avoided.
		faction_changes = [
			{"faction_id":employer, "standing_delta":20.0, "knowledge_delta":20.0},
			{"faction_id":target, "standing_delta":0.0, "knowledge_delta":15.0}
		]
	else:
		faction_changes = [
			{"faction_id":employer, "standing_delta":15.0 if is_guild else -20.0, "knowledge_delta":15.0},
			{"faction_id":target, "standing_delta":-20.0 if is_guild else 15.0, "knowledge_delta":20.0}
		]
		influence_changes = [{"faction_id":IRONBOND, "kingdom_id":KINGDOM, "amount":-10.0 if is_guild else 10.0}]
	var choice_id := "double_agent_success" if double_agent else "evidence_delivered"
	var decision := FACTION_DECISIONS.apply_outcome(
		journal, quest_id, "evidence_returned", choice_id, faction_changes,
		influence_changes, "Reddale espionage: " + quest_id
	)
	if not bool(decision.get("ok", false)):
		return decision
	var world_updates := WORLD_CONSEQUENCES.apply_decision_consequences(
		journal, quest_id, "evidence_returned",
		[{"settlement_id":"reddale", "deltas":{"ironbond_presence":-8.0 if is_guild and not double_agent else (8.0 if not is_guild and not double_agent else 0.0)}, "flags":{"guild_ledgers_exposed":is_guild, "baron_tariffs_exposed":not is_guild}}],
		[{"npc_id":"petra_voss" if is_guild else "baron_corwin_aldervale", "deltas":{"trust":20.0 if is_guild else 20.0}, "flags":{"espionage_evidence_received":true, "double_agent":double_agent}}]
	)
	if not bool(world_updates.get("ok", false)):
		return world_updates
	journal.set_objective_progress(quest_id, "evidence", 1.0)
	var completed := journal.complete_quest(quest_id)
	if not bool(completed.get("ok", false)):
		return completed
	var reward := 60 if double_agent else 40
	player.gold += reward
	player.experience += 150
	return {"ok":true, "quest_id":quest_id, "double_agent":double_agent, "gold_delta":reward, "player_gold":player.gold, "experience_delta":150}

static func quest_for_employer(employer_npc_id: String) -> String:
	if employer_npc_id == "baron_corwin_aldervale":
		return GUILD_QUEST
	if employer_npc_id == "petra_voss":
		return BARON_QUEST
	return ""
