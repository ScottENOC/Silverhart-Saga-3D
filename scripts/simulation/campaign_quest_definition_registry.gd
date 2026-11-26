class_name CampaignQuestDefinitionRegistry
extends RefCounted
## Registers all campaign quest schemas before save restoration so active and
## completed quest records survive load even when their content is elsewhere.

const COMPANION_CONTENT = preload("res://scripts/simulation/companion_campaign_content.gd")
const GOBLIN_CONTENT = preload("res://scripts/simulation/goblin_threat_campaign_content.gd")
const GOBLIN_FOLLOWUP_CONTENT = preload("res://scripts/simulation/goblin_threat_followup_content.gd")


static func register_all(journal: CampaignJournal) -> void:
	if journal == null:
		return
	COMPANION_CONTENT.register_quest_definitions(journal)
	var definitions: Array[Dictionary] = [
		GOBLIN_CONTENT.mine_raid_quest_definition(),
		GOBLIN_CONTENT.greenskin_spy_quest_definition(),
		GOBLIN_FOLLOWUP_CONTENT.new().goblin_spy_for_humans_quest_definition(),
		{
			"id": "goblin_scout_note",
			"title": "The Goblin Scout's Note",
			"description": "Read the oilcloth map found in the Skarn-tooth camp.",
			"objectives": []
		}
	]
	for definition in definitions:
		var quest_id := String(definition.get("id", ""))
		if not quest_id.is_empty() and not journal.quest_definitions.has(quest_id):
			journal.register_quest_definition(definition)
