extends SceneTree

const AMBASSADOR_CONTENT = preload("res://scripts/simulation/dwarven_ambassador_content.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_dwarven_toll_flow()
	if _failures > 0:
		push_error("%d Deepholds toll assertion(s) failed." % _failures)
		quit(1)
		return
	print("Dwarven ambassador content tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_dwarven_toll_flow() -> void:
	var journal := CampaignJournal.new()
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	player.gold = 10
	player.experience = 100

	_check(String(AMBASSADOR_CONTENT.definition().get("id", "")) == "dwarven_toll")
	_check(bool(AMBASSADOR_CONTENT.register_definition(journal).get("ok", false)))
	var initial := AMBASSADOR_CONTENT.greeting(journal, player)
	_check(String(initial.speaker) == "Ambassador Brokk Stonehammer")
	_check(String(initial.choices[0].id) == "brokk_accept_toll")

	var accepted := AMBASSADOR_CONTENT.resolve_choice(journal, player, "brokk_accept_toll")
	_check(bool(accepted.get("ok", false)))
	_check(String(journal.quest_state(AMBASSADOR_CONTENT.QUEST_ID).get("status", "")) == "active")
	_check(String(accepted.dialogue.text).contains("Fifteen gold, when you have it"))

	var insufficient := AMBASSADOR_CONTENT.pay_toll(journal, player)
	_check(String(insufficient.get("reason", "")) == "insufficient_gold")
	_check(player.gold == 10)
	_check(player.experience == 100)
	_check(String(journal.quest_state(AMBASSADOR_CONTENT.QUEST_ID).get("status", "")) == "active")

	player.gold = 20
	var ready := AMBASSADOR_CONTENT.greeting(journal, player)
	_check(String(ready.choices[0].id) == "brokk_pay_toll")
	var paid := AMBASSADOR_CONTENT.resolve_choice(journal, player, "brokk_pay_toll")
	_check(bool(paid.get("ok", false)))
	_check(bool(paid.get("quest_completed", false)))
	_check(String(journal.quest_state(AMBASSADOR_CONTENT.QUEST_ID).get("status", "")) == "completed")
	_check(player.gold == 5, "The toll must deduct exactly 15 gold")
	_check(player.experience == 160, "The source reward is 60 experience")
	_check(journal.npc_standing(AMBASSADOR_CONTENT.NPC_ID) == 10.0)
	_check(journal.npc_knowledge.get(AMBASSADOR_CONTENT.NPC_ID, 0.0) == 15.0)
	_check(journal.faction_standing(AMBASSADOR_CONTENT.FACTION_ID) == 10.0)
	_check(journal.faction_knowledge.get(AMBASSADOR_CONTENT.FACTION_ID, 0.0) == 15.0)

	var after := AMBASSADOR_CONTENT.greeting(journal, player)
	_check(String(after.text).contains("Silverhart's been fair"))
	var repeated := AMBASSADOR_CONTENT.pay_toll(journal, player)
	_check(String(repeated.get("reason", "")) == "quest_not_active")
	_check(player.gold == 5)
	_check(player.experience == 160)
