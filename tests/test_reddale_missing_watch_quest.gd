extends SceneTree

const MISSING_WATCH = preload("res://scripts/simulation/reddale_missing_watch_quest.gd")
const MISSING_WATCH_ENCOUNTER = preload("res://scripts/simulation/reddale_missing_watch_encounter.gd")


func _initialize() -> void:
	_test_offer_accept_and_decline()
	_test_goblin_objective_and_source_rewards()
	_test_source_placement_and_persistent_goblin_states()
	_test_encounter_victory_and_retreat()
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
	assert(is_equal_approx(float(journal.faction_knowledge.get(MISSING_WATCH.FACTION_ID, 0.0)), 20.0))

	var repeated := MISSING_WATCH.resolve_choice(journal, player, "ilsa_missing_watch_turn_in", 0)
	assert(not repeated.ok)
	assert(player.gold == 45 and player.experience == 200)


func _test_source_placement_and_persistent_goblin_states() -> void:
	assert(MISSING_WATCH_ENCOUNTER.SEARCH_SITE_HEX == Vector2i(156, 24))
	assert(MISSING_WATCH_ENCOUNTER.GOBLIN_OFFSETS[1] == Vector2i(1, -1))
	var simulation := WorldSimulation.new()
	var created := MISSING_WATCH_ENCOUNTER.ensure_goblins(simulation)
	assert(created.ok and created.created_ids.size() == 2)
	assert(MISSING_WATCH_ENCOUNTER.goblins_remaining(simulation) == 2)
	for index in range(MISSING_WATCH_ENCOUNTER.GOBLIN_IDS.size()):
		var goblin_id: String = MISSING_WATCH_ENCOUNTER.GOBLIN_IDS[index]
		var goblin := simulation.get_character(goblin_id)
		assert(goblin != null)
		assert(goblin.race == "goblin" and goblin.side == "enemy")
		assert(goblin.max_health == MISSING_WATCH_ENCOUNTER.GOBLIN_HEALTH)
		assert(goblin.combat_dormant and goblin.tags.has("reddale_missing_watch_goblin"))
		assert(goblin.axial == MISSING_WATCH_ENCOUNTER.SEARCH_SITE_HEX + MISSING_WATCH_ENCOUNTER.GOBLIN_OFFSETS[index])
	var repeated := MISSING_WATCH_ENCOUNTER.ensure_goblins(simulation)
	assert(repeated.ok and repeated.created_ids.is_empty())
	var records := MISSING_WATCH_ENCOUNTER.dynamic_character_records(simulation)
	assert(records.size() == 2)
	var restored := CharacterState.from_dict(records[MISSING_WATCH_ENCOUNTER.GOBLIN_IDS[0]])
	assert(restored != null and restored.race == "goblin")


func _test_encounter_victory_and_retreat() -> void:
	var simulation := WorldSimulation.new()
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	simulation.register_character(player)
	MISSING_WATCH.register_definition(simulation.campaign_journal)
	MISSING_WATCH.accept(simulation.campaign_journal)
	MISSING_WATCH_ENCOUNTER.ensure_goblins(simulation)
	var started := MISSING_WATCH_ENCOUNTER.start_encounter(simulation, ["player"])
	assert(started.ok and simulation.is_in_combat)
	var first := simulation.get_character(MISSING_WATCH_ENCOUNTER.GOBLIN_IDS[0])
	var second := simulation.get_character(MISSING_WATCH_ENCOUNTER.GOBLIN_IDS[1])
	first.alive = false
	second.health = 0
	second.unconscious = true
	var victory := MISSING_WATCH_ENCOUNTER.resolve_combat(simulation, simulation.campaign_journal, ["player"], started.session)
	assert(victory.ok and victory.resolved and victory.outcome == "victory")
	assert(not simulation.is_in_combat)
	assert(not first.alive and not second.alive)
	assert(MISSING_WATCH_ENCOUNTER.goblins_remaining(simulation) == 0)
	var objective: Dictionary = simulation.campaign_journal.quest_state(MISSING_WATCH.QUEST_ID).objectives.get(MISSING_WATCH.OBJECTIVE_ID, {})
	assert(objective.get("completed", false))

	var retreat_simulation := WorldSimulation.new()
	var retreat_player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	retreat_simulation.register_character(retreat_player)
	MISSING_WATCH_ENCOUNTER.ensure_goblins(retreat_simulation)
	var retreat_start := MISSING_WATCH_ENCOUNTER.start_encounter(retreat_simulation, ["player"])
	assert(retreat_start.ok)
	retreat_player.alive = false
	var retreat := MISSING_WATCH_ENCOUNTER.resolve_combat(retreat_simulation, retreat_simulation.campaign_journal, ["player"], retreat_start.session)
	assert(retreat.resolved and retreat.outcome == "defeat")
	assert(MISSING_WATCH_ENCOUNTER.goblins_remaining(retreat_simulation) == 2)
