class_name CampaignQuestDialogueDispatcher
extends RefCounted
## Resolves authored quest dialogue choices without depending on a world scene.
##
## The dispatcher returns simulation results. Actor creation, status labels and
## dialogue presentation remain responsibilities of the active world scene.

const FARM_WOLVES = preload("res://scripts/simulation/farm_wolves_quest.gd")
const TOLL_TAKER_CONTENT = preload("res://scripts/simulation/toll_taker_quest_content.gd")
const TOLL_TAKER_ENCOUNTER = preload("res://scripts/simulation/toll_taker_quest_encounter.gd")
const ELDER_MARTA = preload("res://scripts/simulation/elder_marta_content.gd")
const NELLA = preload("res://scripts/simulation/reddale_innkeeper_content.gd")
const IRONBOND_COURIER = preload("res://scripts/simulation/ironbond_missing_courier_content.gd")
const BARON_TRIBUTE = preload("res://scripts/simulation/baron_tribute_content.gd")
const DWARVEN_AMBASSADOR = preload("res://scripts/simulation/dwarven_ambassador_content.gd")
const CORVANE_AMBASSADOR = preload("res://scripts/simulation/corvane_ambassador_content.gd")
const ALDENREACH_MESSAGE = preload("res://scripts/simulation/aldenreach_message_content.gd")


static func greeting_for_actor(
	simulation: WorldSimulation,
	dialogue_id: String,
	context: Dictionary = {}
) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {}
	var journal = simulation.campaign_journal
	var player = simulation.get_character(simulation.player_character_id)
	match dialogue_id:
		"old_mac":
			return FARM_WOLVES.greeting(journal, int(context.get("remaining_wolves", 0)))
		"elder_marta", "marta_wynfield":
			var delivery: Dictionary = ALDENREACH_MESSAGE.deliver_to_elder(journal)
			var conversation: Dictionary = ELDER_MARTA.greeting(journal, player)
			conversation["delivered_now"] = bool(delivery.get("delivered_now", false))
			return conversation
		"dray_coltayne":
			return IRONBOND_COURIER.greeting(journal)
		"petra_hollis":
			return TOLL_TAKER_CONTENT.greeting(journal, TOLL_TAKER_ENCOUNTER.is_alive(simulation))
		"reddale_innkeeper":
			return NELLA.greeting(journal, player, bool(context.get("abandoned_house_journal_read", false)))
		"reddale_baron":
			return BARON_TRIBUTE.greeting(journal, player)
		"dwarven_ambassador":
			return DWARVEN_AMBASSADOR.greeting(journal, player)
		"corvane_ambassador":
			return CORVANE_AMBASSADOR.greeting(journal, player)
		"aldenreach_ambassador":
			return ALDENREACH_MESSAGE.greeting(journal)
	return {}


static func resolve_choice(simulation: WorldSimulation, choice: Dictionary) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"handled": false, "reason": "missing_campaign_journal"}

	var choice_id := String(choice.get("id", ""))
	var journal = simulation.campaign_journal
	var player = simulation.get_character(simulation.player_character_id)
	var quest_id := ""
	var fallback_speaker := "Campaign journal"
	var result: Dictionary = {}

	if choice_id.begins_with("ironbond_courier_"):
		quest_id = "ironbond_missing_courier"
		fallback_speaker = "Dray Coltayne"
		result = IRONBOND_COURIER.resolve_choice(journal, choice_id)
	elif choice_id.begins_with("toll_ogre_"):
		quest_id = "toll_ogre"
		fallback_speaker = "Petra Hollis"
		result = TOLL_TAKER_CONTENT.resolve_choice(
			journal,
			player,
			choice_id,
			TOLL_TAKER_ENCOUNTER.is_alive(simulation)
		)
	elif choice_id.begins_with("farm_wolves_"):
		quest_id = "farm_wolves"
		fallback_speaker = "Old Mac"
		result = FARM_WOLVES.resolve_dialogue_choice(
			journal,
			simulation.get_character("player"),
			choice_id,
			String(choice.get("text", "Take care on the road."))
		)
		if not bool(result.get("handled", false)):
			return {"handled": false}
	elif choice_id.begins_with("brokk_"):
		quest_id = "dwarven_toll"
		fallback_speaker = "Ambassador Brokk Stonehammer"
		result = DWARVEN_AMBASSADOR.resolve_choice(journal, player, choice_id)
	elif choice_id.begins_with("toren_"):
		quest_id = "corvane_watch"
		fallback_speaker = "Ambassador Toren Aldwyn"
		result = CORVANE_AMBASSADOR.resolve_choice(journal, player, choice_id)
	elif choice_id.begins_with("cassia_"):
		quest_id = "aldenreach_message"
		fallback_speaker = "Ambassador Cassia Wren"
		result = ALDENREACH_MESSAGE.resolve_choice(journal, player, choice_id)
	elif choice_id.begins_with("marta_"):
		quest_id = "elder_locket"
		fallback_speaker = "Elder Marta Wynfield"
		result = ELDER_MARTA.resolve_choice(journal, player, choice_id)
	elif choice_id.begins_with("nella_"):
		quest_id = "a_stone_for_nella"
		fallback_speaker = "Nella Brook"
		result = NELLA.resolve_choice(journal, player, choice_id)
	elif choice_id.begins_with("baron_tribute_"):
		quest_id = "baron_tribute"
		fallback_speaker = "Baron Corwin Aldervale"
		result = BARON_TRIBUTE.resolve_choice(journal, player, choice_id)
	else:
		return {"handled": false}

	return {
		"handled": true,
		"quest_id": quest_id,
		"speaker": fallback_speaker,
		"result": result
	}
