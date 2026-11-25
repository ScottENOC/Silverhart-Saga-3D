class_name OrcStrongholdCampaignContent
extends RefCounted
## Quest and recruitment rules for Skarnak's Hold.
## The world owns the troll actor; this service owns the quest and rewards.

const QUEST_ID := "orc_stronghold_trust"
const GRUKK_ID := "warlord_grukk_ironhide"
const TROLL_ID := "orc_stronghold_troll"
const QUEST_TITLE := "Prove Your Strength"

static func quest_definition() -> Dictionary:
	return {
		"id": QUEST_ID,
		"title": QUEST_TITLE,
		"giver": "Warlord Grukk Ironhide",
		"description": "A troll denning east of Skarnak's Hold has been killing orc scouts and cattle. Kill it to earn the stronghold's trust.",
		"objectives": [
			{"id":"kill_troll","description":"Defeat the troll east of Skarnak's Hold."}
		]
	}


static func accept(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok":false,"reason":"missing_campaign_journal"}
	if not journal.quest_definitions.has(QUEST_ID):
		var registered := journal.register_quest_definition(quest_definition())
		if not bool(registered.get("ok", false)):
			return registered
	var current := journal.quest_state(QUEST_ID)
	if String(current.get("status", "")) == "active":
		return {"ok":true,"applied":false,"reason":"already_active"}
	if String(current.get("status", "")) == "completed":
		return {"ok":false,"reason":"already_completed"}
	return journal.start_quest(QUEST_ID)


static func complete_if_troll_defeated(journal: CampaignJournal, player: CharacterState, troll: CharacterState) -> Dictionary:
	if journal == null or player == null or troll == null:
		return {"ok":false,"reason":"missing_campaign_actor"}
	if troll.id != TROLL_ID or troll.alive:
		return {"ok":false,"reason":"troll_not_defeated"}
	var quest := journal.quest_state(QUEST_ID)
	if String(quest.get("status", "")) != "active":
		return {"ok":false,"reason":"quest_not_active"}
	var recorded := journal.record_decision(QUEST_ID, "troll_defeated", TROLL_ID)
	if not bool(recorded.get("ok", false)):
		return recorded
	var standing := journal.adjust_faction_reputation("orc_raiders", 25.0, 25.0, "orc_stronghold_troll_defeated")
	if not bool(standing.get("ok", false)):
		return standing
	var objective := journal.set_objective_progress(QUEST_ID, "kill_troll", 1.0)
	if not bool(objective.get("ok", false)):
		return objective
	var completed := journal.complete_quest(QUEST_ID)
	if not bool(completed.get("ok", false)):
		return completed
	player.gold += 40
	player.experience += 150
	return {
		"ok":true,
		"applied":true,
		"gold_awarded":40,
		"experience_awarded":150,
		"faction_standing":standing,
		"message":"The denning troll stops taking our scouts, and a stranger's the one who stopped it. Good work. You've earned a proper welcome here."
	}


static func can_recruit_grukk(journal: CampaignJournal, grukk: CharacterState) -> bool:
	if journal == null or grukk == null or grukk.id != GRUKK_ID:
		return false
	if String(journal.quest_state(QUEST_ID).get("status", "")) != "completed":
		return false
	if journal.faction_standing("orc_raiders") < 40.0:
		return false
	return grukk.side != "player"


static func recruit_grukk(simulation: WorldSimulation) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"ok":false,"reason":"missing_campaign"}
	var grukk := simulation.get_character(GRUKK_ID)
	if not can_recruit_grukk(simulation.campaign_journal, grukk):
		return {"ok":false,"reason":"recruitment_requirements_not_met"}
	return simulation.recruit_companion(GRUKK_ID)


static func warlord_greeting(journal: CampaignJournal, simulation: WorldSimulation, grukk: CharacterState) -> Dictionary:
	if journal == null or simulation == null or grukk == null:
		return {}
	var quest := journal.quest_state(QUEST_ID)
	var status := String(quest.get("status", ""))
	if status == "active":
		var player := simulation.get_character(simulation.player_character_id)
		var troll := simulation.get_character(TROLL_ID)
		if troll != null and not troll.alive:
			var resolved := complete_if_troll_defeated(journal, player, troll)
			if bool(resolved.get("ok", false)):
				return _conversation("The denning troll stops taking our scouts, and a stranger's the one who stopped it. Good work. You've earned a proper welcome here.", [
					{"id":"leave","label":"Glad to help.","text":"Grukk gives a short, approving nod."}
				])
		return _conversation("That troll still denning east of here? Deal with it and we'll talk properly.", [
			{"id":"leave","label":"I'm working on it.","text":"Grukk folds his arms."}
		])
	if status == "completed":
		if simulation.is_party_member(GRUKK_ID):
			return _conversation("Hold's still standing. What is it?", [
				{"id":"leave","label":"Nothing, carry on.","text":"Grukk returns to watching the gate."}
			])
		if journal.faction_standing("orc_raiders") >= 40.0:
			return _conversation("Skarnak's Hold remembers who dealt with the troll, and Kesh trades with you properly now — but I've had my fill of sitting behind a stockade counting raids. There's more out there worth breaking than trolls. Room for a warlord at your back?", [
				{"id":"orc_grukk_recruit","label":"Come with me.","text":"Grukk shoulders his axe and falls in beside you."},
				{"id":"leave","label":"Not yet.","text":"Grukk nods once and remains at the hold."}
			])
		return _conversation("Skarnak's Hold remembers who dealt with the troll. Kesh will trade with you properly now.", [
			{"id":"leave","label":"Good to know.","text":"Grukk gives a short, approving nod."}
		])
	return _conversation("Humans don't usually walk in here and expect to walk out. Something's been picking off our scouts and cattle east of the stockade — a troll, denned in the rocks. Kill it, and maybe you're worth talking to.", [
		{"id":"orc_stronghold_accept","label":"I'll deal with it.","text":"Grukk nods. "Then prove it. The den is east of the stockade, among the rocks.""},
		{"id":"leave","label":"Not interested.","text":"Grukk's expression hardens."}
	])


static func _conversation(body: String, choices: Array[Dictionary]) -> Dictionary:
	return {"ok":true,"speaker":"Warlord Grukk Ironhide","text":body,"choices":choices.duplicate(true)}
