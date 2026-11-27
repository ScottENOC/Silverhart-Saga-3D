extends SceneTree

const QUEST_SERVICE = preload("res://scripts/quests/campaign_quest_service.gd")
const QUEST_REGISTRY = preload("res://scripts/quests/campaign_quest_registry.gd")
const ABANDONED_HOUSE = preload("res://scripts/simulation/abandoned_house_clearing_quest.gd")
const TOLL_TAKER = preload("res://scripts/simulation/toll_taker_quest_content.gd")
const FARM_WOLVES = preload("res://scripts/simulation/farm_wolves_quest.gd")
const QUEST_DIALOGUE_DISPATCHER = preload("res://scripts/quests/campaign_quest_dialogue_dispatcher.gd")


func _initialize() -> void:
	_test_registry_registration()
	_test_service_journal_facade()
	_test_unconfigured_service_fails_safely()
	_test_quest_dialogue_dispatcher()
	print("Campaign quest service tests passed.")
	quit(0)


func _test_registry_registration() -> void:
	var simulation := WorldSimulation.new()
	var result := QUEST_REGISTRY.register_definitions(simulation)
	assert(bool(result.get("ok", false)))
	assert(simulation.campaign_journal.quest_definitions.has(ABANDONED_HOUSE.QUEST_ID))
	assert(simulation.campaign_journal.quest_definitions.has(TOLL_TAKER.QUEST_ID))
	assert(simulation.campaign_journal.quest_definitions.has(FARM_WOLVES.QUEST_ID), "Registry should include farm wolves content.")
	var repeated := QUEST_REGISTRY.register_definitions(simulation)
	assert(bool(repeated.get("ok", false)), "Registry should tolerate repeated registration.")


func _test_service_journal_facade() -> void:
	var simulation := WorldSimulation.new()
	var service := QUEST_SERVICE.new()
	assert(service.configure(simulation).ok)
	assert(service.register_definitions().ok)
	var started := service.start(ABANDONED_HOUSE.QUEST_ID)
	assert(bool(started.get("ok", false)))
	assert(String(service.state(ABANDONED_HOUSE.QUEST_ID).get("status", "")) == "active")
	var progress := service.set_objective_progress(
		ABANDONED_HOUSE.QUEST_ID,
		"house_guardians_defeated",
		1.0
	)
	# The service must pass through journal validation rather than inventing
	# objectives or silently accepting unknown quest state.
	assert(bool(progress.get("ok", false)), "Known quest objectives should be updated through the service.")



func _test_quest_dialogue_dispatcher() -> void:
	var simulation := WorldSimulation.new()
	var dispatched := QUEST_DIALOGUE_DISPATCHER.resolve_choice(
		simulation,
		{"id": "ironbond_courier_decline"}
	)
	assert(bool(dispatched.get("handled", false)), "Quest dialogue dispatcher should recognise authored quest choices.")
	var result: Dictionary = dispatched.get("result", {})
	assert(bool(result.get("ok", false)), "A valid decline choice should resolve through quest content.")
	var dialogue: Dictionary = result.get("dialogue", {})
	assert(String(dialogue.get("speaker", "")) == "Dray Coltayne")

	var farm_choice := QUEST_DIALOGUE_DISPATCHER.resolve_choice(
		simulation,
		{"id": "farm_wolves_continue", "text": "I will keep watch."}
	)
	assert(bool(farm_choice.get("handled", false)), "Farm dialogue choices should be handled by the dispatcher.")
	var farm_result: Dictionary = farm_choice.get("result", {})
	assert(farm_result.has("dialogue"), "Farm quest content returns dialogue without an ok flag.")

	var unrelated := QUEST_DIALOGUE_DISPATCHER.resolve_choice(simulation, {"id": "continue"})
	assert(not bool(unrelated.get("handled", false)), "World-only choices should remain with the world scene.")


func _test_unconfigured_service_fails_safely() -> void:
	var service := QUEST_SERVICE.new()
	assert(not bool(service.register_definitions().get("ok", false)))
	assert(not bool(service.start("unknown_quest").get("ok", false)))
	assert(service.state("unknown_quest").is_empty())
