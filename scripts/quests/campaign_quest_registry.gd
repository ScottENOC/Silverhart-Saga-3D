class_name CampaignQuestRegistry
extends RefCounted
## Central catalogue of campaign quest content modules.
##
## Quest content remains independently testable. The registry is the only
## place that knows which modules contribute definitions to a campaign.

const COMPANION_RUNTIME_STORE = preload("res://scripts/simulation/companion_campaign_runtime_store.gd")
const ABANDONED_HOUSE = preload("res://scripts/simulation/abandoned_house_clearing_quest.gd")
const TOLL_TAKER = preload("res://scripts/simulation/toll_taker_quest_content.gd")
const REDDALE_INNKEEPER = preload("res://scripts/simulation/reddale_innkeeper_content.gd")
const IRONBOND_MISSING_COURIER = preload("res://scripts/simulation/ironbond_missing_courier_content.gd")
const BARON_TRIBUTE = preload("res://scripts/simulation/baron_tribute_content.gd")
const DWARVEN_AMBASSADOR = preload("res://scripts/simulation/dwarven_ambassador_content.gd")
const CORVANE_AMBASSADOR = preload("res://scripts/simulation/corvane_ambassador_content.gd")

# Keep quest IDs explicit here so duplicate registration can be prevented
# without relying on implementation-specific Script reflection.
const QUEST_CONTENT_MODULES: Array[Dictionary] = [
	{"id": "abandoned_house_cleared", "script": ABANDONED_HOUSE},
	{"id": "toll_ogre", "script": TOLL_TAKER},
	{"id": "nella_stone", "script": REDDALE_INNKEEPER},
	{"id": "ironbond_missing_courier", "script": IRONBOND_MISSING_COURIER},
	{"id": "baron_tribute", "script": BARON_TRIBUTE},
	{"id": "coin_for_the_deepholds", "script": DWARVEN_AMBASSADOR},
	{"id": "eyes_on_the_border", "script": CORVANE_AMBASSADOR},
]


static func register_definitions(simulation: WorldSimulation) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"ok": false, "reason": "missing_campaign_journal"}

	# Companion chapters and prerequisite quests share the campaign journal,
	# but retain their existing specialised runtime store.
	COMPANION_RUNTIME_STORE.register_quest_definitions(simulation)

	var registered: Array[String] = []
	var failed: Array[Dictionary] = []
	for module_entry in QUEST_CONTENT_MODULES:
		var quest_id := String(module_entry.get("id", ""))
		var module: Script = module_entry.get("script") as Script
		if module == null or quest_id.is_empty():
			failed.append({"module": quest_id, "reason": "invalid_registry_entry"})
			continue
		if simulation.campaign_journal.quest_definitions.has(quest_id):
			registered.append(quest_id)
			continue
		var result: Variant = module.call("register_definition", simulation.campaign_journal)
		if result is Dictionary and bool(result.get("ok", false)):
			registered.append(quest_id)
		else:
			failed.append({
				"quest_id": quest_id,
				"result": result if result is Dictionary else {"reason": "invalid_registration_result"}
			})

	return {
		"ok": failed.is_empty(),
		"registered_quest_ids": registered,
		"failed_quests": failed
	}
