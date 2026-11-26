extends SceneTree

const CONTENT = preload("res://scripts/simulation/aldenreach_message_content.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_quiet_word_delivery_and_reward()
	if _failures > 0:
		push_error("%d Aldenreach message assertion(s) failed." % _failures)
		quit(1)
		return
	print("Aldenreach quiet-word content tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_quiet_word_delivery_and_reward() -> void:
	var journal := CampaignJournal.new()
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	player.gold = 2
	player.experience = 25

	_check(String(CONTENT.definition().get("id", "")) == "aldenreach_message")
	_check(bool(CONTENT.register_definition(journal).get("ok", false)))
	var opening := CONTENT.greeting(journal)
	_check(String(opening.speaker) == "Ambassador Cassia Wren")
	_check(String(opening.choices[0].id) == "cassia_accept_message")

	var early_delivery := CONTENT.deliver_to_elder(journal)
	_check(not bool(early_delivery.get("delivered_now", false)), "The elder cannot receive a message before the quest is accepted")
	var accepted := CONTENT.resolve_choice(journal, player, "cassia_accept_message")
	_check(bool(accepted.get("ok", false)))
	_check(bool(accepted.get("quest_started", false)))
	_check(String(journal.quest_state(CONTENT.QUEST_ID).get("status", "")) == "active")

	var waiting := CONTENT.greeting(journal)
	_check(String(waiting.text).contains("Still waiting"))
	var early_claim := CONTENT.claim_delivery(journal, player)
	_check(String(early_claim.get("reason", "")) == "message_not_delivered")

	var delivered := CONTENT.deliver_to_elder(journal)
	_check(bool(delivered.get("ok", false)))
	_check(bool(delivered.get("delivered_now", false)))
	var delivery_objective: Dictionary = journal.quest_state(CONTENT.QUEST_ID).objectives[CONTENT.DELIVERY_OBJECTIVE_ID]
	_check(bool(delivery_objective.get("completed", false)))
	var repeated_delivery := CONTENT.deliver_to_elder(journal)
	_check(not bool(repeated_delivery.get("delivered_now", false)), "Speaking to Elder Marta twice must not duplicate delivery")

	var ready_to_report := CONTENT.greeting(journal)
	_check(String(ready_to_report.text).contains("Elder Marta had your word"))
	_check(String(ready_to_report.choices[0].id) == "cassia_claim_delivery")
	var claimed := CONTENT.resolve_choice(journal, player, "cassia_claim_delivery")
	_check(bool(claimed.get("ok", false)))
	_check(bool(claimed.get("quest_completed", false)))
	_check(String(journal.quest_state(CONTENT.QUEST_ID).get("status", "")) == "completed")
	_check(player.gold == 17)
	_check(player.experience == 85)
	_check(journal.npc_standing(CONTENT.NPC_ID) == 10.0)
	_check(journal.npc_knowledge.get(CONTENT.NPC_ID, 0.0) == 15.0)

	var repeated_claim := CONTENT.claim_delivery(journal, player)
	_check(String(repeated_claim.get("reason", "")) == "quest_not_active")
	_check(player.gold == 17)
	_check(player.experience == 85)
