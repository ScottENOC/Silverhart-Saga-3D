class_name CampaignAmbassadorDialogueService
extends RefCounted
## Resolves the quest dialogue choices owned by six campaign NPC content
## modules. Coordinates domain content only; it never creates UI or accesses
## scene nodes.

const BROKK_CONTENT = preload("res://scripts/simulation/dwarven_ambassador_content.gd")
const TOREN_CONTENT = preload("res://scripts/simulation/corvane_ambassador_content.gd")
const CASSIA_CONTENT = preload("res://scripts/simulation/aldenreach_message_content.gd")
const MARTA_CONTENT = preload("res://scripts/simulation/elder_marta_content.gd")
const NELLA_CONTENT = preload("res://scripts/simulation/reddale_innkeeper_content.gd")
const BARON_CONTENT = preload("res://scripts/simulation/baron_tribute_content.gd")


static func resolve_choice(simulation: WorldSimulation, choice: Dictionary) -> Dictionary:
	var choice_id := String(choice.get("id", ""))
	var speaker := ""
	var result: Dictionary = {}
	var status_message := ""
	var completion_fallback := ""

	if choice_id.begins_with("brokk_"):
		speaker = "Ambassador Brokk Stonehammer"
		if simulation == null or simulation.campaign_journal == null:
			return _failure(speaker, "The campaign journal is unavailable.")
		result = BROKK_CONTENT.resolve_choice(simulation.campaign_journal, simulation.get_character(simulation.player_character_id), choice_id)
		if choice_id == "brokk_accept_toll":
			status_message = "Quest added: Coin for the Deepholds."
		if bool(result.get("quest_completed", false)):
			status_message = "Quest complete: Coin for the Deepholds  ·  -15 gold  ·  +60 XP"
		completion_fallback = "brokk"
	elif choice_id.begins_with("toren_"):
		speaker = "Ambassador Toren Aldwyn"
		if simulation == null or simulation.campaign_journal == null:
			return _failure(speaker, "The campaign journal is unavailable.")
		result = TOREN_CONTENT.resolve_choice(simulation.campaign_journal, simulation.get_character(simulation.player_character_id), choice_id)
		if choice_id == "toren_accept_report":
			status_message = "Quest added: Eyes on the Border."
		if bool(result.get("quest_completed", false)):
			status_message = "Quest complete: Eyes on the Border  ·  +15 gold  ·  +60 XP"
		completion_fallback = "toren"
	elif choice_id.begins_with("cassia_"):
		speaker = "Ambassador Cassia Wren"
		if simulation == null or simulation.campaign_journal == null:
			return _failure(speaker, "The campaign journal is unavailable.")
		result = CASSIA_CONTENT.resolve_choice(simulation.campaign_journal, simulation.get_character(simulation.player_character_id), choice_id)
		if bool(result.get("quest_started", false)):
			status_message = "Quest added: A Quiet Word."
		if bool(result.get("quest_completed", false)):
			status_message = "Quest complete: A Quiet Word  ·  +15 gold  ·  +60 XP"
	elif choice_id.begins_with("marta_"):
		speaker = "Elder Marta Wynfield"
		if simulation == null or simulation.campaign_journal == null:
			return _failure(speaker, "The campaign journal is unavailable.")
		result = MARTA_CONTENT.resolve_choice(simulation.campaign_journal, simulation.get_character(simulation.player_character_id), choice_id)
		if bool(result.get("quest_completed", false)):
			status_message = "Quest complete: A Missing Locket  ·  +20 gold  ·  +100 XP"
	elif choice_id.begins_with("nella_"):
		speaker = "Nella Brook"
		if simulation == null or simulation.campaign_journal == null:
			return _failure(speaker, "The campaign journal is unavailable.")
		result = NELLA_CONTENT.resolve_choice(simulation.campaign_journal, simulation.get_character(simulation.player_character_id), choice_id)
		if bool(result.get("quest_completed", false)):
			status_message = "Quest complete: A Stone for Nella  ·  +20 gold"
	elif choice_id.begins_with("baron_tribute_"):
		speaker = "Baron Corwin Aldervale"
		if simulation == null or simulation.campaign_journal == null:
			return _failure(speaker, "The campaign journal is unavailable.")
		result = BARON_CONTENT.resolve_choice(simulation.campaign_journal, simulation.get_character(simulation.player_character_id), choice_id)
		if bool(result.get("quest_completed", false)):
			status_message = "Quest complete: The Baron's Tribute  ·  +20 gold"
	else:
		return {"handled": false}

	if not bool(result.get("ok", false)):
		var reason := String(result.get("reason", "unknown error")).replace("_", " ")
		return {
			"handled": true,
			"ok": false,
			"status_message": "",
			"dialogue": {
				"speaker": speaker,
				"text": "That could not be completed: %s." % reason,
				"choices": [{"id": "continue", "label": "Understood.", "text": ""}]
			}
		}

	var dialogue: Variant = result.get("dialogue", {})
	if (not dialogue is Dictionary or dialogue.is_empty()) and bool(result.get("quest_completed", false)):
		if completion_fallback == "brokk":
			dialogue = BROKK_CONTENT.greeting(simulation.campaign_journal, simulation.get_character(simulation.player_character_id))
		elif completion_fallback == "toren":
			dialogue = TOREN_CONTENT.greeting(simulation.campaign_journal, simulation.get_character(simulation.player_character_id))
	if dialogue is Dictionary and not dialogue.is_empty():
		return {
			"handled": true,
			"ok": true,
			"status_message": status_message,
			"dialogue": dialogue
		}
	return {
		"handled": bool(result.get("handled", false)),
		"ok": true,
		"status_message": status_message,
		"close": bool(result.get("handled", false))
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
