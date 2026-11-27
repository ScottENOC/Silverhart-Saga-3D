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

const QUEST_CONTENT_MODULES: Array[Script] = [
	ABANDONED_HOUSE,
	TOLL_TAKER,
	REDDALE_INNKEEPER,
	IRONBOND_MISSING_COURIER,
	BARON_TRIBUTE,
	DWARVEN_AMBASSADOR,
	CORVANE_AMBASSADOR,
]


static func register_definitions(simulation: WorldSimulation) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"ok": false, "reason": "missing_campaign_journal"}

	# Companion chapters and prerequisite quests share the campaign journal,
	# but retain their existing specialised runtime store.
	COMPANION_RUNTIME_STORE.register_quest_definitions(simulation)

	var registered: Array[String] = []
	var failed: Array[Dictionary] = []
	for module in QUEST_CONTENT_MODULES:
		if not module.has_method("register_definition"):
			continue
		var result: Variant = module.call("register_definition", simulation.campaign_journal)
		if result is Dictionary and bool(result.get("ok", false)):
			registered.append(module.resource_path)
		else:
			failed.append({
				"module": module.resource_path,
				"result": result if result is Dictionary else {"reason": "invalid_registration_result"}
			})

	return {
		"ok": failed.is_empty(),
		"registered_modules": registered,
		"failed_modules": failed
	}
