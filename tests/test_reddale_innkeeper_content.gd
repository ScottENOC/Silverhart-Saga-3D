extends SceneTree

const INNKEEPER_CONTENT = preload("res://scripts/simulation/reddale_innkeeper_content.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_source_backed_nella_quest()
	if _failures > 0:
		push_error("%d Nella quest assertion(s) failed." % _failures)
		quit(1)
		return
	print("Reddale innkeeper content tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_source_backed_nella_quest() -> void:
	var journal := CampaignJournal.new()
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	var definition := INNKEEPER_CONTENT.definition()
	_check(String(definition.get("id", "")) == "a_stone_for_nella")
	_check(bool(INNKEEPER_CONTENT.register_definition(journal).get("ok", false)))

	var initial := INNKEEPER_CONTENT.greeting(journal, player)
	_check(String(initial.get("speaker", "")) == "Nella Brook")
	_check(String(initial.get("text", "")).contains("rooms are warm"))
	_check(String(initial.choices[0].get("id", "")) == "nella_offer_stone")

	var gated := INNKEEPER_CONTENT.greeting(journal, player, true)
	_check(not gated.choices.any(func(choice: Dictionary) -> bool:
		return String(choice.get("id", "")) == "nella_offer_stone"
	), "Reading the abandoned-house journal preserves the source dialogue gate")

	var accepted := INNKEEPER_CONTENT.resolve_choice(journal, player, "nella_offer_stone")
	_check(bool(accepted.get("ok", false)))
	_check(String(journal.quest_state(INNKEEPER_CONTENT.QUEST_ID).get("status", "")) == "active")
	_check(String(accepted.dialogue.text).contains("my mother always wore a blue stone"))

	var waiting := INNKEEPER_CONTENT.greeting(journal, player)
	_check(String(waiting.text).contains("keeping an eye out"))
	var missing_gem := INNKEEPER_CONTENT.turn_in(journal, player)
	_check(String(missing_gem.get("reason", "")) == "blue_gem_missing")
	_check(String(journal.quest_state(INNKEEPER_CONTENT.QUEST_ID).get("status", "")) == "active")

	var blue_gem := ItemCatalog.create_instance("gem_blue", "nella_blue_gem_test")
	_check(not blue_gem.is_empty(), "The source blue-gem item already exists in the shared item catalogue")
	_check(player.add_inventory_item(blue_gem))
	var ready_to_turn_in := INNKEEPER_CONTENT.greeting(journal, player)
	_check(String(ready_to_turn_in.choices[0].get("id", "")) == "nella_turn_in")

	var turned_in := INNKEEPER_CONTENT.resolve_choice(journal, player, "nella_turn_in")
	_check(bool(turned_in.get("ok", false)))
	_check(bool(turned_in.get("quest_completed", false)))
	_check(String(journal.quest_state(INNKEEPER_CONTENT.QUEST_ID).get("status", "")) == "completed")
	_check(player.inventory.is_empty(), "Turn-in consumes the blue gem")
	_check(player.gold == INNKEEPER_CONTENT.REWARD_GOLD)
	_check(journal.npc_standing("nella_brook") == 20.0)
	_check(journal.npc_knowledge.get("nella_brook", 0.0) == 20.0)
	_check(String(turned_in.dialogue.text).contains("found one"))

	var repeated_turn_in := INNKEEPER_CONTENT.turn_in(journal, player)
	_check(String(repeated_turn_in.get("reason", "")) == "quest_not_active")
	_check(player.gold == INNKEEPER_CONTENT.REWARD_GOLD, "A completed quest cannot pay twice")
