extends SceneTree

const TOLL_OGRE_CONTENT = preload("res://scripts/simulation/toll_taker_quest_content.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_toll_taker_quest_flow()
	if _failures > 0:
		push_error("%d Toll-Taker assertion(s) failed." % _failures)
		quit(1)
		return
	print("Toll-Taker quest content tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_toll_taker_quest_flow() -> void:
	var journal := CampaignJournal.new()
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	_check(String(TOLL_OGRE_CONTENT.definition().get("id", "")) == "toll_ogre")
	_check(bool(TOLL_OGRE_CONTENT.register_definition(journal).get("ok", false)))

	var initial := TOLL_OGRE_CONTENT.greeting(journal, true)
	_check(String(initial.get("speaker", "")) == "Petra Hollis")
	_check(String(initial.get("text", "")).contains("ogre"))
	_check(String(initial.choices[0].get("id", "")) == "toll_ogre_accept")

	var accepted := TOLL_OGRE_CONTENT.resolve_choice(journal, player, "toll_ogre_accept", true)
	_check(bool(accepted.get("ok", false)))
	_check(String(journal.quest_state(TOLL_OGRE_CONTENT.QUEST_ID).get("status", "")) == "active")

	var still_active := TOLL_OGRE_CONTENT.record_ogre_defeat(journal, true)
	_check(bool(still_active.get("ok", false)))
	_check(not bool(still_active.get("defeated", true)))
	_check(String(TOLL_OGRE_CONTENT.turn_in(journal, player).get("reason", "")) == "ogre_not_defeated")
	_check(player.gold == 0 and player.experience == 0)

	var ready_to_turn_in := TOLL_OGRE_CONTENT.greeting(journal, false)
	_check(String(ready_to_turn_in.choices[0].get("id", "")) == "toll_ogre_turn_in")
	var objective: Dictionary = journal.quest_state(TOLL_OGRE_CONTENT.QUEST_ID).get("objectives", {}).get(TOLL_OGRE_CONTENT.OBJECTIVE_ID, {})
	_check(bool(objective.get("completed", false)), "Petra's return conversation records that the ogre is dead")
	var repeated_defeat := TOLL_OGRE_CONTENT.record_ogre_defeat(journal, false)
	_check(bool(repeated_defeat.get("ok", false)) and bool(repeated_defeat.get("defeated", false)))

	var turned_in := TOLL_OGRE_CONTENT.resolve_choice(journal, player, "toll_ogre_turn_in", false)
	_check(bool(turned_in.get("ok", false)))
	_check(bool(turned_in.get("quest_completed", false)))
	_check(String(journal.quest_state(TOLL_OGRE_CONTENT.QUEST_ID).get("status", "")) == "completed")
	_check(player.gold == TOLL_OGRE_CONTENT.REWARD_GOLD)
	_check(player.experience == TOLL_OGRE_CONTENT.REWARD_EXPERIENCE)
	_check(journal.faction_standing("silverhart_kingdom") == TOLL_OGRE_CONTENT.REWARD_REPUTATION)
	_check(journal.faction_knowledge.get("silverhart_kingdom", 0.0) == TOLL_OGRE_CONTENT.REWARD_KNOWLEDGE)

	var repeated_turn_in := TOLL_OGRE_CONTENT.turn_in(journal, player)
	_check(String(repeated_turn_in.get("reason", "")) == "quest_not_active")
	_check(player.gold == TOLL_OGRE_CONTENT.REWARD_GOLD, "A completed quest cannot pay twice")
	_check(player.experience == TOLL_OGRE_CONTENT.REWARD_EXPERIENCE, "Experience cannot be awarded twice")
	_check(String(TOLL_OGRE_CONTENT.greeting(journal, false).choices[0].get("id", "")) == "toll_ogre_leave")

	var saved := journal.to_dict()
	var restored := CampaignJournal.new()
	TOLL_OGRE_CONTENT.register_definition(restored)
	restored.load_dict(saved)
	_check(restored.to_dict() == saved, "The quest completion survives journal save/restore")
