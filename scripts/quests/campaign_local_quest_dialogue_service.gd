class_name CampaignLocalQuestDialogueService
extends RefCounted
## Routes local campaign quest choices through their existing content modules.
## World-specific consequences are returned as flags for the scene adapter; this
## service never creates actors, starts UI, or accesses scene nodes.

const FARM_WOLVES_CONTENT = preload("res://scripts/simulation/farm_wolves_quest.gd")
const MISSING_COURIER_CONTENT = preload("res://scripts/simulation/ironbond_missing_courier_content.gd")
const TOLL_TAKER_CONTENT = preload("res://scripts/simulation/toll_taker_quest_content.gd")


static func resolve_choice(
	simulation: WorldSimulation,
	choice: Dictionary,
	ogre_alive: bool = true
) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"handled": false, "ok": false, "reason": "missing_campaign"}
	var choice_id := String(choice.get("id", ""))
	var player := simulation.get_character(simulation.player_character_id)
	var result: Dictionary = {}
	var status_message := ""
	var spawn_ogre := false

	if choice_id.begins_with("farm_wolves_"):
		result = FARM_WOLVES_CONTENT.resolve_dialogue_choice(
			simulation.campaign_journal,
			simulation.get_character("player"),
			choice_id,
			String(choice.get("text", "Take care on the road."))
		)
		if not bool(result.get("handled", false)):
			return {"handled": false}
		if bool(result.get("quest_completed", false)):
			status_message = "Quest complete: Wolves at the Farm  ·  +25 gold  ·  +150 XP"
	elif choice_id.begins_with("ironbond_courier_"):
		result = MISSING_COURIER_CONTENT.resolve_choice(simulation.campaign_journal, choice_id)
		if not bool(result.get("ok", false)):
			return _failure("Dray Coltayne", "That job cannot be recorded just now: %s." % String(result.get("reason", "unknown error")).replace("_", " "))
		if bool(result.get("quest_started", false)):
			status_message = "Quest added: The Missing Courier  ·  +10 Ironbond reputation"
	elif choice_id.begins_with("toll_ogre_"):
		result = TOLL_TAKER_CONTENT.resolve_choice(
			simulation.campaign_journal,
			player,
			choice_id,
			ogre_alive
		)
		if not bool(result.get("ok", false)):
			return _failure("Petra Hollis", "That cannot be resolved just now: %s." % String(result.get("reason", "unknown error")).replace("_", " "))
		spawn_ogre = choice_id == "toll_ogre_accept"
		if spawn_ogre:
			status_message = "Quest added: The Toll-Taker. The ogre is beyond the abandoned house."
	else:
		return {"handled": false}

	var dialogue: Variant = result.get("dialogue", {})
	var has_dialogue := dialogue is Dictionary and not dialogue.is_empty()
	return {
		"handled": bool(result.get("handled", true)),
		"ok": true,
		"dialogue": dialogue if has_dialogue else {},
		"status_message": status_message,
		"spawn_ogre": spawn_ogre,
		"close": bool(result.get("handled", false)) and not has_dialogue
	}


static func _failure(speaker: String, message: String) -> Dictionary:
	return {
		"handled": true,
		"ok": false,
		"dialogue": {
			"speaker": speaker,
			"text": message,
			"choices": [{"id": "continue", "label": "Understood.", "text": ""}]
		}
	}
