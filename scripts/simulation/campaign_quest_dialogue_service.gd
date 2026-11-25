class_name CampaignQuestDialogueService
extends RefCounted
## Adapts quest-domain services to the campaign dialogue presentation contract.
## Location controllers identify the actor and display the returned dialogue;
## quest-specific text, choices and state changes stay outside the location.

const FARM_WOLVES_QUEST := preload("res://scripts/simulation/farm_wolves_quest.gd")


static func greeting_for_npc(
	npc_id: String,
	journal: CampaignJournal,
	context: Dictionary = {}
) -> Dictionary:
	match npc_id:
		"old_mac":
			return FARM_WOLVES_QUEST.greeting(journal, int(context.get("wolves_remaining", 0)))
		_:
			return {}


static func resolve_choice(
	npc_id: String,
	journal: CampaignJournal,
	player: CharacterState,
	choice_id: String,
	choice_text: String = ""
) -> Dictionary:
	match npc_id:
		"old_mac":
			return FARM_WOLVES_QUEST.resolve_dialogue_choice(journal, player, choice_id, choice_text)
		_:
			return {"handled": false}
