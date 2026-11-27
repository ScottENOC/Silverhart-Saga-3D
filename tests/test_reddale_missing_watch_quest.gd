extends SceneTree

const MISSING_WATCH = preload("res://scripts/simulation/reddale_missing_watch_quest.gd")


func _initialize() -> void:
	_test_offer_accept_and_decline()
	_test_goblin_objective_and_source_rewards()
	print("Reddale Missing Watch quest tests passed.")
	quit(0)


func _test_offer_accept_and_decline() -> void:
	var journal := CampaignJournal.new()
	assert(MISSING_WATCH.register_definition(journal).ok)
	var offer := MISSING_WATCH.greeting(journal, MISSING_WATCH.GOBLIN_COUNT)
	assert(offer.ok)
	assert(String(offer.text).contains("Two of my watchmen"))
	assert(offer.choices.size() == 2)

	var declined := MISSING_WATCH.resolve_choice(journal, null, "ilsa_missing_watch_decline", 2)
	assert(declined.ok and declined.declined)
	assert(String(journal.quest_state(MISSING_WATCH.QUEST_ID).get("status", "")).is_empty())

	var accepted := MISSING_WATCH.resolve_choice(journal, null, "ilsa_missing_watch_accept", 2)
	assert(accepted.ok and accepted.quest_started)
	assert(String(journal.quest_state(MISSING_WATCH.QUEST_ID).status) == "active")
	var repeated := MISSING_WATCH.accept(journal)
	assert(not repeated.ok and String(repeated.reason) == "quest_already_started")


func _test_goblin_objective_and_source_rewards() -> void:
	var journal := CampaignJournal.new()
	MISSING_WATCH.register_definition(journal)
	MISSING_WATCH.accept(journal)
	var incomplete := MISSING_WATCH.greeting(journal, 2)
	assert(String(incomplete.text).contains("Head out along the east road"))
	var blocked_turn_in := MISSING_WATCH.turn_in(journal, CharacterState.new("player", "Adventurer"))
	assert(not blocked_turn_in.ok and String(blocked_turn_in.reason) == "goblins_remain")

	var one_defeated := MISSING_WATCH.record_goblin_defeats(journal, 1)
	assert(one_defeated.ok and not one_defeated.completed)
	var two_defeated := MISSING_WATCH.record_goblin_defeats(journal, 2)
	assert(two_defeated.ok and two_defeated.completed)
	var ready := MISSING_WATCH.greeting(journal, 0)
	assert(String(ready.text).contains("Goblins, this far out?"))
	assert(String(ready.choices[0].id) == "ilsa_missing_watch_turn_in")

	var player := CharacterState.new("player", "Adventurer")
	player.gold = 5
	var result := MISSING_WATCH.resolve_choice(journal, player, "ilsa_missing_watch_turn_in", 0)
	assert(result.ok and result.quest_completed)
	assert(player.gold == 45)
	assert(player.experience == 200)
	assert(String(journal.quest_state(MISSING_WATCH.QUEST_ID).status) == "completed")
	assert(is_equal_approx(journal.faction_standing(MISSING_WATCH.FACTION_ID), 15.0))
	assert(is_equal_approx(journal.faction_knowledge(MISSING_WATCH.FACTION_ID), 20.0))

	var repeated := MISSING_WATCH.resolve_choice(journal, player, "ilsa_missing_watch_turn_in", 0)
	assert(not repeated.ok)
	assert(player.gold == 45 and player.experience == 200)
