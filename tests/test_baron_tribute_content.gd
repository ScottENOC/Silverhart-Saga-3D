extends SceneTree

const BARON_CONTENT = preload("res://scripts/simulation/baron_tribute_content.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_barons_tribute_flow()
	if _failures > 0:
		push_error("%d Baron's Tribute assertion(s) failed." % _failures)
		quit(1)
		return
	print("Baron's Tribute content tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_barons_tribute_flow() -> void:
	var journal := CampaignJournal.new()
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	_check(String(BARON_CONTENT.definition().get("id", "")) == "baron_tribute")
	_check(bool(BARON_CONTENT.register_definition(journal).get("ok", false)))

	var initial := BARON_CONTENT.greeting(journal, player)
	_check(String(initial.get("speaker", "")) == "Baron Corwin Aldervale")
	_check(String(initial.get("text", "")).contains("fine red gem"))
	_check(String(initial.choices[0].get("id", "")) == "baron_tribute_offer")

	var accepted := BARON_CONTENT.resolve_choice(journal, player, "baron_tribute_offer")
	_check(bool(accepted.get("ok", false)))
	_check(String(journal.quest_state(BARON_CONTENT.QUEST_ID).get("status", "")) == "active")

	var waiting := BARON_CONTENT.greeting(journal, player)
	_check(String(waiting.get("text", "")).contains("Still no tribute"))
	var missing_gem := BARON_CONTENT.turn_in(journal, player)
	_check(String(missing_gem.get("reason", "")) == "red_gem_missing")
	_check(String(journal.quest_state(BARON_CONTENT.QUEST_ID).get("status", "")) == "active")

	var red_gem := ItemCatalog.create_instance("gem_red", "baron_red_gem_test")
	_check(not red_gem.is_empty(), "The source red-gem item must exist in the shared item catalogue")
	_check(player.add_inventory_item(red_gem))
	var ready_to_turn_in := BARON_CONTENT.greeting(journal, player)
	_check(String(ready_to_turn_in.choices[0].get("id", "")) == "baron_tribute_present")

	var turned_in := BARON_CONTENT.resolve_choice(journal, player, "baron_tribute_present")
	_check(bool(turned_in.get("ok", false)))
	_check(bool(turned_in.get("quest_completed", false)))
	_check(String(journal.quest_state(BARON_CONTENT.QUEST_ID).get("status", "")) == "completed")
	_check(player.inventory.is_empty(), "Turn-in consumes the red gem")
	_check(player.gold == BARON_CONTENT.REWARD_GOLD)
	_check(journal.npc_standing("baron_corwin_aldervale") == 20.0)
	_check(journal.npc_knowledge.get("baron_corwin_aldervale", 0.0) == 20.0)
	_check(journal.faction_standing("silverhart_kingdom") == 10.0)
	_check(journal.faction_knowledge.get("silverhart_kingdom", 0.0) == 15.0)

	var repeated_turn_in := BARON_CONTENT.turn_in(journal, player)
	_check(String(repeated_turn_in.get("reason", "")) == "quest_not_active")
	_check(player.gold == BARON_CONTENT.REWARD_GOLD, "A completed quest cannot pay twice")
