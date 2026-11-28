extends SceneTree

const CORVANE_CONTENT = preload("res://scripts/simulation/corvane_ambassador_content.gd")
const GOBLIN_THREAT_CONTENT = preload("res://scripts/simulation/goblin_threat_campaign_content.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_border_report_gates_and_rewards()
	if _failures > 0:
		push_error("%d Eyes on the Border assertion(s) failed." % _failures)
		quit(1)
		return
	print("Corvane ambassador content tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_border_report_gates_and_rewards() -> void:
	var journal := CampaignJournal.new()
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	player.gold = 5
	player.experience = 25

	var opening := CORVANE_CONTENT.greeting(journal, player)
	_check(String(opening.speaker) == "Ambassador Toren Aldwyn")
	_check(String(opening.choices[0].id) == "toren_accept_report")

	var accepted := CORVANE_CONTENT.resolve_choice(journal, player, "toren_accept_report")
	_check(bool(accepted.get("ok", false)))
	_check(String(journal.quest_state(CORVANE_CONTENT.QUEST_ID).get("status", "")) == "active")
	_check(String(accepted.dialogue.text).contains("Riveting dispatches"))

	var early_report := CORVANE_CONTENT.report_resolution(journal, player)
	_check(String(early_report.get("reason", "")) == "goblin_threat_still_active")
	_check(player.gold == 5)
	_check(player.experience == 25)

	var goblin_content = GOBLIN_THREAT_CONTENT.new()
	var goblin_started := goblin_content.begin_favour_negotiation(journal)
	_check(bool(goblin_started.get("ok", false)))
	var resolved := goblin_content.resolve_threat(journal, "assault")
	_check(bool(resolved.get("ok", false)))
	_check(String(journal.quest_state("goblin_threat").get("status", "")) == "completed")

	var ready := CORVANE_CONTENT.greeting(journal, player)
	_check(String(ready.text).contains("That's the first good dispatch"))
	_check(String(ready.choices[0].id) == "toren_report_resolved")

	var report := CORVANE_CONTENT.resolve_choice(journal, player, "toren_report_resolved")
	_check(bool(report.get("ok", false)))
	_check(bool(report.get("quest_completed", false)))
	_check(String(journal.quest_state(CORVANE_CONTENT.QUEST_ID).get("status", "")) == "completed")
	_check(player.gold == 20, "The source reward is 15 gold")
	_check(player.experience == 85, "The source reward is 60 experience")
	_check(journal.npc_standing(CORVANE_CONTENT.NPC_ID) == 10.0)
	_check(journal.npc_knowledge.get(CORVANE_CONTENT.NPC_ID, 0.0) == 15.0)

	var after := CORVANE_CONTENT.greeting(journal, player)
	_check(String(after.text).contains("The border's quieter"))
	var repeated := CORVANE_CONTENT.report_resolution(journal, player)
	_check(String(repeated.get("reason", "")) == "quest_not_active")
	_check(player.gold == 20)
	_check(player.experience == 85)
